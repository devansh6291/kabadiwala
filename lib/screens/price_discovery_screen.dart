import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../services/api_client.dart';

class PriceDiscoveryScreen extends StatefulWidget {
  const PriceDiscoveryScreen({super.key});

  @override
  State<PriceDiscoveryScreen> createState() => _PriceDiscoveryScreenState();
}

class _PriceDiscoveryScreenState extends State<PriceDiscoveryScreen> {
  late Future<List<Map<String, dynamic>>> _pricesFuture;

  @override
  void initState() {
    super.initState();
    _pricesFuture = _fetchPrices();
  }

  Future<List<Map<String, dynamic>>> _fetchPrices() async {
    try {
      final response = await ApiClient().dio.get('/prices');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('[PRICE API ERROR] $e');
      throw Exception('Failed to load market prices.');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _pricesFuture = _fetchPrices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Current Prices'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pricesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading prices: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No market data available right now.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final entries = snapshot.data!;
          final byCategory = <String, List<Map<String, dynamic>>>{};
          for (final e in entries) {
            final cat = e['materialCategory'] ?? 'Unknown';
            byCategory.putIfAbsent(cat, () => []).add(e);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: byCategory.entries.map((group) {
                final category = group.key;
                final rows = group.value;

                final bestBuy = rows
                    .map((r) => (r['buyingPrice'] as num?)?.toDouble() ?? 0.0)
                    .reduce((a, b) => a > b ? a : b);
                final bestSell = rows
                    .map((r) => (r['sellingPrice'] as num?)?.toDouble() ?? 0.0)
                    .reduce((a, b) => a > b ? a : b);

                DateTime date;
                try {
                  date = DateTime.parse(rows.first['date']);
                } catch (_) {
                  date = DateTime.now();
                }

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
                                child: _priceStat('Recycler pays up to',
                                    bestSell, AppColors.primaryYellow)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Updated ${dateFormat.format(date)}  •  ${rows.first['location']}  •  per kg',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
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
