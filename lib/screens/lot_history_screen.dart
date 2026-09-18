import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../models/lot.dart';
import '../models/lot_store.dart';

class LotHistoryScreen extends StatefulWidget {
  const LotHistoryScreen({super.key});

  @override
  State<LotHistoryScreen> createState() => _LotHistoryScreenState();
}

class _LotHistoryScreenState extends State<LotHistoryScreen> {
  final DateFormat _dateFormat = DateFormat('d MMM, h:mm a');

  @override
  Widget build(BuildContext context) {
    final lots = LotStore.getAllLots();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Lots')),
      body: lots.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No lots yet. Create your first lot to see it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _LotCard(
                  lot: lots[index],
                  dateFormat: _dateFormat,
                ),
              ),
            ),
    );
  }
}

class _LotCard extends StatelessWidget {
  final Lot lot;
  final DateFormat dateFormat;

  const _LotCard({required this.lot, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = lot.photoPaths.isNotEmpty && File(lot.photoPaths.first).existsSync();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasPhoto
                  ? Image.file(
                      File(lot.photoPaths.first),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: AppColors.background,
                      child: const Icon(Icons.inventory_2, color: AppColors.primaryGreen),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lot.subCategory != null
                              ? '${lot.category} · ${lot.subCategory}'
                              : lot.category,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      _StatusBadge(status: lot.syncStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lot.approxWeightKg} kg'
                    '${lot.estimatedValue != null ? ' · ~₹${lot.estimatedValue!.toStringAsFixed(0)}' : ''}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(lot.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSyncStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}