import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../app_colors.dart';
import '../services/api_client.dart';

class PriceDiscoveryScreen extends StatefulWidget {
  final String languageCode;
  const PriceDiscoveryScreen({super.key, this.languageCode = 'hi'});

  @override
  State<PriceDiscoveryScreen> createState() => _PriceDiscoveryScreenState();
}

class _PriceDiscoveryScreenState extends State<PriceDiscoveryScreen> {
  final FlutterTts _speech = FlutterTts();
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

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _speakPrice(Map<String, dynamic> entry) async {
    final material = entry['materialCategory']?.toString() ?? 'material';
    final amount = (entry['price'] as num?)?.toDouble() ?? 0;
    final location = entry['location']?.toString();
    final lang = widget.languageCode;
    final locale = lang == 'mr' ? 'mr-IN' : lang == 'hi' ? 'hi-IN' : 'en-IN';
    final sentence = lang == 'mr'
        ? '$material. खरेदीचा दर ${amount.toStringAsFixed(0)} रुपये प्रति किलो. ${location ?? ''}'
        : lang == 'hi'
            ? '$material. खरीदने का भाव ${amount.toStringAsFixed(0)} रुपये प्रति किलो. ${location ?? ''}'
            : '$material. Buying reference ${amount.toStringAsFixed(0)} rupees per kilogram. ${location ?? ''}';
    try {
      await _speech.setLanguage(locale);
      await _speech.setSpeechRate(0.42);
      await _speech.speak(sentence);
    } catch (e) {
      debugPrint('[PRICE SPEECH ERROR] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech is unavailable. Check the device text-to-speech voice settings.')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPrices() async {
    final api = ApiClient().dio;
    List<Map<String, dynamic>> liveEntries = [];
    List<Map<String, dynamic>> fieldEntries = [];
    try {
      final response = await api.get('/prices');
      liveEntries = List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('[PRICE API ERROR] $e');
    }
    try {
      final response = await api.get('/price-dataset');
      fieldEntries = List<Map<String, dynamic>>.from(response.data).map((entry) => {
        ...entry,
        'price': entry['buyingPrice'],
        'changePercent': entry['trendPercent'],
        'isFieldData': true,
      }).toList();
    } catch (e) {
      debugPrint('[FIELD PRICE DATA ERROR] $e');
    }

    final observedNames = {...liveEntries, ...fieldEntries}
        .map((entry) => entry['materialCategory']?.toString().toLowerCase())
        .toSet();
    final additionalSamples = _samplePrices.where((entry) =>
        !observedNames.contains(entry['materialCategory'].toString().toLowerCase()));
    return [...fieldEntries, ...liveEntries, ...additionalSamples];
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
                    child: Text('Market references and recorded field prices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  );
                }
                final entry = entries[index - _itemPrices.length - 2];
                final date = DateTime.tryParse(entry['date']?.toString() ?? '')
                    ?.toLocal();
                final price = (entry['price'] as num?)?.toDouble() ?? 0.0;
                final isDemo = entry['isDemo'] == true;
                final isFieldData = entry['isFieldData'] == true;
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
                        Row(children: [
                          Expanded(child: _priceStat(isDemo ? 'Indicative estimate' : isFieldData ? 'Latest collector buying price' : 'Global reference', price,
                              AppColors.primaryGreen)),
                          IconButton(
                            tooltip: 'Speak price',
                            onPressed: () => _speakPrice(entry),
                            icon: const Icon(Icons.volume_up, color: AppColors.primaryGreen),
                          ),
                        ]),
                        if (isFieldData) ...[
                          const SizedBox(height: 8),
                          Text('Recycler/aggregator offer: ₹${(entry['sellingPrice'] as num?)?.toStringAsFixed(2) ?? '—'}  •  Range: ₹${(entry['marketRangeLow'] as num?)?.toStringAsFixed(2) ?? '—'}–₹${(entry['marketRangeHigh'] as num?)?.toStringAsFixed(2) ?? '—'}  •  ${entry['location'] ?? 'Location not recorded'}', style: const TextStyle(fontSize: 12)),
                          Text('${entry['materialSubCategory'] ?? entry['materialCategory']}  •  ${(entry['observations'] ?? 0)} observations', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${isDemo ? 'Indicative only — verify local rates' : date == null ? 'Latest available' : 'Updated ${dateFormat.format(date)}'}  •  ${entry['source'] ?? 'Live market API'}  •  ${entry['unit'] ?? 'per kg'}',
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
            Expanded(child: _priceStat('Customer receives (estimate)', customerAmount, AppColors.primaryGreen, unitLabel: ' total')),
            const SizedBox(width: 12),
            Expanded(child: _priceStat('Recycler resale (estimate)', recyclerAmount, AppColors.accent, unitLabel: ' total')),
          ]),
          const SizedBox(height: 7),
          Text('Demo rates: ₹${item.customerRatePerKg.toStringAsFixed(0)}/kg paid · ₹${item.recyclerRatePerKg.toStringAsFixed(0)}/kg resale', style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ]),
      ),
    );
  }

  Widget _priceStat(String label, double value, Color color,
      {String unitLabel = '/kg'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text('₹${value.toStringAsFixed(2)}$unitLabel',
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
