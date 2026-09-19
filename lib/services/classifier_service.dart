/// One item classified from a single photo of it.
class DetectedItem {
  /// The photo this classification came from — each item now has its own
  /// photo (one photo per item, not one shared "whole collection" photo).
  String photoPath;

  String category;
  String? subCategory;
  double estimatedWeightKg;
  double estimatedValue;

  /// "good" or "bad". NOTE: the current model does not actually classify
  /// physical condition — it only does category + valuation. This stays
  /// optional and defaults to "good" until/unless a condition signal is
  /// added on the ML side. Don't treat this as real until confirmed.
  String? condition;

  /// 0.0–1.0, when the classifier provides one.
  double? confidence;

  DetectedItem({
    required this.photoPath,
    required this.category,
    this.subCategory,
    required this.estimatedWeightKg,
    required this.estimatedValue,
    this.condition,
    this.confidence,
  });
}

/// Anything that can classify ONE photo of ONE item implements this.
/// The collector takes one photo per item now (not one group photo), so
/// this runs once per item, from CreateLotScreen's capture loop.
abstract class ClassifierService {
  /// [approxWeightKg] is an optional hint the collector already entered;
  /// pass it through if you have it — her engine falls back to a
  /// category weight prior when it's null.
  Future<DetectedItem> classifyOne({
    required String photoPath,
    double? approxWeightKg,
  });
}

/// TEMPORARY manual/rule-based stand-in — does not look at the photo's
/// actual content. Used until ApiClassifierService (calling the real
/// Python model over HTTP) is wired in and confirmed working.
class ManualClassifierService implements ClassifierService {
  static const List<String> _categories = [
    'PCB',
    'CRT',
    'Cables',
    'Battery',
    'Motor',
    'MixedPlastics'
  ];
  static const Map<String, double> _indicativeRatePerKg = {
    'PCB': 180,
    'CRT': 8,
    'Cables': 90,
    'Battery': 40,
    'Motor': 60,
    'MixedPlastics': 15,
  };

  @override
  Future<DetectedItem> classifyOne({
    required String photoPath,
    double? approxWeightKg,
  }) async {
    final seed = photoPath.hashCode.abs();
    final category = _categories[seed % _categories.length];
    final weight = approxWeightKg ?? (0.5 + (seed % 40) / 10.0);
    final rate = _indicativeRatePerKg[category] ?? 10.0;

    return DetectedItem(
      photoPath: photoPath,
      category: category,
      estimatedWeightKg: double.parse(weight.toStringAsFixed(1)),
      estimatedValue: double.parse((rate * weight).toStringAsFixed(2)),
    );
  }
}
