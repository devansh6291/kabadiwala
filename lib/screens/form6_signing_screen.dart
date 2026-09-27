import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';
import '../models/form6_manifest.dart';
import '../models/lot.dart';
import '../models/collector_store.dart';
import '../services/crypto_service.dart';
import '../services/location_service.dart';
import '../services/api_client.dart';
import '../services/firebase_service.dart';

enum _Stage { dispatch, transit, delivery, complete }

const _pdfFillerFormUrl =
    'https://www.pdffiller.com/409045148-FORM-6-E-waste-Rules-2016pdf-form-6-e-waste-';

/// Digitizes the Form-6 manifest and pushes checkpoints to the live MySQL ledger.
class Form6SigningScreen extends StatefulWidget {
  final Lot lot;
  final String recyclerId;
  final Map<String, dynamic>? initialManifestData;

  const Form6SigningScreen(
      {super.key, required this.lot, required this.recyclerId, this.initialManifestData});

  @override
  State<Form6SigningScreen> createState() => _Form6SigningScreenState();
}

class _Form6SigningScreenState extends State<Form6SigningScreen> {
  final Uuid _uuid = const Uuid();
  final TextEditingController _nameController = TextEditingController();

  late _Stage _stage;
  bool _signing = false;
  bool _cloudLedgerUnavailable = false;
  String? _dispatchSigner;
  String? _transitSigner;
  String? _deliverySigner;
  List<String>? _cloudPhotoRefs;

