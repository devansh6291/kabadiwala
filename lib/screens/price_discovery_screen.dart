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

  // Display-only examples for material categories without a live quote feed.
  // They are explicitly marked as samples and must not be used as offers.
  static final List<Map<String, dynamic>> _samplePrices = <Map<String, dynamic>>[
    {'materialCategory': 'Steel scrap', 'price': 35.0},
    {'materialCategory': 'Iron scrap', 'price': 28.0},
    {'materialCategory': 'Brass scrap', 'price': 420.0},
    {'materialCategory': 'PET plastic', 'price': 25.0},
    {'materialCategory': 'HDPE plastic', 'price': 45.0},
    {'materialCategory': 'Cardboard', 'price': 12.0},
    {'materialCategory': 'Mixed paper', 'price': 10.0},
    {'materialCategory': 'Glass', 'price': 2.0},
    {'materialCategory': 'E-waste circuit boards', 'price': 250.0},
    {'materialCategory': 'E-waste cables', 'price': 90.0},
  ].map((entry) => {
        ...entry,
        'currency': 'INR',
        'unit': 'per_kg',
        'source': 'Sample display estimate',
        'isDemo': true,
      }).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _pricesFuture = _fetchPrices();
  }

  Future<List<Map<String, dynamic>>> _fetchPrices() async {
    try {
      final response = await ApiClient().dio.get('/prices');
      final liveEntries = List<Map<String, dynamic>>.from(response.data);
      final liveNames = liveEntries
          .map((entry) => entry['materialCategory']?.toString().toLowerCase())
          .toSet();
      final additionalSamples = _samplePrices.where((entry) =>
          !liveNames.contains(entry['materialCategory'].toString().toLowerCase()));
      return [...liveEntries, ...additionalSamples];
    } catch (e) {
      debugPrint('[PRICE API ERROR] $e');
      return _samplePrices;
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
        title: const Text('Material Price Guide'),
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Text(
                    'Live metal benchmarks are global references. Other material prices are sample display estimates only, not live local offers. Actual rates vary by grade, quality, quantity, and location.',
                    style: TextStyle(color: AppColors.textSecondary),
                  );
                }
                final entry = entries[index - 1];
                final date = DateTime.tryParse(entry['date']?.toString() ?? '')
                    ?.toLocal();
                final price = (entry['price'] as num?)?.toDouble() ?? 0.0;
                final isDemo = entry['isDemo'] == true;
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry['materialCategory']?.toString() ?? 'Metal',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        _priceStat(isDemo ? 'Sample estimate' : 'Global reference', price,
                            AppColors.primaryGreen),
                        const SizedBox(height: 8),
                        Text(
                          '${isDemo ? 'Demo only — verify local rates' : date == null ? 'Latest available' : 'Updated ${dateFormat.format(date)}'}  •  ${entry['source'] ?? 'Live market API'}  •  per kg',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45),
                        ),
                        if (entry['changePercent'] is num)
                          Text('Change: ${(entry['changePercent'] as num).toStringAsFixed(2)}%',
                              style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
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
        Text('₹${value.toStringAsFixed(2)}/kg',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
