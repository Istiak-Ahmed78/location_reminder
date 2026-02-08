import 'dart:math';
import '../entities/eta_result.dart';
import '../entities/user_location.dart';

/// Calculate ETA using local GPS speed data
class CalculateLocalETA {
  static const int _maxSpeedHistory = 10;
  static const double _minMovingSpeed = 0.5; // m/s (1.8 km/h)

  final List<_SpeedEntry> _speedHistory = [];

  /// Calculate ETA based on current location and speed history
  ETAResult call({
    required UserLocation currentLocation,
    required double destinationLat,
    required double destinationLon,
  }) {
    // Add current speed to history
    if (currentLocation.speed != null && currentLocation.speed! >= 0) {
      _addSpeedToHistory(currentLocation.speed!, currentLocation.timestamp);
    }

    // Calculate distance
    final distance = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      destinationLat,
      destinationLon,
    );

    // Check if user is moving
    final averageSpeed = _getAverageSpeed();

    if (averageSpeed < _minMovingSpeed) {
      // User is stationary or moving very slowly
      return ETAResult(
        seconds: 0,
        source: ETASource.localGPS,
        confidence: 0.0,
        calculatedAt: DateTime.now(),
        distanceMeters: distance,
        currentSpeed: averageSpeed,
      );
    }

    // Calculate ETA
    final etaSeconds = (distance / averageSpeed).round();

    // Calculate confidence based on speed stability
    final confidence = _calculateConfidence();

    return ETAResult(
      seconds: etaSeconds,
      source: ETASource.localGPS,
      confidence: confidence,
      calculatedAt: DateTime.now(),
      distanceMeters: distance,
      currentSpeed: averageSpeed,
    );
  }

  /// Add speed to history
  void _addSpeedToHistory(double speed, DateTime timestamp) {
    _speedHistory.add(_SpeedEntry(speed, timestamp));

    // Keep only last N entries
    if (_speedHistory.length > _maxSpeedHistory) {
      _speedHistory.removeAt(0);
    }
  }

  /// Get average speed from history
  double _getAverageSpeed() {
    if (_speedHistory.isEmpty) return 0.0;

    // Remove outliers (speeds that are too different from median)
    final speeds = _speedHistory.map((e) => e.speed).toList()..sort();
    final median = speeds[speeds.length ~/ 2];

    final filteredSpeeds = speeds.where((speed) {
      return (speed - median).abs() < median * 0.5; // Within 50% of median
    }).toList();

    if (filteredSpeeds.isEmpty) return 0.0;

    return filteredSpeeds.reduce((a, b) => a + b) / filteredSpeeds.length;
  }

  /// Calculate confidence based on speed stability
  double _calculateConfidence() {
    if (_speedHistory.length < 3)
      return 0.5; // Low confidence with few data points

    final speeds = _speedHistory.map((e) => e.speed).toList();
    final average = speeds.reduce((a, b) => a + b) / speeds.length;

    // Calculate standard deviation
    final variance =
        speeds.map((speed) => pow(speed - average, 2)).reduce((a, b) => a + b) /
        speeds.length;
    final stdDev = sqrt(variance);

    // Lower standard deviation = higher confidence
    final coefficientOfVariation = average > 0 ? stdDev / average : 1.0;

    // Convert to confidence (0.0 to 1.0)
    // CV < 0.2 = high confidence, CV > 0.5 = low confidence
    final confidence = (1.0 - coefficientOfVariation.clamp(0.0, 1.0)) * 0.8;

    return confidence.clamp(0.3, 0.8); // Local GPS max confidence is 0.8
  }

  /// Calculate distance between two coordinates
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

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Clear speed history
  void reset() {
    _speedHistory.clear();
  }
}

/// Speed entry with timestamp
class _SpeedEntry {
  final double speed;
  final DateTime timestamp;

  _SpeedEntry(this.speed, this.timestamp);
}
