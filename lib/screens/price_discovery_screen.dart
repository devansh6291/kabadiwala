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

  // Illustrative per-item figures for the demo. Real offers depend on city,
  // condition, recovery grade, and the recycler's current buying rate.
  static const List<_ItemPriceGuide> _itemPrices = [
    _ItemPriceGuide('LED television', 'E-waste · mixed materials', 8, 20, 35),
    _ItemPriceGuide('CRT television', 'E-waste · glass and metals', 25, 8, 15),
    _ItemPriceGuide('Refrigerator', 'Appliance · steel and compressor', 55, 18, 30),
    _ItemPriceGuide('Washing machine', 'Appliance · steel and motor', 35, 18, 30),
    _ItemPriceGuide('Air conditioner', 'Appliance · copper and aluminium', 45, 35, 55),
    _ItemPriceGuide('Steel wardrobe / cupboard', 'Heavy furniture · steel', 40, 25, 38),
    _ItemPriceGuide('Steel office desk', 'Heavy furniture · steel', 28, 25, 38),
    _ItemPriceGuide('Wooden wardrobe', 'Heavy furniture · reusable wood', 35, 3, 8),
    _ItemPriceGuide('Wooden sofa frame', 'Heavy furniture · reusable wood', 25, 3, 8),
    _ItemPriceGuide('Desktop motherboard', 'PCB · mixed grade', 0.8, 180, 260),
    _ItemPriceGuide('Graphics card PCB', 'PCB · higher grade', 0.5, 260, 400),
    _ItemPriceGuide('Power-supply board', 'PCB · low / mixed grade', 1.2, 70, 120),
    _ItemPriceGuide('TV control / main board', 'PCB · mixed grade', 0.7, 100, 170),
    _ItemPriceGuide('Small switchboard', 'Electrical · switches and copper', 0.5, 25, 50),
    _ItemPriceGuide('Distribution switchboard', 'Electrical · steel and copper', 5, 35, 65),
    _ItemPriceGuide('Circuit breakers (lot)', 'Electrical · mixed metals', 1, 40, 75),
    _ItemPriceGuide('Copper power cable', 'Cable · copper', 1, 90, 140),
    _ItemPriceGuide('Ceiling fan with motor', 'Appliance · steel and copper', 4, 35, 60),
  ];

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
              itemCount: entries.length + _itemPrices.length + 2,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Item-by-item estimates', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text(
                        'Demo estimates use a typical item weight. “Customer receives” is the illustrative amount paid to the person handing it in; “Recycler resale” is an illustrative downstream value. These are sample figures, not confirmed local offers. Ask for a quote before collection.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  );
                }
                if (index <= _itemPrices.length) {
                  return _itemPriceCard(_itemPrices[index - 1]);
                }
                if (index == _itemPrices.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('Material benchmarks (per kg)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  );
                }
                final entry = entries[index - _itemPrices.length - 2];
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

  Widget _itemPriceCard(_ItemPriceGuide item) {
    final customerAmount = item.customerRatePerKg * item.typicalWeightKg;
    final recyclerAmount = item.recyclerRatePerKg * item.typicalWeightKg;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 3),
          Text('${item.material} · typical weight ${item.typicalWeightKg == item.typicalWeightKg.roundToDouble() ? item.typicalWeightKg.toStringAsFixed(0) : item.typicalWeightKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _priceStat('Customer receives (estimate)', customerAmount, AppColors.primaryGreen)),
            const SizedBox(width: 12),
            Expanded(child: _priceStat('Recycler resale (estimate)', recyclerAmount, AppColors.accent)),
          ]),
          const SizedBox(height: 7),
          Text('Demo rates: ₹${item.customerRatePerKg.toStringAsFixed(0)}/kg paid · ₹${item.recyclerRatePerKg.toStringAsFixed(0)}/kg resale', style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ]),
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

class _ItemPriceGuide {
  final String name;
  final String material;
  final double typicalWeightKg;
  final double customerRatePerKg;
  final double recyclerRatePerKg;

  const _ItemPriceGuide(this.name, this.material, this.typicalWeightKg,
      this.customerRatePerKg, this.recyclerRatePerKg);
}
