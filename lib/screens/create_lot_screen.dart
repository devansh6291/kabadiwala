import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../app_colors.dart';
import '../data/material_categories.dart';
import '../models/lot.dart';
import '../models/lot_store.dart';
import '../services/classifier_service.dart';
import '../services/location_service.dart';
import 'camera_capture_screen.dart';
import 'classification_result_screen.dart';
import '../widgets/lot_photo_image.dart';

class CreateLotScreen extends StatefulWidget {
  /// Injected so the real ML classifier can be swapped in later without
  /// touching this screen — see lib/services/classifier_service.dart.
  /// Defaults to the manual stand-in when not provided.
  final ClassifierService? classifierService;

  const CreateLotScreen({super.key, this.classifierService});

  @override
  State<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends State<CreateLotScreen> {
  final TextEditingController weightController = TextEditingController();
  final Uuid _uuid = const Uuid();
  late final ClassifierService _classifierService =
      widget.classifierService ?? ManualClassifierService();

  String selectedCategory = MaterialCategories.all.first.label;
  String? selectedSubCategory;
  final List<String> photoPaths = [];
  bool capturingLocation = false;
  double? capturedLatitude;
  double? capturedLongitude;
  bool saving = false;

  MaterialCategoryData get _selectedCategoryData =>
      MaterialCategories.byLabel(selectedCategory);

  Future<void> _capturePhoto() async {
    final String? path = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (context) => const CameraCaptureScreen()),
    );
    if (path == null) return;
    setState(() => photoPaths.add(path));
  }

  void _removePhoto(int index) {
    setState(() => photoPaths.removeAt(index));
  }

  Future<void> _captureLocation() async {
    setState(() => capturingLocation = true);
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      capturingLocation = false;
      capturedLatitude = position?.latitude;
      capturedLongitude = position?.longitude;
    });
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable — lot will save without GPS.'),
        ),
      );
    }
  }

  Future<void> saveLot() async {
    final double? weight = double.tryParse(weightController.text);

    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    setState(() => saving = true);

    final classification = await _classifierService.classify(
      category: selectedCategory,
      subCategory: selectedSubCategory,
      approxWeightKg: weight,
      photoPaths: photoPaths,
    );

    final newLot = Lot(
      id: _uuid.v4(),
      category: selectedCategory,
      subCategory: selectedSubCategory ?? classification.suggestedSubCategory,
      approxWeightKg: weight,
      photoPaths: List.from(photoPaths),
      estimatedValue: classification.estimatedValue,
      createdAt: DateTime.now(),
      latitude: capturedLatitude,
      longitude: capturedLongitude,
      syncStatus: 'pending',
    );

    await LotStore.addLot(newLot);

    if (!mounted) return;
    setState(() => saving = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassificationResultScreen(
          lot: newLot,
          result: classification,
        ),
      ),
    );

    weightController.clear();
    setState(() {
      photoPaths.clear();
      selectedSubCategory = null;
      capturedLatitude = null;
      capturedLongitude = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create Lot')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: 'Select category',
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: MaterialCategories.all.length,
                itemBuilder: (context, index) {
                  final category = MaterialCategories.all[index];
                  final bool isSelected = selectedCategory == category.label;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = category.label;
                        selectedSubCategory = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.lightGreen,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryGreen
                                      .withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category.icon,
                            size: 28,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primaryGreen,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_selectedCategoryData.subCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Sub-category (optional)',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedCategoryData.subCategories.map((sub) {
                    final bool isSelected = selectedSubCategory == sub;
                    return ChoiceChip(
                      label: Text(sub),
                      selected: isSelected,
                      selectedColor: AppColors.primaryGreen,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          selectedSubCategory = selected ? sub : null;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Approx weight (kg)',
              child: TextField(
                controller: weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  hintText: 'e.g. 2.5',
                  prefixIcon:
                      const Icon(Icons.scale, color: AppColors.primaryGreen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Photos',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...photoPaths.asMap().entries.map((entry) {
                    final index = entry.key;
                    final path = entry.value;
                    return Stack(
                      children: [
                        LotPhotoImage(
                          path: path,
                          width: 84,
                          height: 84,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.black54, size: 20),
                            onPressed: () => _removePhoto(index),
                          ),
                        ),
                      ],
                    );
                  }),
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.lightGreen, width: 1.5),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: AppColors.primaryGreen, size: 30),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Location',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      capturedLatitude != null && capturedLongitude != null
                          ? '${capturedLatitude!.toStringAsFixed(5)}, ${capturedLongitude!.toStringAsFixed(5)}'
                          : 'Not captured yet',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: capturingLocation ? null : _captureLocation,
                    icon: capturingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location,
                            color: AppColors.primaryGreen),
                    label: const Text('Tag GPS'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: saving ? null : saveLot,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  saving ? 'Estimating value...' : 'Save Lot',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
