/// Price Dataset Entry — matches the data dictionary's "Price Dataset
/// Entry" section exactly, used for price discovery/trend display.
class PriceDatasetEntry {
  String materialCategory;
  String? materialSubCategory;
  String location;
  DateTime date;
  double buyingPrice; // what collectors were paid
  double sellingPrice; // what recyclers/aggregators offered
  String unit; // almost always "per_kg"
  String? recyclerId;

  PriceDatasetEntry({
    required this.materialCategory,
    this.materialSubCategory,
    required this.location,
    required this.date,
    required this.buyingPrice,
    required this.sellingPrice,
    this.unit = 'per_kg',
    this.recyclerId,
  });
}
