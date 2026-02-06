import 'package:geolocator/geolocator.dart';
import '../../domain/entities/user_location.dart';

abstract class LocationDataSource {
  Future<void> ensurePermission();
  Future<UserLocation> getCurrentLocation();
  Stream<UserLocation> watchPosition({
    double? distanceFilter,
    LocationAccuracy? accuracy,
  });
}

class GeolocatorLocationDataSource implements LocationDataSource {
  @override
  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable from settings.',
      );
    }
  }

  @override
  Future<UserLocation> getCurrentLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );

    return UserLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp ?? DateTime.now(),
    );
  }

  @override
  Stream<UserLocation> watchPosition({
    double? distanceFilter,
    LocationAccuracy? accuracy,
  }) {
    // Convert distanceFilter to int (geolocator expects int)
    // Use default of 50 meters if not specified
    final int distanceFilterInt = distanceFilter?.toInt() ?? 50;

    final settings = LocationSettings(
      accuracy: accuracy ?? LocationAccuracy.medium,
      distanceFilter: distanceFilterInt,
    );

    return Geolocator.getPositionStream(locationSettings: settings).map((pos) {
      return UserLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
    });
  }
}