  late Form6Manifest _manifest;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialManifestData;
    if (initial != null) {
      _manifest = Form6Manifest.fromJson(initial);
      _manifest.destinationRecyclerId = widget.recyclerId;
      _dispatchSigner = _signerFrom(initial, 'checkpoint_dispatch', 'checkpointDispatch');
      _transitSigner = _signerFrom(initial, 'checkpoint_transit', 'checkpointTransit');
      _deliverySigner = _signerFrom(initial, 'checkpoint_delivery', 'checkpointDelivery');
      _stage = _manifest.checkpointDelivery != null
          ? _Stage.complete
          : _manifest.checkpointTransit != null
              ? _Stage.delivery
              : _manifest.checkpointDispatch != null
                  ? _Stage.transit
                  : _Stage.dispatch;
    } else {
      final collector = CollectorStore.getOrCreate();
      _manifest = Form6Manifest(
        manifestId: _uuid.v4(),
        senderName: collector.name,
        senderPhone: collector.phoneNumber,
        materialType: widget.lot.category,
        quantity: widget.lot.approxWeightKg,
        destinationRecyclerId: widget.recyclerId,
      );
      _stage = _Stage.dispatch;
    }
  }

  String? _signerFrom(Map<String, dynamic> data, String snake, String camel) {
    final checkpoint = data[snake] ?? data[camel];
    if (checkpoint is Map) {
      return (checkpoint['signer_name'] ?? checkpoint['signerName'])?.toString();
    }
    return null;
  }

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
      final position = await LocationService.getCurrentPosition()
          .catchError((_) => null);
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
          _dispatchSigner = name;
          _manifest.checkpointDispatch = checkpoint;
          break;
        case _Stage.transit:
          _transitSigner = name;
          _manifest.checkpointTransit = checkpoint;
          break;
        case _Stage.delivery:
          _deliverySigner = name;
          _manifest.checkpointDelivery = checkpoint;
          break;
        case _Stage.complete:
          break;
      }

      // Try the cloud ledger, but keep the signing walkthrough usable if the
      // network/database is unavailable. The screen reports the sync state.
      var synced = true;
      try {
        await _pushManifestToLedger();
      } catch (e) {
        synced = false;
        debugPrint('[FORM-6 LEDGER SYNC ERROR] $e');
      }

      if (!mounted) return;
      setState(() {
        if (_stage == _Stage.dispatch)
          _stage = _Stage.transit;
        else if (_stage == _Stage.transit)
          _stage = _Stage.delivery;
        else if (_stage == _Stage.delivery) _stage = _Stage.complete;

        _signing = false;
        _cloudLedgerUnavailable = _cloudLedgerUnavailable || !synced;
        _nameController.clear();
      });
      if (!synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Checkpoint added to this walkthrough, but the cloud ledger could not be reached.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _signing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record signature: $e')),
      );
    }
  }

  Future<void> _pushManifestToLedger() async {
    _cloudPhotoRefs ??= await Future.wait(widget.lot.photoPaths.map((path) async {
      if (path.startsWith('http://') || path.startsWith('https://')) return path;
      try {
        return await FirebaseService().uploadLotPhoto(
            lotId: widget.lot.id, localPath: path);
      } catch (_) {
        return path;
      }
    }));
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
      'photo_refs': _cloudPhotoRefs,
      'lot_reference_id': widget.lot.id,
      'collection_location': {
        'latitude': widget.lot.latitude,
        'longitude': widget.lot.longitude,
        'recorded_at': widget.lot.createdAt.toIso8601String(),
      },
      'checkpoint_dispatch': _manifest.checkpointDispatch != null
          ? {
              'signer_name': _dispatchSigner,
              'signature_hash': _manifest.checkpointDispatch!.signatureHash,
              'cumulative_hash': _manifest.checkpointDispatch!.cumulativeHash,
              'timestamp':
                  _manifest.checkpointDispatch!.timestamp.toIso8601String(),
              'latitude': _manifest.checkpointDispatch!.latitude,
              'longitude': _manifest.checkpointDispatch!.longitude,
            }
          : null,
      'checkpoint_transit': _manifest.checkpointTransit != null
          ? {
              'signer_name': _transitSigner,
              'signature_hash': _manifest.checkpointTransit!.signatureHash,
              'cumulative_hash': _manifest.checkpointTransit!.cumulativeHash,
              'timestamp':
                  _manifest.checkpointTransit!.timestamp.toIso8601String(),
              'latitude': _manifest.checkpointTransit!.latitude,
              'longitude': _manifest.checkpointTransit!.longitude,
            }
          : null,
      'checkpoint_delivery': _manifest.checkpointDelivery != null
          ? {
              'signer_name': _deliverySigner,
              'signature_hash': _manifest.checkpointDelivery!.signatureHash,
              'cumulative_hash': _manifest.checkpointDelivery!.cumulativeHash,
              'timestamp':
                  _manifest.checkpointDelivery!.timestamp.toIso8601String(),
              'latitude': _manifest.checkpointDelivery!.latitude,
              'longitude': _manifest.checkpointDelivery!.longitude,
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

  Future<void> _shareManifestPdf() async {
    final pdf = pw.Document();
    final checkpoints = <String, Form6Checkpoint?>{
      'Dispatch': _manifest.checkpointDispatch,
      'Transit': _manifest.checkpointTransit,
      'Recycler receipt': _manifest.checkpointDelivery,
    };
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('E-WASTE FORM-6 HANDOVER RECORD',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('Platform-generated handover record · Reference ${_manifest.manifestId}'),
        pw.Divider(),
        pw.Text('Sender / Kabadiwala: ${_manifest.senderName}'),
        pw.Text('Sender phone: ${_manifest.senderPhone}'),
        pw.Text('Destination recycler ID: ${_manifest.destinationRecyclerId}'),
        pw.Text('Lot reference: ${widget.lot.id}'),
        pw.Text('Material: ${_manifest.materialType} · ${_manifest.quantity} kg'),
        pw.Text('Collection GPS: ${widget.lot.latitude ?? 'Not recorded'}, ${widget.lot.longitude ?? 'Not recorded'}'),
        pw.Text('Collected at: ${widget.lot.createdAt.toIso8601String()}'),
        pw.SizedBox(height: 12),
        pw.Text('Transfer checkpoints', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...checkpoints.entries.map((entry) {
          final checkpoint = entry.value;
          if (checkpoint == null) return pw.Text('${entry.key}: Not signed');
          final signer = entry.key == 'Dispatch'
              ? _dispatchSigner
              : entry.key == 'Transit'
                  ? _transitSigner
                  : _deliverySigner;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${entry.key} · Signed by ${signer ?? 'Unknown'}'),
              pw.Text('Time ${checkpoint.timestamp.toIso8601String()} · GPS ${checkpoint.latitude ?? '—'}, ${checkpoint.longitude ?? '—'}'),
              pw.Text('Checkpoint hash ${checkpoint.cumulativeHash}'),
            ]),
          );
        }),
        pw.SizedBox(height: 10),
        pw.Text('Photo references: ${_cloudPhotoRefs?.join(', ') ?? widget.lot.photoPaths.join(', ')}'),
        pw.SizedBox(height: 18),
        pw.Text('This file summarizes the app handover record. Review and complete any required statutory Form-6 fields and signatures before regulatory submission.'),
      ],
    ));
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Form6-${_manifest.manifestId}.pdf',
    );
  }

  Future<void> _openPdfFiller() async {
    await launchUrl(Uri.parse(_pdfFillerFormUrl),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Form-6 Manifest')),
      body: SingleChildScrollView(
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
            if (widget.recyclerId.startsWith('sample-recycler-'))
              _workflowNotice(
                'Sample routing profile. This walkthrough does not book a real pickup.',
                AppColors.pending,
              ),
            if (_cloudLedgerUnavailable)
              _workflowNotice(
                'Cloud ledger unavailable. Checkpoint sync did not complete.',
                AppColors.error,
              ),
            if (widget.recyclerId.startsWith('sample-recycler-') ||
                _cloudLedgerUnavailable)
              const SizedBox(height: 12),
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
                      if (_cloudLedgerUnavailable) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'This presentation run is complete locally; one or more checkpoints did not sync to the cloud ledger.',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
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
            if (_stage == _Stage.complete) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _shareManifestPdf,
                icon: const Icon(Icons.download),
                label: const Text('Download / share Form-6 PDF'),
              ),
              OutlinedButton.icon(
                onPressed: _openPdfFiller,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open the fillable form on pdfFiller'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _workflowNotice(String message, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message, style: TextStyle(color: color)),
      );

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
