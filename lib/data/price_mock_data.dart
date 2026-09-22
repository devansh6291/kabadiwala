import '../models/price_dataset_entry.dart';
import 'recycler_mock_data.dart';

/// TEMPORARY mock price feed, derived from RecyclerMockData's offered
/// rates. These are indicative numbers only — label them as such in the
/// UI. TODO(backend-team): replace with the real Price Discovery Dataset
/// API once it exists; keep the same PriceDatasetEntry shape.
class PriceMockData {
  static List<PriceDatasetEntry> latest() {
    final entries = <PriceDatasetEntry>[];
    final now = DateTime.now();

    for (final recycler
        in RecyclerMockData.all.where((r) => !r.isStorageOnly)) {
      recycler.offeredRates.forEach((category, sellingPrice) {
        entries.add(PriceDatasetEntry(
          materialCategory: category,
          location: 'Indore',
          date: now.subtract(const Duration(days: 1)),
          buyingPrice: double.parse((sellingPrice * 0.82).toStringAsFixed(2)),
          sellingPrice: sellingPrice,
          recyclerId: recycler.recyclerId,
        ));
      });
    }
    return entries;
  }
}
