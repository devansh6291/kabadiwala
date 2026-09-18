/// Result of classifying/valuing a lot, whether that came from a real
/// model or a manual rule-based stand-in.
class ClassificationResult {
  /// Instant AI/rule-based value estimate, in ₹ — maps straight onto
  /// `Lot.estimatedValue`.
  final double estimatedValue;

  /// A suggested finer classification, e.g. "Motherboard" — maps onto
  /// `Lot.subCategory`. Null when the classifier has no opinion and the
  /// collector's manual pick should stand.
  final String? suggestedSubCategory;

  /// 0.0–1.0. Used later to flag low-confidence classifications for
  /// human-in-the-loop review on the recycler/aggregator dashboard.
  /// The manual stand-in always reports 1.0 since a person made the
  /// choice directly.
  final double confidence;

  const ClassificationResult({
    required this.estimatedValue,
    this.suggestedSubCategory,
    this.confidence = 1.0,
  });
}

/// Anything that can turn a photographed, weighed lot into a value
/// estimate implements this. Your ML teammate implements this same
/// interface with the real model — no UI code needs to change, just
/// the instantiation in CreateLotScreen (see Step 9).
abstract class ClassifierService {
  Future<ClassificationResult> classify({
    required String category,
    String? subCategory,
    required double approxWeightKg,
    required List<String> photoPaths,
  });
}

/// TEMPORARY manual/rule-based stand-in for the real ML classifier.
/// Looks up a flat, indicative ₹/kg rate per category and multiplies
/// by weight — it does not look at the photos at all.
///
/// TODO(ml-team): replace with a real implementation of
/// [ClassifierService] that actually inspects `photoPaths`.
class ManualClassifierService implements ClassifierService {
  /// Indicative ₹/kg by category. Placeholder numbers only — replace
  /// with real figures from the Price Discovery Dataset once available.
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
    return ClassificationResult(
      estimatedValue: double.parse(
        (rate * approxWeightKg).toStringAsFixed(2),
      ),
      suggestedSubCategory: subCategory,
      confidence: 1.0,
    );
  }
}