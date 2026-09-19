import 'dart:io';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/lot.dart';
import '../services/classifier_service.dart';
import 'routing_result_screen.dart';

/// Shown right after a lot is captured: what the classifier thinks the
/// material and condition are, and the resulting value estimate, before
/// the lot is routed to a recycler / pool / storage point.
class ClassificationResultScreen extends StatelessWidget {
  final Lot lot;
  final ClassificationResult result;

  const ClassificationResultScreen({
    super.key,
    required this.lot,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        lot.photoPaths.isNotEmpty && File(lot.photoPaths.first).existsSync();
    final isBad = result.condition == 'bad';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Classification Result')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(lot.photoPaths.first),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Material', lot.category),
                    if (result.suggestedSubCategory != null)
                      _row('Sub-category', result.suggestedSubCategory!),
                    _row('Weight', '${lot.approxWeightKg} kg'),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Condition',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.forCondition(result.condition)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isBad ? 'Needs review' : 'Good',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forCondition(result.condition),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isBad) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Lower confidence — a human should double-check this one at the recycler dashboard.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated value',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '₹${result.estimatedValue.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoutingResultScreen(lot: lot),
                    ),
                  );
                },
                icon: const Icon(Icons.local_shipping),
                label: const Text('Confirm & Route to Recycler',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
