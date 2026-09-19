/// Result of classifying/valuing a lot, whether that came from a real
/// model or a manual rule-based stand-in.
class ClassificationResult {
  /// Instant AI/rule-based value estimate, in ₹ — maps onto `Lot.estimatedValue`.
  final double estimatedValue;

  /// A suggested finer classification, e.g. "Motherboard" — maps onto
  /// `Lot.subCategory`. Null when the classifier has no opinion.
  final String? suggestedSubCategory;

  /// "good" or "bad" — condition of the material as read from the photo.
  /// Bad-condition items (corroded, badly damaged) get a lower estimate
  /// and are flagged for the recycler/aggregator to double-check.
  final String condition;

  /// 0.0–1.0. Used to flag low-confidence classifications for
  /// human-in-the-loop review on the recycler/aggregator dashboard
  /// (idea doc, section 9).
  final double confidence;

  const ClassificationResult({
    required this.estimatedValue,
    this.suggestedSubCategory,
    this.condition = 'good',
    this.confidence = 1.0,
  });
}

/// Anything that can turn a photographed, weighed lot into a value +
/// condition estimate implements this. Swap [ManualClassifierService] for
/// a real on-device (TFLite) or cloud-assisted vision model by
/// implementing this same interface — no UI code needs to change, just
/// the instantiation in CreateLotScreen.
abstract class ClassifierService {
  Future<ClassificationResult> classify({
    required String category,
    String? subCategory,
    required double approxWeightKg,
    required List<String> photoPaths,
  });
}

/// TEMPORARY manual/rule-based stand-in for the real ML classifier.
///
/// Value: looks up a flat, indicative ₹/kg rate per category and
/// multiplies by weight. Condition: since there's no real vision model
/// yet, this derives a *deterministic* good/bad flag from the photo's
/// file path so the UI has something consistent to demo with — it does
/// not actually look at the image content.
///
/// TODO(ml-team): replace with a real implementation of
/// [ClassifierService] that inspects `photoPaths` for both material
/// identification and physical condition.
class ManualClassifierService implements ClassifierService {
  static const Map<String, double> _indicativeRatePerKg = {
    'PCB': 180,
    'CRT': 8,
    'Cables': 90,
    'Battery': 40,
    'Motor': 60,
    'MixedPlastics': 15,
  };

  @override
  Future<ClassificationResult> classify({
    required String category,
    String? subCategory,
    required double approxWeightKg,
    required List<String> photoPaths,
  }) async {
    final rate = _indicativeRatePerKg[category] ?? 10.0;

    // Placeholder condition heuristic — NOT real image analysis.
    final bool looksBad =
        photoPaths.isNotEmpty && photoPaths.first.hashCode.abs() % 5 == 0;
    final condition = looksBad ? 'bad' : 'good';
    final conditionMultiplier = looksBad ? 0.6 : 1.0;

    return ClassificationResult(
      estimatedValue: double.parse(
        (rate * approxWeightKg * conditionMultiplier).toStringAsFixed(2),
      ),
      suggestedSubCategory: subCategory,
      condition: condition,
      confidence: looksBad ? 0.55 : 0.9,
    );
  }
}
