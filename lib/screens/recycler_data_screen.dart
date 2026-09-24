import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/recycler.dart';
import '../services/backend_service.dart';

/// Lists authorized recyclers/aggregators from the live backend database.
class RecyclerDataScreen extends StatefulWidget {
  const RecyclerDataScreen({super.key});

  @override
  State<RecyclerDataScreen> createState() => _RecyclerDataScreenState();
}

class _RecyclerDataScreenState extends State<RecyclerDataScreen> {
  late Future<List<Recycler>> _recyclersFuture;

  @override
  void initState() {
    super.initState();
    _recyclersFuture = BackendService().getRecyclers();
  }

  Future<void> _refresh() async {
    setState(() {
      _recyclersFuture = BackendService().getRecyclers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recyclers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          )
        ],
      ),
      body: FutureBuilder<List<Recycler>>(
        future: _recyclersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading recyclers: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No authorized recyclers found nearby.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Filter out storage-only Kabadiwalas so only actual processing recyclers show
          final recyclers =
              snapshot.data!.where((r) => !r.isStorageOnly).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: recyclers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _recyclerCard(recyclers[index]),
            ),
          );
        },
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
