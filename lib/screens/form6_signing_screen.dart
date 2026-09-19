import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../app_colors.dart';
import '../models/form6_manifest.dart';
import '../models/lot.dart';
import '../services/crypto_service.dart';
import '../services/location_service.dart';

enum _Stage { dispatch, transit, delivery, complete }

/// Digitizes the Form-6 manifest and walks through its three sign-off
/// checkpoints (dispatch → transit → delivery), chaining each stage's
/// hash into the next — the digital equivalent of the paper form's
/// three physical signatures (see CryptoService for what "chained" means
/// here, and its honesty note about hash-chaining vs. encryption).
///
/// In production each checkpoint is signed by a different party (the
/// collector/storage point, the transporter, the recycler) on their own
/// device. This screen lets all three be signed in sequence for demo/
/// testing purposes — split it across apps once the transporter and
/// recycler-side apps exist.
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
    senderName: '',
    senderPhone: '',
    materialType: widget.lot.category,
    quantity: widget.lot.approxWeightKg,
    destinationRecyclerId: widget.recyclerId,
  );

  String get _stageLabel {
    switch (_stage) {
      case _Stage.dispatch:
        return 'Dispatch (handover from collector/storage point)';
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
    final position = await LocationService.getCurrentPosition();
    final now = DateTime.now();

    // NOTE: a typed name + timestamp stands in for a drawn signature here.
    // Swap in a signature-pad widget later; only this hash source changes.
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

    setState(() {
      switch (_stage) {
        case _Stage.dispatch:
          _manifest.senderName = name;
          _manifest.checkpointDispatch = checkpoint;
          _stage = _Stage.transit;
          break;
        case _Stage.transit:
          _manifest.checkpointTransit = checkpoint;
          _stage = _Stage.delivery;
          break;
        case _Stage.delivery:
          _manifest.checkpointDelivery = checkpoint;
          _stage = _Stage.complete;
          break;
        case _Stage.complete:
          break;
      }
      _signing = false;
      _nameController.clear();
    });
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
                        '${_manifest.materialType} · ${_manifest.quantity} kg'),
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
                  label: const Text('Sign this checkpoint'),
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
