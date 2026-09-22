import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../data/news_mock_data.dart';

class MarketNewsScreen extends StatelessWidget {
  const MarketNewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = NewsMockData.latest();
    final dateFormat = DateFormat('d MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Market & Policy News')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(item.snippet,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(
                    '${item.source} · ${dateFormat.format(item.date)}',
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
  }
}
