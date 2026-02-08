import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching ETA data
class ETACacheService {
  static const String _cacheKey = 'eta_cache';
  static const String _requestCountKey = 'api_request_count';
  static const String _lastResetDateKey = 'api_last_reset_date';
  static const int _maxRequestsPerDay = 2000;

  final SharedPreferences prefs;

  ETACacheService(this.prefs);

  /// Cache ETA data
  Future<void> cacheETA({
    required int seconds,
    required double lat,
    required double lon,
    required DateTime timestamp,
  }) async {
    final data = {
      'seconds': seconds,
      'lat': lat,
      'lon': lon,
      'timestamp': timestamp.toIso8601String(),
    };

    await prefs.setString(_cacheKey, json.encode(data));
  }

  /// Get cached ETA if still valid
  /// Returns null if cache is invalid or expired
  Map<String, dynamic>? getCachedETA({
    required double currentLat,
    required double currentLon,
    Duration maxAge = const Duration(minutes: 15),
  }) {
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return null;

    try {
      final data = json.decode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);
      final cachedLat = data['lat'] as double;
      final cachedLon = data['lon'] as double;

      // Check if cache is too old
      if (DateTime.now().difference(timestamp) > maxAge) {
        return null;
      }

      // Check if user moved too far from cached position (>500m)
      final distance = _calculateDistance(
        currentLat,
        currentLon,
        cachedLat,
        cachedLon,
      );

      if (distance > 500) {
        return null;
      }

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Clear cached ETA
  Future<void> clearCache() async {
    await prefs.remove(_cacheKey);
  }

  /// Increment API request count
  Future<bool> incrementRequestCount() async {
    await _resetCountIfNewDay();

    final count = prefs.getInt(_requestCountKey) ?? 0;

    if (count >= _maxRequestsPerDay) {
      return false; // Limit reached
    }

    await prefs.setInt(_requestCountKey, count + 1);
    return true;
  }

  /// Get remaining API requests for today
  int getRemainingRequests() {
    final count = prefs.getInt(_requestCountKey) ?? 0;
    return (_maxRequestsPerDay - count).clamp(0, _maxRequestsPerDay);
  }

  /// Check if approaching rate limit (80% used)
  bool isApproachingLimit() {
    final remaining = getRemainingRequests();
    return remaining < (_maxRequestsPerDay * 0.2); // Less than 20% remaining
  }

  /// Reset request count if it's a new day
  Future<void> _resetCountIfNewDay() async {
    final lastResetDate = prefs.getString(_lastResetDateKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastResetDate != today) {
      await prefs.setInt(_requestCountKey, 0);
      await prefs.setString(_lastResetDateKey, today);
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }
}
