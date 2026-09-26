import 'package:flutter/material.dart';

/// A top-level material category, matching `Lot.category` values in the
/// data dictionary, plus the finer `Lot.subCategory` options a collector
/// (or later, the AI classifier) can pick within it.
class MaterialCategoryData {
  final String label;
  final IconData icon;
  final List<String> subCategories;

  const MaterialCategoryData({
    required this.label,
    required this.icon,
    this.subCategories = const [],
  });
}

/// Single source of truth for category choices shown in the UI.
/// Keep `label` values identical to what the data dictionary expects
/// for `Lot.category` — the backend and the ML classifier match on
/// these exact strings.
class MaterialCategories {
  static const List<MaterialCategoryData> all = [
    MaterialCategoryData(
      label: 'PCB',
      icon: Icons.memory,
      subCategories: [
        'Motherboard',
        'Graphics Card',
        'Power Supply Board',
        'Other PCB',
      ],
    ),
    MaterialCategoryData(
      label: 'CRT',
      icon: Icons.tv,
      subCategories: ['CRT Monitor', 'CRT Television'],
    ),
    MaterialCategoryData(
      label: 'Cables',
      icon: Icons.cable,
      subCategories: ['Copper Wire', 'USB / Data Cable', 'Power Cable'],
    ),
    MaterialCategoryData(
      label: 'Battery',
      icon: Icons.battery_full,
      subCategories: ['Li-ion', 'Lead-acid', 'Alkaline', 'Other Battery'],
    ),
    MaterialCategoryData(
      label: 'Motor',
      icon: Icons.settings,
      subCategories: ['Fan Motor', 'Compressor Motor', 'Other Motor'],
    ),
    MaterialCategoryData(
      label: 'MixedPlastics',
      icon: Icons.local_drink,
    ),
    MaterialCategoryData(
      label: 'OtherEwaste',
      icon: Icons.devices_other,
      // Matches the model's CANONICAL_SUBCATEGORIES that fall under
      // OtherEwaste rather than a more specific category.
      subCategories: [
        'Laptop',
        'Keyboard',
        'Mouse',
        'MobilePhone',
        'ScrapMetal'
      ],
    ),
  ];

  static MaterialCategoryData byLabel(String label) {
    return all.firstWhere(
      (c) => c.label == label,
      orElse: () => all.first,
    );
  }
}
