import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/user_location.dart';
import '../repositories/location_repository.dart';
import 'watch_position_params.dart';

class WatchPosition extends UseCase<Stream<UserLocation>, WatchPositionParams> {
  final LocationRepository repository;
  WatchPosition(this.repository);

  @override
  Future<Stream<UserLocation>> call(WatchPositionParams params) async {
    print('🟣 WatchPosition: Starting location stream...');
    print('   distanceFilter: ${params.distanceFilter}');
    print('   accuracy: ${params.accuracy}');

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('🟣 WatchPosition: Current permission: $permission');

      if (permission == LocationPermission.denied) {
        print('🟣 WatchPosition: Requesting permission...');
        permission = await Geolocator.requestPermission();
        print('🟣 WatchPosition: Permission after request: $permission');
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ WatchPosition: Permission denied!');
        throw Exception('Location permission denied');
      }

      print('🟣 WatchPosition: Creating position stream...');
      final positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy:
              params.accuracy ??
              LocationAccuracy.high, // ✅ Fix: Provide default
          distanceFilter: params.distanceFilter?.toInt() ?? 0,
        ),
      );

      print(
        '✅ WatchPosition: Position stream created, mapping to UserLocation...',
      );

      return positionStream.map((position) {
        print(
          '🟢 WatchPosition: Position received - Lat: ${position.latitude}, Lon: ${position.longitude}',
        );

        return UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          timestamp: position.timestamp ?? DateTime.now(),
        );
      });
    } catch (e) {
      print('❌ WatchPosition: Error: $e');
      rethrow;
    }
  }
}
