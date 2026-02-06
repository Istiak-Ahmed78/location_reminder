import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_datasource.dart';
import '../datasources/location_local_datasource.dart';

/// Implementation of [LocationRepository] that handles location data
/// from both remote (GPS) and local (cache) sources
class LocationRepositoryImpl implements LocationRepository {
  final LocationDataSource dataSource;
  final LocationLocalDataSource localDataSource;

  LocationRepositoryImpl(this.dataSource, this.localDataSource);

  @override
  Future<void> ensurePermission() => dataSource.ensurePermission();

  @override
  Future<UserLocation> getCurrentLocation() async {
    final location = await dataSource.getCurrentLocation();

    // Cache the location asynchronously without blocking
    _cacheLocationSilently(location);

    return location;
  }

  @override
  Stream<UserLocation> watchPosition({
    double? distanceFilter,
    LocationAccuracy? accuracy,
  }) {
    return dataSource
        .watchPosition(distanceFilter: distanceFilter, accuracy: accuracy)
        .map((location) {
          // Cache each location update asynchronously
          _cacheLocationSilently(location);
          return location;
        });
  }

  @override
  Future<Either<Failure, UserLocation?>> getLastCachedCurrentLocation() async {
    try {
      final location = await localDataSource.getLastKnownLocation();
      return Right(location);
    } catch (e) {
      return Left(LocationFailure('Failed to retrieve cached location: $e'));
    }
  }

  /// Caches location silently without throwing errors
  ///
  /// This is a fire-and-forget operation that logs errors
  /// but doesn't interrupt the main location flow
  void _cacheLocationSilently(UserLocation location) {
    localDataSource.saveLastKnownLocation(location).catchError((error) {
      // Log error silently - caching failure shouldn't affect location retrieval
      // In production, you might want to send this to a logging service
      return null;
    });
  }
}
