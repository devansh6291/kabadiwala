import '../models/recycler.dart';

/// TEMPORARY mock recycler/aggregator directory.
///
/// TODO(backend-team): replace with a real fetch from the Node.js
/// recycler/matching API once it exists. Keep [Recycler] field names and
/// meanings identical when you do — the matching service and UI only
/// depend on the model, not on where the data came from.
class RecyclerMockData {
  static final List<Recycler> all = [
    const Recycler(
      recyclerId: 'rec_001',
      name: 'GreenCircuit E-Waste Recyclers',
      facilityLat: 22.7196,
      facilityLng: 75.8577,
      materialsAccepted: ['PCB', 'CRT', 'Cables', 'Battery', 'Motor'],
      authorizationNumber: 'EPR-MH-2024-1187',
      authorizationStatus: 'authorized',
      contactDetails: '+91-98230-00001',
      offeredRates: {
        'PCB': 190,
        'CRT': 9,
        'Cables': 95,
        'Battery': 42,
        'Motor': 65,
      },
      pickupAvailability: 'scheduled',
      minVehicleCapacityKg: 50,
      hasOwnLogistics: true,
    ),
    const Recycler(
      recyclerId: 'rec_002',
      name: 'Indore Metal & Battery Recovery',
      facilityLat: 22.7532,
      facilityLng: 75.8937,
      materialsAccepted: ['Battery', 'Motor', 'Cables'],
      authorizationNumber: 'EPR-MH-2023-0456',
      authorizationStatus: 'authorized',
      contactDetails: '+91-98230-00002',
      offeredRates: {'Battery': 45, 'Motor': 70, 'Cables': 88},
      pickupAvailability: 'same_day',
      minVehicleCapacityKg: 30,
      hasOwnLogistics: true,
    ),
    const Recycler(
      recyclerId: 'rec_003',
      name: 'ShreeJi Plastic & Household Goods Mfg.',
      facilityLat: 22.6900,
      facilityLng: 75.8300,
      materialsAccepted: ['MixedPlastics'],
      authorizationNumber: null,
      authorizationStatus: 'authorized',
      contactDetails: '+91-98230-00003',
      offeredRates: {'MixedPlastics': 16},
      pickupAvailability: 'scheduled',
      minVehicleCapacityKg: 40,
      hasOwnLogistics: false,
    ),

    // Large Kabadiwalas — storage-only custodians, not recyclers.
    // They never appear in the "route to recycler" match; only in the
    // "pool needs storage" fallback.
    const Recycler(
      recyclerId: 'storage_001',
      name: 'Rajesh Bhai (Large Kabadiwala — Storage Point)',
      facilityLat: 22.7300,
      facilityLng: 75.8600,
      materialsAccepted: ['PCB', 'CRT', 'Cables', 'Battery', 'Motor'],
      authorizationStatus: 'pending',
      contactDetails: '+91-98230-00010',
      offeredRates: {},
      pickupAvailability: 'none',
      minVehicleCapacityKg: 0,
      hasOwnLogistics: false,
      isStorageOnly: true,
      storageRatePerItemPerWeek: 30,
    ),
  ];

  static List<Recycler> forCategory(String category) {
    return all
        .where(
            (r) => !r.isStorageOnly && r.materialsAccepted.contains(category))
        .where((r) => r.authorizationStatus == 'authorized')
        .toList();
  }

  static List<Recycler> storagePointsFor(String category) {
    return all
        .where((r) => r.isStorageOnly && r.materialsAccepted.contains(category))
        .toList();
  }
}
