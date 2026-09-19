import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/material_categories.dart';
import '../services/classifier_service.dart';
import '../services/location_service.dart';
import '../widgets/lot_photo_image.dart';
import 'camera_capture_screen.dart';
import 'detected_items_review_screen.dart';

/// A collection session: tap "Add Item", take one photo of one item, it
/// gets classified immediately, repeat for everything collected today,
/// then review everything at once before routing.
class CreateLotScreen extends StatefulWidget {
  final ClassifierService? classifierService;

  const CreateLotScreen({super.key, this.classifierService});

  @override
  State<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends State<CreateLotScreen> {
  late final ClassifierService _classifierService =
      widget.classifierService ?? ManualClassifierService();

  final List<DetectedItem> _items = [];
  bool _classifying = false;
  double? _latitude;
  double? _longitude;
  bool _capturingLocation = false;

  Future<void> _addItem() async {
    final String? path = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (context) => const CameraCaptureScreen()),
    );
    if (path == null) return;

    setState(() => _classifying = true);
    try {
      final item = await _classifierService.classifyOne(photoPath: path);
      if (!mounted) return;
      setState(() => _items.add(item));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Classification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _classifying = false);
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _captureLocation() async {
    setState(() => _capturingLocation = true);
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _capturingLocation = false;
      _latitude = position?.latitude;
      _longitude = position?.longitude;
    });
  }

  void _reviewAll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetectedItemsReviewScreen(
          items: List.from(_items),
          latitude: _latitude,
          longitude: _longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Collection')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _latitude != null && _longitude != null
                        ? '📍 ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                        : 'Location not tagged',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                TextButton.icon(
                  onPressed: _capturingLocation ? null : _captureLocation,
                  icon: _capturingLocation
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location,
                          size: 18, color: AppColors.primaryGreen),
                  label: const Text('Tag GPS'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _classifying
                            ? 'Classifying...'
                            : 'Tap "Add Item" below and photograph one item at a time.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black54),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _itemTile(index),
                  ),
          ),
          if (_classifying)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(height: 3, child: LinearProgressIndicator()),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(
                          color: AppColors.primaryGreen, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _classifying ? null : _addItem,
                    icon: const Icon(Icons.add_a_photo),
                    label: Text(_items.isEmpty ? 'Add Item' : 'Add Another'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _items.isEmpty ? null : _reviewAll,
                    icon: const Icon(Icons.checklist),
                    label: Text('Review (${_items.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(int index) {
    final item = _items[index];
    final categoryData = MaterialCategories.byLabel(item.category);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: LotPhotoImage(
          path: item.photoPath,
          width: 48,
          height: 48,
          borderRadius: BorderRadius.circular(8),
        ),
        title: Row(
          children: [
            Icon(categoryData.icon, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Text(item.subCategory != null
                ? '${item.category} · ${item.subCategory}'
                : item.category),
          ],
        ),
        subtitle: Text(
            '${item.estimatedWeightKg} kg · ~₹${item.estimatedValue.toStringAsFixed(0)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.black45),
          onPressed: () => _removeItem(index),
        ),
      ),
    );
  }
}
