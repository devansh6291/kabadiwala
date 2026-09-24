import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/lot.dart';
import '../services/recycler_matching_services.dart';
import 'form6_signing_screen.dart';

class BatchRoutingSummaryScreen extends StatefulWidget {
  final List<Lot> lots;
  final bool hasStorage;

  const BatchRoutingSummaryScreen(
      {super.key, required this.lots, required this.hasStorage});

  @override
  State<BatchRoutingSummaryScreen> createState() =>
      _BatchRoutingSummaryScreenState();
}

class _BatchRoutingSummaryScreenState extends State<BatchRoutingSummaryScreen> {
  late Future<List<MapEntry<Lot, RoutingResult>>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = _computeAllRoutes();
  }

  Future<List<MapEntry<Lot, RoutingResult>>> _computeAllRoutes() async {
    // Await API resolution for every lot in the batch simultaneously
    final futures = widget.lots.map((lot) async {
      final res = await RecyclerMatchingService.route(lot,
          hasStorage: widget.hasStorage);
      return MapEntry(lot, res);
    });
    return Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Routing Summary')),
      body: FutureBuilder<List<MapEntry<Lot, RoutingResult>>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Calculating optimal routes...',
                    style: TextStyle(color: AppColors.textSecondary))
              ],
            ));
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Routing Error: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error)));
          }

          final results = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _resultCard(results[index]),
          );
        },
      ),
    );
  }

  Widget _resultCard(MapEntry<Lot, RoutingResult> entry) {
    final lot = entry.key;
    final result = entry.value;

    late IconData icon;
    late Color color;
    late String title;
    late String subtitle;
    bool showForm6Button = false;

    switch (result.outcome) {
      case RoutingOutcome.noRecyclerAvailable:
        icon = Icons.error_outline;
        color = AppColors.statusFailed;
        title = 'No recycler available';
        subtitle =
            'No authorized recycler currently accepts "${lot.category}".';
        break;
      case RoutingOutcome.directDispatch:
        icon = Icons.local_shipping;
        color = AppColors.primaryGreen;
        title = 'Routed directly';
        subtitle =
            'Meets ${result.recycler!.name}\'s vehicle capacity alone  •  pickup scheduled directly.';
        break;
      case RoutingOutcome.pooling:
        icon = Icons.hourglass_bottom;
        color = AppColors.primaryYellow;
        title = 'Pooling';
        subtitle =
            '${result.pool!.totalWeightKg.toStringAsFixed(1)} / ${result.pool!.thresholdKg.toStringAsFixed(0)} kg '
            'toward ${result.recycler!.name}.';
        break;
      case RoutingOutcome.poolReadyForPickup:
        icon = Icons.check_circle;
        color = AppColors.primaryGreen;
        title = 'Pool ready for pickup';
        subtitle =
            'Threshold reached for ${result.recycler!.name}  •  Form-6 handover can begin.';
        showForm6Button = true;
        break;
      case RoutingOutcome.routedToStorage:
        icon = Icons.warehouse;
        color = AppColors.primaryYellow;
        title = 'Routed to storage';
        subtitle =
            'Held by ${result.storageKabadiwala!.name} until ${result.recycler!.name}\'s pool completes.';
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lot.subCategory != null
                            ? '${lot.category}  •  ${lot.subCategory}'
                            : lot.category,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text('${lot.approxWeightKg} kg',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            if (showForm6Button) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Form6SigningScreen(
                            lot: lot, recyclerId: result.recycler!.recyclerId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description, size: 18),
                  label: const Text('Start Form-6'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
