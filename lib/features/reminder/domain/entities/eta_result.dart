import 'package:equatable/equatable.dart';

/// Represents an ETA calculation result with metadata
class ETAResult extends Equatable {
  /// Estimated time in seconds
  final int seconds;

  /// Source of the calculation
  final ETASource source;

  /// Confidence level (0.0 to 1.0)
  final double confidence;

  /// When this ETA was calculated
  final DateTime calculatedAt;

  /// Current distance in meters
  final double distanceMeters;

  /// Current speed in m/s (if available)
  final double? currentSpeed;

  const ETAResult({
    required this.seconds,
    required this.source,
    required this.confidence,
    required this.calculatedAt,
    required this.distanceMeters,
    this.currentSpeed,
  });

  /// Get formatted time string (e.g., "5 min", "45 sec")
  String get formattedTime {
    if (seconds < 60) {
      return '$seconds sec';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).round();
      return '$minutes min';
    } else {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).round();
      return '${hours}h ${minutes}min';
    }
  }

  /// Get confidence as stars (⭐⭐⭐)
  String get confidenceStars {
    if (confidence >= 0.8) return '⭐⭐⭐';
    if (confidence >= 0.6) return '⭐⭐';
    return '⭐';
  }

  /// Get source display name
  String get sourceDisplayName {
    switch (source) {
      case ETASource.localGPS:
        return 'GPS-based';
      case ETASource.api:
        return 'Traffic-aware';
      case ETASource.blended:
        return 'Enhanced';
      case ETASource.cached:
        return 'Cached';
    }
  }

  /// Check if this ETA is stale (older than 5 minutes)
  bool get isStale {
    return DateTime.now().difference(calculatedAt).inMinutes > 5;
  }

  @override
  List<Object?> get props => [
    seconds,
    source,
    confidence,
    calculatedAt,
    distanceMeters,
    currentSpeed,
  ];

  ETAResult copyWith({
    int? seconds,
    ETASource? source,
    double? confidence,
    DateTime? calculatedAt,
    double? distanceMeters,
    double? currentSpeed,
  }) {
    return ETAResult(
      seconds: seconds ?? this.seconds,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeed: currentSpeed ?? this.currentSpeed,
    );
  }
}

/// Source of ETA calculation
enum ETASource {
  /// Calculated from local GPS speed data
  localGPS,

  /// Fetched from OpenRouteService API
  api,

  /// Blended from both local and API data
  blended,

  /// Cached API result
  cached,
}
