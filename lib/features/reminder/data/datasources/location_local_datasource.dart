import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_location.dart';
import '../models/user_location_model.dart';

/// Abstract interface for local location data operations
abstract class LocationLocalDataSource {
  /// Saves the last known location to local storage
  Future<void> saveLastKnownLocation(UserLocation location);

  /// Retrieves the last known location from local storage
  /// Returns null if no cached location exists
  Future<UserLocation?> getLastKnownLocation();
}

/// Implementation of [LocationLocalDataSource] using SharedPreferences
class SharedPreferencesLocationDataSource implements LocationLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _cacheKey = 'cached_user_location';

  SharedPreferencesLocationDataSource(this.sharedPreferences);

  @override
  Future<void> saveLastKnownLocation(UserLocation location) async {
    try {
      final model = UserLocationModel.fromEntity(location);
      final jsonString = model.toJsonString();

      final success = await sharedPreferences.setString(_cacheKey, jsonString);

      if (!success) {
        throw CacheException('Failed to save location to cache');
      }
    } catch (e) {
      throw CacheException('Error saving location: $e');
    }
  }

  @override
  Future<UserLocation?> getLastKnownLocation() async {
    final jsonString = sharedPreferences.getString(_cacheKey);

    // No cached data is not an error - return null
    if (jsonString == null) {
      return null;
    }

    try {
      final model = UserLocationModel.fromJsonString(jsonString);
      return model;
    } catch (e) {
      throw CacheException('Failed to parse cached location: $e');
    }
  }
}

/// Exception thrown when cache operations fail
class CacheException implements Exception {
  final String message;

  CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}
