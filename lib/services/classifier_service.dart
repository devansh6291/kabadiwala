/// One item classified from a single photo of it.
class DetectedItem {
  /// The photo this classification came from — each item now has its own
  /// photo (one photo per item, not one shared "whole collection" photo).
  String photoPath;

  String category;
  String? subCategory;
  double estimatedWeightKg;
  double estimatedValue;

  /// "Scrap_Only" or similar — sourced from the model's physicalCondition.
  String? condition;

  /// Single overall confidence (0.0–1.0) for quick display — currently
  /// set to the model's "category" confidence sub-score. See
  /// [confidenceScores] for the full breakdown.
  double? confidence;

  /// "E_WASTE" or "PLASTIC" — drives dual routing (idea doc §3.2).
  String? routeType;

  /// % composition by weight/probability, e.g. {"Copper": 0.50, "Aluminum": 0.49}.
  /// This is the copper/gold/silver data — populated for e-waste items.
  Map<String, double>? materialComposition;

  /// Named materials the model flagged as present, e.g. ["Copper", "Gold_Plated_Connectors"].
  List<String>? detectedMaterials;

  /// Full confidence breakdown per pipeline stage:
  /// segregation, category, subCategory, condition.
  Map<String, double>? confidenceScores;

  DetectedItem({
    required this.photoPath,
    required this.category,
    this.subCategory,
    required this.estimatedWeightKg,
    required this.estimatedValue,
    this.condition,
    this.confidence,
    this.routeType,
    this.materialComposition,
    this.detectedMaterials,
    this.confidenceScores,
  });
}

/// Anything that can classify ONE photo of ONE item implements this.
abstract class ClassifierService {
  Future<DetectedItem> classifyOne({
    required String photoPath,
    double? approxWeightKg,
  });
}

/// Offline fallback. It deliberately does not infer a material from the
/// image; the collector chooses the category on the review screen.
class ManualClassifierService implements ClassifierService {
  static const String _defaultCategory = 'OtherEwaste';
  static const Map<String, double> _indicativeRatePerKg = {
    'PCB': 180,
    'CRT': 8,
    'Cables': 90,
    'Battery': 40,
    'Motor': 60,
    'MixedPlastics': 15,
    'OtherEwaste': 25,
  };

  @override
  Future<DetectedItem> classifyOne({
    required String photoPath,
    double? approxWeightKg,
  }) async {
    final category = _defaultCategory;
    final weight = approxWeightKg ?? 1.0;
    final rate = _indicativeRatePerKg[category] ?? 10.0;

    return DetectedItem(
      photoPath: photoPath,
      category: category,
      estimatedWeightKg: double.parse(weight.toStringAsFixed(1)),
      estimatedValue: double.parse((rate * weight).toStringAsFixed(2)),
    );
  }
}
