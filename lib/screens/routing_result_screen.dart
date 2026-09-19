import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/lot.dart';
import '../services/recycler_matching_services.dart';
import 'form6_signing_screen.dart';
import 'terms_conditions_screen.dart';

/// Shows where a lot ended up after routing: straight to a recycler,
/// pooling toward one, ready for pickup, or held at a storage-only
/// Kabadiwala until the pool completes (idea doc sections 3.2–3.3).
class RoutingResultScreen extends StatefulWidget {
  final Lot lot;

  const RoutingResultScreen({super.key, required this.lot});

  @override
  State<RoutingResultScreen> createState() => _RoutingResultScreenState();
}

class _RoutingResultScreenState extends State<RoutingResultScreen> {
  RoutingResult? _result;
  bool _declinedStorage = false;
  bool _askedStorage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askStorageThenRoute());
  }

  Future<void> _askStorageThenRoute() async {
    if (_askedStorage) return;
    _askedStorage = true;

    final hasStorage = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage check'),
        content: const Text(
          'If this needs to be pooled with other collectors before a vehicle '
          'is sent, can you hold onto it yourself until then?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, I need storage'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, I can hold it'),
          ),
        ],
      ),
    );

    var result = RecyclerMatchingService.route(widget.lot,
        hasStorage: hasStorage ?? true);

    // If routed to a storage point, require the custody Terms &
    // Conditions to be accepted before this is treated as final.
    if (result.outcome == RoutingOutcome.routedToStorage && mounted) {
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TermsConditionsScreen(storageProvider: result.storageKabadiwala!),
        ),
      );

      if (accepted != true) {
        // Collector declined custody terms — re-route without storage
        // so they're at least still pooling, just without a storage
        // assignment. Flag this in the UI via _declinedStorage.
        _declinedStorage = true;
        result = RecyclerMatchingService.route(widget.lot, hasStorage: true);
      }
    }

    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Routing')),
      body: result == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: _buildResultBody(context, result),
            ),
    );
  }

  Widget _buildResultBody(BuildContext context, RoutingResult result) {
    switch (result.outcome) {
      case RoutingOutcome.noRecyclerAvailable:
        return _statusCard(
          icon: Icons.error_outline,
          color: AppColors.statusFailed,
          title: 'No authorized recycler yet',
          subtitle:
              'No recycler currently accepts "${widget.lot.category}" in this area. '
              'The lot is saved and will route automatically once one is available.',
        );

      case RoutingOutcome.directDispatch:
        return _statusCard(
          icon: Icons.local_shipping,
          color: AppColors.primaryGreen,
          title: 'Routed directly',
          subtitle:
              'This lot alone meets ${result.recycler!.name}\'s minimum vehicle '
              'capacity (${result.recycler!.minVehicleCapacityKg.toStringAsFixed(0)} kg). '
              'Pickup will be scheduled directly — no pooling needed.',
        );

      case RoutingOutcome.pooling:
        return _poolingCard(result, ready: false);

      case RoutingOutcome.poolReadyForPickup:
        return _poolingCard(result, ready: true);

      case RoutingOutcome.routedToStorage:
        return _storageCard(result);
    }
  }

  Widget _poolingCard(RoutingResult result, {required bool ready}) {
    final pool = result.pool!;
    final progress = (pool.totalWeightKg / pool.thresholdKg).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_declinedStorage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _statusCard(
              icon: Icons.info_outline,
              color: AppColors.primaryYellow,
              title: 'Storage declined',
              subtitle:
                  'You\'re still pooling toward this recycler, just without a storage assignment.',
            ),
          ),
        _statusCard(
          icon: ready ? Icons.check_circle : Icons.hourglass_bottom,
          color: ready ? AppColors.primaryGreen : AppColors.primaryYellow,
          title: ready
              ? 'Pool ready for pickup!'
              : 'Pooling with nearby collectors',
          subtitle: 'Target: ${result.recycler!.name} · ${pool.category}\n'
              '${pool.totalWeightKg.toStringAsFixed(1)} / ${pool.thresholdKg.toStringAsFixed(0)} kg collected'
              '${ready ? '' : ' · ${pool.remainingKg.toStringAsFixed(1)} kg to go'}',
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.lightGreen.withValues(alpha: 0.3),
            color: ready ? AppColors.primaryGreen : AppColors.primaryYellow,
          ),
        ),
        if (ready) ...[
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Form6SigningScreen(
                      lot: widget.lot,
                      recyclerId: result.recycler!.recyclerId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.description),
              label: const Text('Start Form-6 Handover',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _storageCard(RoutingResult result) {
    final pool = result.pool!;
    final rate = result.storageKabadiwala!.storageRatePerItemPerWeek ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusCard(
          icon: Icons.warehouse,
          color: AppColors.primaryYellow,
          title: 'Routed to storage',
          subtitle:
              '${result.storageKabadiwala!.name} will hold this at ₹${rate.toStringAsFixed(0)}/item/week '
              'until ${result.recycler!.name}\'s pool reaches ${pool.thresholdKg.toStringAsFixed(0)} kg. '
              'They only custody it — they don\'t process or resell it.',
        ),
        const SizedBox(height: 16),
        _statusCard(
          icon: Icons.scale,
          color: AppColors.primaryGreen,
          title: 'Pool progress',
          subtitle:
              '${pool.totalWeightKg.toStringAsFixed(1)} / ${pool.thresholdKg.toStringAsFixed(0)} kg '
              'toward ${result.recycler!.name}',
        ),
      ],
    );
  }

  Widget _statusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
