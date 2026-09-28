import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows a self-contained, scannable transaction record that works offline.
class TransactionQrButton extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionQrButton({super.key, required this.transaction});

  static Future<void> show(BuildContext context, Map<String, dynamic> data) =>
      showDialog<void>(
        context: context,
        builder: (context) {
          final encoded = _readableTransactionText(data);
          return AlertDialog(
            title: const Text('Transaction QR'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 260,
                  height: 260,
                  child: QrImageView(
                    data: encoded,
                    version: QrVersions.auto,
                    size: 260,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'QR could not be generated. The transaction data may be too large.\n$error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'Transaction ${data['transactionId'] ?? '—'}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan this code to read the lot, parties, materials, values, location, and payment record.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('QR contents',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      encoded,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );

  static String _readableTransactionText(Map<String, dynamic> data) {
    final lines = <String>['KABADIWALA CONNECT — TRANSACTION RECORD'];
    _appendFields(data, lines, 0);
    return lines.join('\n');
  }

  static void _appendFields(
    Map<dynamic, dynamic> fields,
    List<String> lines,
    int depth,
  ) {
    for (final entry in fields.entries) {
      final key = entry.key.toString();
      if (key == 'schema' ||
          key == 'recordedTransaction' ||
          key == 'recordedPayment') {
        continue;
      }
      final value = entry.value;
      if (value == null || value.toString().isEmpty) continue;
      final label = _fieldLabel(key);
      final prefix = '  ' * depth;
      if (value is Map) {
        lines.add('$prefix$label');
        _appendFields(value, lines, depth + 1);
      } else if (value is List) {
        if (value.isEmpty) continue;
        lines.add('$prefix$label:');
        for (final item in value) {
          if (item is Map) {
            lines.add('${prefix}  •');
            _appendFields(item, lines, depth + 2);
          } else {
            lines.add('${prefix}  • ${item.toString()}');
          }
        }
      } else {
        lines.add('$prefix$label: ${value.toString()}');
      }
    }
  }

  static String _fieldLabel(String key) {
    const overrides = {
      'transactionId': 'Transaction ID',
      'manifestId': 'Manifest ID',
      'lotId': 'Lot ID',
      'collector': 'Collector',
      'recycler': 'Recycler',
      'material': 'Material',
      'values': 'Price details',
      'payment': 'Payment details',
      'collection': 'Collection details',
      'checkpoints': 'Handover checkpoints',
      'chainHash': 'Verification chain hash',
      'photoReferences': 'Photo references',
      'weightKg': 'Weight (kg)',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'recordedAt': 'Recorded at',
      'createdAt': 'Created at',
      'signatureHash': 'Signature hash',
      'cumulativeHash': 'Checkpoint chain hash',
      'finalSale': 'Final sale value (₹)',
      'finalPrice': 'Final sale value (₹)',
      'quoted': 'Quoted value (₹)',
      'quotedPrice': 'Quoted value (₹)',
      'estimated': 'Estimated value (₹)',
      'estimatedValue': 'Estimated value (₹)',
      'amount': 'Amount (₹)',
      'currency': 'Currency',
      'status': 'Status',
      'paymentStatus': 'Payment status',
      'transactionStatus': 'Transaction status',
      'signerName': 'Signed by',
      'subCategory': 'Subcategory',
      'category': 'Category',
    };
    final override = overrides[key];
    if (override != null) return override;
    final spaced = key
        .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match[1]} ${match[2]}')
        .replaceAll('_', ' ');
    return spaced.isEmpty
        ? spaced
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Show transaction QR',
        icon: const Icon(Icons.qr_code_2),
        onPressed: () => show(context, transaction),
      );
}
