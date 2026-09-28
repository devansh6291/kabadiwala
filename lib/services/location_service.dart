import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper around geolocator for capturing `Lot.latitude` /
/// `Lot.longitude` at creation time. Returns null (never throws) on any
/// failure — GPS tagging is a nice-to-have for a lot, not a blocker.
class LocationService {
  static String? lastError;

  static Future<Position?> getCurrentPosition() async {
    lastError = null;
    try {
      // Some browsers do not implement the Permissions API. In that case
      // checkPermission() reports denied even though getCurrentPosition()
      // can still trigger the browser's location prompt.
      if (!kIsWeb) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          lastError = 'Turn on location services and try again.';
          return null;
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          lastError = 'Allow location access in your device settings, then retry.';
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 20));
    } catch (error) {
      lastError = kIsWeb
          ? 'Location was not available. Allow location for this site and use HTTPS or localhost, then retry.'
          : 'Could not get your location. Check GPS and permission, then retry.';
      debugPrint('[LOCATION] $error');
      return null;
    }
  }
}
