import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../data/price_mock_data.dart';
import '../models/price_dataset_entry.dart';

/// Current buying/selling price trends by category. NOTE: backed by mock
/// data derived from RecyclerMockData until a real price-discovery API
/// exists — the "Indicative" label below must stay until real data is
/// wired in, since collectors could otherwise make real decisions off
/// fabricated numbers.
class PriceDiscoveryScreen extends StatelessWidget {
  const PriceDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = PriceMockData.latest();
    final dateFormat = DateFormat('d MMM');

    final byCategory = <String, List<PriceDatasetEntry>>{};
    for (final e in entries) {
      byCategory.putIfAbsent(e.materialCategory, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Current Prices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.black54),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Indicative rates only — not live market data yet.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          ...byCategory.entries.map((group) {
            final category = group.key;
            final rows = group.value;
            final bestBuy =
                rows.map((r) => r.buyingPrice).reduce((a, b) => a > b ? a : b);
            final bestSell =
                rows.map((r) => r.sellingPrice).reduce((a, b) => a > b ? a : b);

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _priceStat('You get paid up to', bestBuy,
                                AppColors.primaryGreen)),
                        Expanded(
                            child: _priceStat('Recycler pays up to', bestSell,
                                AppColors.primaryYellow)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updated ${dateFormat.format(rows.first.date)} · ${rows.first.location} · per kg',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _priceStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text('₹${value.toStringAsFixed(0)}/kg',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
