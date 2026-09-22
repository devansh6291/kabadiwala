import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_colors.dart';
import '../data/recycler_mock_data.dart';
import '../models/recycler.dart';
import '../services/location_service.dart';

/// Nearby large-Kabadiwala storage points a collector can route pooled
/// material to. Distance is computed from the device's current GPS to
/// each point's mock facility coordinates — real distance/routing would
/// come from the backend once it exists.
class NearbyKabadiwalasScreen extends StatefulWidget {
  const NearbyKabadiwalasScreen({super.key});

  @override
  State<NearbyKabadiwalasScreen> createState() =>
      _NearbyKabadiwalasScreenState();
}

class _NearbyKabadiwalasScreenState extends State<NearbyKabadiwalasScreen> {
  Position? _myPosition;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _myPosition = pos;
      _locating = false;
    });
  }

  double? _distanceKm(Recycler r) {
    if (_myPosition == null) return null;
    final meters = Geolocator.distanceBetween(
      _myPosition!.latitude,
      _myPosition!.longitude,
      r.facilityLat,
      r.facilityLng,
    );
    return meters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final points =
        List<Recycler>.from(RecyclerMockData.all.where((r) => r.isStorageOnly));
    if (_myPosition != null) {
      points.sort((a, b) => _distanceKm(a)!.compareTo(_distanceKm(b)!));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nearby Kabadiwalas')),
      body: _locating
          ? const Center(child: CircularProgressIndicator())
          : points.isEmpty
              ? const Center(
                  child: Text('No storage points registered nearby yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: points.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _kabadiwalaCard(points[index]),
                ),
    );
  }

  Widget _kabadiwalaCard(Recycler r) {
    final distance = _distanceKm(r);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryGreen,
          child: Icon(Icons.warehouse, color: Colors.white),
        ),
        title:
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Accepts: ${r.materialsAccepted.join(', ')}\n'
          'Storage only — does not process or buy',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: distance != null
            ? Text('${distance.toStringAsFixed(1)} km',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primaryGreen))
            : null,
      ),
    );
  }
}
