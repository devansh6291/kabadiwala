import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/storage_host.dart';

/// Custody/storage agreement shown before a lot is routed to a large
/// Kabadiwala's storage point (idea doc section 4 — binding custody
/// undertaking).
class TermsConditionsScreen extends StatefulWidget {
  final StorageHost storageProvider;
  const TermsConditionsScreen({super.key, required this.storageProvider});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool accepted = false;

  @override
  Widget build(BuildContext context) {
    final rate = widget.storageProvider.weeklyRatePerItem;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Storage Agreement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.storageProvider.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${rate.toStringAsFixed(0)} per item, per week',
              style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'By storing your item(s) here:\n\n'
                  '• The host will hold your material safely and unmodified until the pool reaches the recycler\'s minimum pickup capacity.\n'
                  '• The host will NOT sell, use, or transfer your item(s) to anyone else during this period.\n'
                  '• You will be paid the agreed weekly storage rate for as long as your item(s) remain stored.\n'
                  '• Once the pool is complete, your item(s) move directly to the matched recycler under a signed Form-6 handover record.\n'
                  '• You can track storage status at any time from your pool status screen.',
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: const Text('I have read and agree to these terms'),
              activeColor: AppColors.primaryGreen,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      accepted ? AppColors.primaryYellow : Colors.grey.shade300,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: accepted ? () => Navigator.pop(context, true) : null,
                child: const Text('Accept & Store Item',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Center(
                child: Text('Decline', style: TextStyle(color: Colors.black54)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
