import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:location_reminder/core/error/failures.dart';

import '../entities/user_location.dart';
import 'package:geolocator/geolocator.dart';

abstract class LocationRepository {
  Future<void> ensurePermission();
  Future<UserLocation> getCurrentLocation();
  Future<Either<Failure, UserLocation?>> getLastCachedCurrentLocation();

  Stream<UserLocation> watchPosition({
    double? distanceFilter,
    LocationAccuracy? accuracy,
  });
}
