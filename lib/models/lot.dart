class Lot {
  String id;
  String category;
  String? subCategory;
  double approxWeightKg;
  List<String> photoPaths;
  double? estimatedValue;
  double? quotedPrice;
  double? finalSaleValue;
  DateTime createdAt;
  String syncStatus;

  Lot({
    required this.id,
    required this.category,
    this.subCategory,
    required this.approxWeightKg,
    required this.photoPaths,
    this.estimatedValue,
    this.quotedPrice,
    this.finalSaleValue,
    required this.createdAt,
    this.syncStatus = 'pending',
  });
}