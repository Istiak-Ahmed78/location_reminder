import 'dart:math';
import '../entities/eta_result.dart';
import '../entities/user_location.dart';

/// Calculates ETA using GPS data (speed + distance)
class CalculateLocalETA {
  // Constants for fallback speed estimation
  static const double _averageWalkingSpeed = 1.4; // m/s (5 km/h)
  static const double _averageDrivingSpeed = 13.9; // m/s (50 km/h)
  static const double _speedThreshold = 2.0; // m/s - below this = walking

  // Speed history for averaging
  final List<double> _speedHistory = [];
  static const int _maxSpeedHistorySize = 5;

  ETAResult call({
    required UserLocation currentLocation,
    required double destinationLat,
    required double destinationLon,
  }) {
    final distance = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      destinationLat,
      destinationLon,
    );

    // Get current speed (default to 0 if null)
    final currentSpeed = currentLocation.speed ?? 0.0;

    // Add to speed history
    if (currentSpeed > 0) {
      _speedHistory.add(currentSpeed);
      if (_speedHistory.length > _maxSpeedHistorySize) {
        _speedHistory.removeAt(0);
      }
    }

    // Calculate average speed from history
    final averageSpeed = _speedHistory.isNotEmpty
        ? _speedHistory.reduce((a, b) => a + b) / _speedHistory.length
        : 0.0;

    // Determine effective speed for ETA calculation
    double effectiveSpeed;
    double confidence; // ✅ ADD confidence calculation

    if (averageSpeed > 0.5) {
      // User is moving, use average speed
      effectiveSpeed = averageSpeed;
      confidence = 0.9; // High confidence - using real speed data
    } else if (currentSpeed > 0.5) {
      // User just started moving, use current speed
      effectiveSpeed = currentSpeed;
      confidence = 0.7; // Medium confidence - limited data
    } else {
      // User is stationary, estimate based on distance
      if (distance > 2000) {
        // > 2km, assume driving
        effectiveSpeed = _averageDrivingSpeed;
        confidence = 0.4; // Low confidence - pure estimation
      } else {
        // <= 2km, assume walking
        effectiveSpeed = _averageWalkingSpeed;
        confidence = 0.5; // Low-medium confidence - reasonable assumption
      }
    }

    // Calculate ETA in seconds
    final etaSeconds = (distance / effectiveSpeed).round();

    // Ensure minimum ETA of 1 minute if distance > 0
    final finalEtaSeconds = etaSeconds < 60 && distance > 50 ? 60 : etaSeconds;

    final result = ETAResult(
      seconds: finalEtaSeconds,
      distanceMeters: distance,
      source: ETASource.localGPS,
      calculatedAt: DateTime.now(),
      currentSpeed: currentSpeed,
      averageSpeed: averageSpeed,
      confidence: confidence, // ✅ ADD THIS
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    print(
      '🔍 CalculateLocalETA: Created ETAResult - seconds: ${result.seconds}, timestamp: ${result.timestamp}, hashCode: ${result.hashCode}',
    );
    return result;
  }

  /// Calculate distance between two coordinates using Haversine formula
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
    return degrees * (pi / 180.0);
  }

  /// Reset speed history (call when tracking stops)
  void reset() {
    _speedHistory.clear();
  }
}
