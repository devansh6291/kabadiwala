import '../models/recycler.dart';

/// Clearly identified sample profiles used when the live recycler directory
/// is empty or unreachable, so the app's routing flow remains demonstrable.
class DemoRecyclerDirectory {
  static const List<String> _materials = [
    'PCB',
    'CRT',
    'Cables',
    'Battery',
    'Motor',
    'MixedPlastics',
    'OtherEwaste',
  ];

  static const List<Recycler> recyclers = [
    Recycler(
      recyclerId: 'sample-recycler-indore-01',
      name: 'GreenLoop Materials Recovery',
      facilityLat: 22.7196,
      facilityLng: 75.8577,
      materialsAccepted: _materials,
      authorizationStatus: 'sample',
      contactDetails: 'Sample profile · contact not available',
      offeredRates: {
        'PCB': 180,
        'CRT': 8,
        'Cables': 90,
        'Battery': 40,
        'Motor': 60,
        'MixedPlastics': 15,
        'OtherEwaste': 30,
      },
      pickupAvailability: 'scheduled',
      minVehicleCapacityKg: 100,
      hasOwnLogistics: true,
      isSampleData: true,
    ),
    Recycler(
      recyclerId: 'sample-recycler-indore-02',
      name: 'Circular City Aggregation Hub',
      facilityLat: 22.7312,
      facilityLng: 75.8664,
      materialsAccepted: _materials,
      authorizationStatus: 'sample',
      contactDetails: 'Sample profile · contact not available',
      offeredRates: {
        'PCB': 165,
        'CRT': 7,
        'Cables': 85,
        'Battery': 38,
        'Motor': 55,
        'MixedPlastics': 14,
        'OtherEwaste': 28,
      },
      pickupAvailability: 'scheduled',
      minVehicleCapacityKg: 100,
      hasOwnLogistics: true,
      isSampleData: true,
    ),
  ];

  static List<Recycler> forMaterial(String category) => recyclers
      .where((recycler) => recycler.materialsAccepted.contains(category))
      .toList(growable: false);
}
