import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../app_colors.dart';
import '../models/storage_host.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

/// Nearby large-Kabadiwala storage points. Fetched via geo-query
/// from the live backend using the collector's actual GPS.
class NearbyKabadiwalasScreen extends StatefulWidget {
  const NearbyKabadiwalasScreen({super.key});

  @override
  State<NearbyKabadiwalasScreen> createState() =>
      _NearbyKabadiwalasScreenState();
}

class _NearbyKabadiwalasScreenState extends State<NearbyKabadiwalasScreen> {
  Position? _myPosition;
  bool _isLoading = true;
  String? _error;
  List<StorageHost> _hosts = [];

  @override
  void initState() {
    super.initState();
    _fetchNearbyHosts();
  }

  Future<void> _fetchNearbyHosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Get exact device GPS
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;

      if (pos == null) {
        setState(() {
          _error = 'Location access is required to find nearby storage points.';
          _isLoading = false;
        });
        return;
      }
      _myPosition = pos;

      // 2. Query the FastAPI backend for hosts within 20km
      final response = await ApiClient().dio.get(
        '/storage-hosts/nearby',
        queryParameters: {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'radius_km': 20.0,
        },
      );

      // 3. Parse JSON response into StorageHost objects safely
      final List<dynamic> data = response.data;
      final hosts = data.map((json) {
        return StorageHost(
          hostId: json['host_id']?.toString() ?? '',
          name: json['name']?.toString() ?? '',
          latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
          weeklyRatePerItem:
              (json['weekly_rate_per_item'] as num?)?.toDouble() ?? 0.0,
          availableCapacity: (json['available_capacity'] as num?)?.toInt() ?? 0,
          rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      // 4. Sort strictly by physical distance
      hosts.sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));

      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to connect to the server: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  double _distanceKm(StorageHost r) {
    if (_myPosition == null) return 999.0;
    final meters = Geolocator.distanceBetween(
      _myPosition!.latitude,
      _myPosition!.longitude,
      r.latitude,
      r.longitude,
    );
    return meters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nearby Kabadiwalas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNearbyHosts,
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchNearbyHosts,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen),
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    if (_hosts.isEmpty) {
      return const Center(
        child: Text(
          'No storage points registered within 20km.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNearbyHosts,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _hosts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _kabadiwalaCard(_hosts[index]),
      ),
    );
  }

  Widget _kabadiwalaCard(StorageHost r) {
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
          'Available Capacity: ${r.availableCapacity} items\n'
          'Storage Rate: ₹${r.weeklyRatePerItem.toStringAsFixed(0)} / week',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Text(
          '${distance.toStringAsFixed(1)} km',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}
