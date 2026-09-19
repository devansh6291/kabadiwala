import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/material_categories.dart';
import '../models/lot.dart';
import '../models/lot_store.dart';
import '../services/classifier_service.dart';
import '../widgets/lot_photo_image.dart';
import 'batch_routing_summary_screen.dart';

/// Final check before saving: one card per item, each with its own photo
/// (since items are now captured one-photo-per-item, not one group photo).
/// Lets the collector fix anything before it's saved and routed.
class DetectedItemsReviewScreen extends StatefulWidget {
  final List<DetectedItem> items;
  final double? latitude;
  final double? longitude;

  const DetectedItemsReviewScreen({
    super.key,
    required this.items,
    this.latitude,
    this.longitude,
  });

  @override
  State<DetectedItemsReviewScreen> createState() =>
      _DetectedItemsReviewScreenState();
}

class _DetectedItemsReviewScreenState extends State<DetectedItemsReviewScreen> {
  final List<DetectedItem> _items = [];
  final List<TextEditingController> _weightControllers = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items.addAll(widget.items);
    _weightControllers.addAll(
      _items.map(
          (i) => TextEditingController(text: i.estimatedWeightKg.toString())),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _weightControllers.removeAt(index).dispose();
    });
  }

  @override
  void dispose() {
    for (final c in _weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmAndRoute() async {
    if (_items.isEmpty) return;

    final hasStorage = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage check'),
        content: const Text(
          'For anything that needs to be pooled with nearby collectors before '
          'a vehicle is sent, can you hold onto it yourself until then?',
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
    if (hasStorage == null) return;

    setState(() => _saving = true);

    final List<Lot> savedLots = [];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final weight =
          double.tryParse(_weightControllers[i].text) ?? item.estimatedWeightKg;

      final lot = Lot(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        category: item.category,
        subCategory: item.subCategory,
        approxWeightKg: weight,
        photoPaths: [item.photoPath],
        estimatedValue: item.estimatedValue,
        createdAt: DateTime.now(),
        latitude: widget.latitude,
        longitude: widget.longitude,
        syncStatus: 'pending',
      );
      await LotStore.addLot(lot);
      savedLots.add(lot);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BatchRoutingSummaryScreen(lots: savedLots, hasStorage: hasStorage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Review Items (${_items.length})')),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('All items removed.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _itemCard(index),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed:
                    (_saving || _items.isEmpty) ? null : _confirmAndRoute,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.local_shipping),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : 'Confirm & Route All (${_items.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(int index) {
    final item = _items[index];
    final categoryData = MaterialCategories.byLabel(item.category);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LotPhotoImage(
                  path: item.photoPath,
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: item.category,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: MaterialCategories.all
                        .map((c) => DropdownMenuItem(
                            value: c.label, child: Text(c.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        item.category = value;
                        item.subCategory = null;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.black45),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            if (categoryData.subCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: categoryData.subCategories.map((sub) {
                  final selected = item.subCategory == sub;
                  return ChoiceChip(
                    label: Text(sub, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: AppColors.primaryGreen,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87),
                    onSelected: (sel) =>
                        setState(() => item.subCategory = sel ? sub : null),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Weight (kg): ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _weightControllers[index],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const Spacer(),
                Text(
                  '~₹${item.estimatedValue.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
