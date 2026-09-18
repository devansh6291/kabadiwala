import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/lot.dart';
import '../models/lot_store.dart';

class CreateLotScreen extends StatefulWidget {
  const CreateLotScreen({super.key});

  @override
  State<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends State<CreateLotScreen> {
  final TextEditingController weightController = TextEditingController();
  String selectedCategory = 'PCB';

  final List<Map<String, dynamic>> categories = [
    {'label': 'PCB', 'icon': Icons.memory},
    {'label': 'CRT', 'icon': Icons.tv},
    {'label': 'Cables', 'icon': Icons.cable},
    {'label': 'Battery', 'icon': Icons.battery_full},
    {'label': 'Motor', 'icon': Icons.settings},
    {'label': 'MixedPlastics', 'icon': Icons.local_drink},
  ];

  void saveLot() {
    final double? weight = double.tryParse(weightController.text);

    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    final newLot = Lot(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: selectedCategory,
      approxWeightKg: weight,
      photoPaths: [],
      createdAt: DateTime.now(),
    );

    LotStore.addLot(newLot);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryGreen,
        content: Text('Saved: ${newLot.category}, ${newLot.approxWeightKg} kg'),
      ),
    );

    weightController.clear();
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
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final bool isSelected = selectedCategory == category['label'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = category['label'];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryGreen : AppColors.lightGreen,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
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
                            category['icon'],
                            size: 28,
                            color: isSelected ? Colors.white : AppColors.primaryGreen,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category['label'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Approx weight (kg)',
              child: TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  hintText: 'e.g. 2.5',
                  prefixIcon: const Icon(Icons.scale, color: AppColors.primaryGreen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                onPressed: saveLot,
                icon: const Icon(Icons.check_circle),
                label: const Text('Save Lot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}