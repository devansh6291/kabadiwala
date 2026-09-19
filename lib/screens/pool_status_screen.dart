import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/pool.dart';

class PoolStatusScreen extends StatelessWidget {
  final Pool pool;
  const PoolStatusScreen({super.key, required this.pool});

  static const _steps = [
    ('Pool Forming', PoolStatus.collecting),
    ('Stored (awaiting pool)', PoolStatus.storageNeeded),
    ('Pool Ready', PoolStatus.readyForPickup),
    ('Vehicle Dispatched', PoolStatus.dispatched),
  ];

  int get _currentIndex {
    // storageNeeded can happen alongside collecting, not strictly after
    // it, so treat them as the same step for progress purposes — only
    // readyForPickup/dispatched represent real forward progress.
    switch (pool.status) {
      case PoolStatus.collecting:
      case PoolStatus.storageNeeded:
        return 0;
      case PoolStatus.readyForPickup:
        return 2;
      case PoolStatus.dispatched:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pool Status')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${pool.totalWeightKg.toStringAsFixed(1)} / ${pool.thresholdKg.toStringAsFixed(0)} kg pooled',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${pool.category} • ${pool.entries.length} contributor(s)',
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (pool.totalWeightKg / pool.thresholdKg).clamp(0, 1),
                color: AppColors.primaryGreen,
                backgroundColor: Colors.grey.shade200,
                minHeight: 8,
              ),
            ),
            if (pool.status == PoolStatus.storageNeeded) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2,
                        color: AppColors.primaryYellow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pool.storageKabadiwalaId != null
                            ? 'Your item is being safely stored until the pool is ready.'
                            : 'Waiting for a storage host to be assigned.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final done = index <= _currentIndex;
                  return ListTile(
                    leading: Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? AppColors.primaryGreen : Colors.grey,
                    ),
                    title: Text(
                      _steps[index].$1,
                      style: TextStyle(
                        fontWeight: done ? FontWeight.w600 : FontWeight.normal,
                        color: done ? AppColors.textPrimary : Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (pool.status == PoolStatus.dispatched)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to the Form-6 tracking / signing screen for
                    // this pool once that screen accepts a Pool instead
                    // of a single Lot — see next step.
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View Form-6 Handover Status'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
