import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../app_colors.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

/// Nearby mapped recycling businesses. OpenStreetMap listings are not
/// authorization-verified recycler records.
class NearbyKabadiwalasScreen extends StatefulWidget {
  const NearbyKabadiwalasScreen({super.key});

  @override
  State<NearbyKabadiwalasScreen> createState() =>
      _NearbyKabadiwalasScreenState();
}

class _NearbyKabadiwalasScreenState extends State<NearbyKabadiwalasScreen> {
  bool _isLoading = true;
  String? _error;
  bool _showingSamples = false;
  List<Map<String, dynamic>> _places = [];

  static const List<Map<String, dynamic>> _samplePlaces = [
    {
      'name': 'Sample Recycler 1',
      'type': 'E-waste collection',
      'materials': 'Phones, cables, small electronics',
      'address': 'Example listing — location not verified',
      'isDemo': true,
    },
    {
      'name': 'Sample Recycler 2',
      'type': 'Scrap dealer',
      'materials': 'Paper, cardboard, plastic',
      'address': 'Example listing — location not verified',
      'isDemo': true,
    },
    {
      'name': 'Sample Recycler 3',
      'type': 'Metal recycler',
      'materials': 'Aluminium, copper, steel',
      'address': 'Example listing — location not verified',
      'isDemo': true,
    },
  ];

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
          _places = [];
          _showingSamples = false;
          _error = LocationService.lastError ?? 'Location is unavailable. Allow location access and retry.';
          _isLoading = false;
        });
        return;
      }
      // The backend sends rounded coordinates to OpenStreetMap, not the
      // device's exact GPS location.
      final response = await ApiClient().dio.get(
        '/recycling-points/nearby',
        queryParameters: {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'radius_km': 20.0,
        },
      );

      // These are map listings, not authorization-verified recycler records.
      final List<dynamic> data = response.data;
      final places = data.map((item) => Map<String, dynamic>.from(item)).toList();
      places.sort((a, b) =>
          ((a['distance_km'] as num?)?.toDouble() ?? 999)
              .compareTo((b['distance_km'] as num?)?.toDouble() ?? 999));

      if (!mounted) return;
      setState(() {
        _places = places.isEmpty ? _samplePlaces : places;
        _showingSamples = places.isEmpty;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _places = _samplePlaces;
        _showingSamples = true;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _places = _samplePlaces;
        _showingSamples = true;
        _error = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nearby recycling points'),
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

    if (_places.isEmpty) {
      return const Center(
        child: Text(
          'No recycling points mapped within 20km.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNearbyHosts,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _places.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => index == 0
            ? Text(
                _showingSamples
                    ? 'Sample directory entries are shown because live nearby data is unavailable. These are examples, not real people or verified locations.'
                    : 'Map-listed recycling locations near you. Authorization is not verified; check a provider before handing over waste.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            : _recyclingPointCard(_places[index - 1]),
      ),
    );
  }

  Widget _recyclingPointCard(Map<String, dynamic> place) {
    final distance = (place['distance_km'] as num?)?.toDouble() ?? 0.0;
    final address = place['address']?.toString() ?? '';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryGreen,
          child: Icon(Icons.recycling, color: Colors.white),
        ),
        title: Text(place['name']?.toString() ?? 'Recycling point',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${place['type'] ?? 'recycling'} • ${place['materials'] ?? 'Materials not listed'}'),
            if (address.isNotEmpty) Text(address),
            Text(
              place['isDemo'] == true
                  ? 'Demo only • not a real listing'
                  : 'OpenStreetMap listing • authorization not verified',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        trailing: Text(
          place['isDemo'] == true
              ? 'Sample'
              : '${distance.toStringAsFixed(1)} km',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}
