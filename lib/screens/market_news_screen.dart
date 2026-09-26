import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../services/api_client.dart';

class MarketNewsScreen extends StatefulWidget {
  const MarketNewsScreen({super.key});

  @override
  State<MarketNewsScreen> createState() => _MarketNewsScreenState();
}

class _MarketNewsScreenState extends State<MarketNewsScreen> {
  late Future<List<Map<String, dynamic>>> _newsFuture;

  static const List<Map<String, dynamic>> _sampleNews = [
    {
      'title': 'Sample update: Keep batteries separate from mixed e-waste',
      'snippet': 'Store damaged or used batteries separately and take them to an appropriate collection point. This is sample guidance, not a current news report.',
      'source': 'Demo content',
      'isDemo': true,
    },
    {
      'title': 'Sample update: Check recycler authorization before drop-off',
      'snippet': 'Ask the recycler what materials they accept and verify required authorizations before handing over regulated waste. This is sample guidance, not a current news report.',
      'source': 'Demo content',
      'isDemo': true,
    },
    {
      'title': 'Sample update: Sort paper, metals, and plastics separately',
      'snippet': 'Clean sorting can make collection and recycling easier. Confirm local collection rules because accepted materials vary by location. This is sample guidance, not a current news report.',
      'source': 'Demo content',
      'isDemo': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _newsFuture = _fetchNews();
  }

  Future<List<Map<String, dynamic>>> _fetchNews() async {
    try {
      final response = await ApiClient().dio.get('/news');
      final items = List<Map<String, dynamic>>.from(response.data);
      return items.isEmpty ? _sampleNews : items;
    } catch (e) {
      debugPrint('[NEWS API ERROR] $e');
      return _sampleNews;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _newsFuture = _fetchNews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Market & Policy News'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading news: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No recent news available.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final items = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                DateTime date;
                try {
                  date = DateTime.parse(item['date']);
                } catch (_) {
                  date = DateTime.now();
                }

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] ?? 'Update',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(item['snippet'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text(
                          item['isDemo'] == true
                              ? 'Demo content • not current news'
                              : '${item['source'] ?? 'Kabadiwala Connect'}  •  ${dateFormat.format(date)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                              fontStyle: FontStyle.italic),
                        ),
                        if (item['url'] != null && item['isDemo'] != true) ...[
                          const SizedBox(height: 6),
                          SelectableText(
                            item['url'].toString(),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.primaryGreen),
                          ),
                        ],
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
}
