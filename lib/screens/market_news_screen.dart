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

  @override
  void initState() {
    super.initState();
    _newsFuture = _fetchNews();
  }

  Future<List<Map<String, dynamic>>> _fetchNews() async {
    try {
      final response = await ApiClient().dio.get('/news');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('[NEWS API ERROR] $e');
      throw Exception('Failed to load market news.');
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
                          '${item['source'] ?? 'Kabadiwala Connect'}  •  ${dateFormat.format(date)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                              fontStyle: FontStyle.italic),
                        ),
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
