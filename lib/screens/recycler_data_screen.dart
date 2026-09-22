import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/recycler_mock_data.dart';
import '../models/recycler.dart';

/// Lists authorized recyclers/aggregators this collector's lots could be
/// routed to. Backed by RecyclerMockData until the backend recycler
/// directory API exists — same data source recycler_matching_service.dart
/// already depends on.
class RecyclerDataScreen extends StatelessWidget {
  const RecyclerDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recyclers =
        RecyclerMockData.all.where((r) => !r.isStorageOnly).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Recyclers')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: recyclers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _recyclerCard(recyclers[index]),
      ),
    );
  }

  Widget _recyclerCard(Recycler r) {
    final statusColor = r.authorizationStatus == 'authorized'
        ? AppColors.success
        : r.authorizationStatus == 'pending'
            ? AppColors.pending
            : AppColors.statusFailed;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(r.authorizationStatus,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.materialsAccepted
                  .map((m) => Chip(
                        label: Text(m, style: const TextStyle(fontSize: 11)),
                        backgroundColor:
                            AppColors.lightGreen.withValues(alpha: 0.2),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            if (r.offeredRates.isNotEmpty)
              Text(
                r.offeredRates.entries
                    .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}/kg')
                    .join('  •  '),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_shipping,
                    size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Text('Pickup: ${r.pickupAvailability}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(width: 16),
                const Icon(Icons.scale, size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Text('Min ${r.minVehicleCapacityKg.toStringAsFixed(0)} kg',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 4),
            Text(r.contactDetails,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
