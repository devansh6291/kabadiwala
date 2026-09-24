import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/form6_manifest.dart';
import '../models/lot.dart';
import '../models/collector_store.dart';
import '../services/crypto_service.dart';
import '../services/location_service.dart';
import '../services/api_client.dart';

enum _Stage { dispatch, transit, delivery, complete }

/// Digitizes the Form-6 manifest and pushes checkpoints to the live MySQL ledger.
class Form6SigningScreen extends StatefulWidget {
  final Lot lot;
  final String recyclerId;

  const Form6SigningScreen(
      {super.key, required this.lot, required this.recyclerId});

  @override
  State<Form6SigningScreen> createState() => _Form6SigningScreenState();
}

class _Form6SigningScreenState extends State<Form6SigningScreen> {
  final Uuid _uuid = const Uuid();
  final TextEditingController _nameController = TextEditingController();

  _Stage _stage = _Stage.dispatch;
  bool _signing = false;

  late final Form6Manifest _manifest = Form6Manifest(
    manifestId: _uuid.v4(),
    senderName: CollectorStore.getOrCreate().name,
    senderPhone: CollectorStore.getOrCreate().phoneNumber,
    materialType: widget.lot.category,
    quantity: widget.lot.approxWeightKg,
    destinationRecyclerId: widget.recyclerId,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _stageLabel {
    switch (_stage) {
      case _Stage.dispatch:
        return 'Dispatch (handover from collector/storage)';
      case _Stage.transit:
        return 'Transit (received by transporter)';
      case _Stage.delivery:
        return 'Delivery (received by recycler)';
      case _Stage.complete:
        return 'Complete';
    }
  }

  Future<void> _signCurrentStage() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the signer\'s name to confirm')),
      );
      return;
    }

    setState(() => _signing = true);

    try {
      final position = await LocationService.getCurrentPosition();
      final now = DateTime.now();

      final signatureHash =
          CryptoService.hash('$name|${_stage.name}|${now.toIso8601String()}');

      final previousHash = switch (_stage) {
        _Stage.dispatch => _manifest.manifestId,
        _Stage.transit => _manifest.checkpointDispatch!.cumulativeHash,
        _Stage.delivery => _manifest.checkpointTransit!.cumulativeHash,
        _Stage.complete => '',
      };

      final checkpoint = Form6Checkpoint(
        signatureHash: signatureHash,
        timestamp: now,
        latitude: position?.latitude,
        longitude: position?.longitude,
        cumulativeHash: CryptoService.chainHash(
          previousHash: previousHash,
          stageSignatureHash: signatureHash,
          timestamp: now,
          latitude: position?.latitude,
          longitude: position?.longitude,
        ),
      );

      // Update Local Object
      switch (_stage) {
        case _Stage.dispatch:
          _manifest.senderName = name;
          _manifest.checkpointDispatch = checkpoint;
          break;
        case _Stage.transit:
          _manifest.checkpointTransit = checkpoint;
          break;
        case _Stage.delivery:
          _manifest.checkpointDelivery = checkpoint;
          break;
        case _Stage.complete:
          break;
      }

      // Sync to live MySQL Backend
      await _pushManifestToLedger();

      if (!mounted) return;
      setState(() {
        if (_stage == _Stage.dispatch)
          _stage = _Stage.transit;
        else if (_stage == _Stage.transit)
          _stage = _Stage.delivery;
        else if (_stage == _Stage.delivery) _stage = _Stage.complete;

        _signing = false;
        _nameController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _signing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record signature: $e')),
      );
    }
  }

  Future<void> _pushManifestToLedger() async {
    final payload = {
      'manifest_id': _manifest.manifestId,
      'sender_name':
          _manifest.senderName.isEmpty ? 'Unknown' : _manifest.senderName,
      'sender_phone': _manifest.senderPhone,
      'transporter_id': 'pending',
      'transporter_name': 'Pending Transporter',
      'material_type': _manifest.materialType,
      'quantity': _manifest.quantity,
      'destination_recycler_id': _manifest.destinationRecyclerId,
      'checkpoint_dispatch': _manifest.checkpointDispatch != null
          ? {
              'signature_hash': _manifest.checkpointDispatch!.signatureHash,
              'cumulative_hash': _manifest.checkpointDispatch!.cumulativeHash,
              'timestamp':
                  _manifest.checkpointDispatch!.timestamp.toIso8601String(),
            }
          : null,
      'checkpoint_transit': _manifest.checkpointTransit != null
          ? {
              'signature_hash': _manifest.checkpointTransit!.signatureHash,
              'cumulative_hash': _manifest.checkpointTransit!.cumulativeHash,
              'timestamp':
                  _manifest.checkpointTransit!.timestamp.toIso8601String(),
            }
          : null,
      'checkpoint_delivery': _manifest.checkpointDelivery != null
          ? {
              'signature_hash': _manifest.checkpointDelivery!.signatureHash,
              'cumulative_hash': _manifest.checkpointDelivery!.cumulativeHash,
              'timestamp':
                  _manifest.checkpointDelivery!.timestamp.toIso8601String(),
            }
          : null,
      'chain_hash': _manifest.chainHash,
    };

    final response =
        await ApiClient().dio.post('/manifests/checkpoint', data: payload);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Server rejected the signature ledger update.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Form-6 Manifest')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manifest ID',
                        style: TextStyle(color: Colors.black54)),
                    SelectableText(_manifest.manifestId,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                        '${_manifest.materialType}  •  ${_manifest.quantity} kg'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildCheckpointTile('Dispatch', _manifest.checkpointDispatch),
            _buildCheckpointTile('Transit', _manifest.checkpointTransit),
            _buildCheckpointTile('Delivery', _manifest.checkpointDelivery),
            const SizedBox(height: 20),
            if (_stage != _Stage.complete) ...[
              Text(_stageLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Type name to confirm signature',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _signing ? null : _signCurrentStage,
                  icon: _signing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.draw),
                  label: const Text('Sign this checkpoint',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ] else
              Card(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified, color: AppColors.primaryGreen),
                          SizedBox(width: 8),
                          Text('Form-6 complete',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'Final chain hash (breaks if any checkpoint is altered):'),
                      const SizedBox(height: 4),
                      SelectableText(
                        _manifest.chainHash ?? '',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckpointTile(String label, Form6Checkpoint? checkpoint) {
    final done = checkpoint != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? AppColors.primaryGreen : Colors.black26,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontWeight: done ? FontWeight.w600 : FontWeight.normal)),
          if (done) ...[
            const Spacer(),
            Text(
              '${checkpoint.timestamp.hour.toString().padLeft(2, '0')}:${checkpoint.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }
}
