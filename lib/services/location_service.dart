import 'package:geolocator/geolocator.dart';

/// Thin wrapper around geolocator for capturing `Lot.latitude` /
/// `Lot.longitude` at creation time. Returns null (never throws) on any
/// failure — GPS tagging is a nice-to-have for a lot, not a blocker.
class LocationService {
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}