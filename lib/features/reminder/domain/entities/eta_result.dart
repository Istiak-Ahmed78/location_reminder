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

  /// Average speed in m/s (if available)
  final double? averageSpeed;

  /// Unique timestamp to force state changes
  final int timestamp;

  ETAResult({
    required this.seconds,
    required this.source,
    required this.confidence,
    required this.calculatedAt,
    required this.distanceMeters,
    this.currentSpeed,
    this.averageSpeed,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch {
    print(
      '🔍 ETAResult created: seconds=$seconds, source=$source, timestamp=${this.timestamp}',
    );
  }

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
  List<Object?> get props {
    return [
      seconds,
      source,
      confidence,
      calculatedAt,
      distanceMeters,
      currentSpeed,
      averageSpeed,
      timestamp,
    ];
  }

  // ✅ ADD THIS: Override hashCode to match props
  @override
  int get hashCode {
    return Object.hash(
      seconds,
      source,
      confidence,
      calculatedAt,
      distanceMeters,
      currentSpeed,
      averageSpeed,
      timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is ETAResult) {
      print('🔍 ETAResult == comparison:');
      print(
        '   this.timestamp: $timestamp vs other.timestamp: ${other.timestamp}',
      );
      print('   this.seconds: $seconds vs other.seconds: ${other.seconds}');

      final result = super == other;
      print('   Result: $result');
      return result;
    }

    return false;
  }

  ETAResult copyWith({
    int? seconds,
    ETASource? source,
    double? confidence,
    DateTime? calculatedAt,
    double? distanceMeters,
    double? currentSpeed,
    double? averageSpeed,
  }) {
    final newTimestamp = DateTime.now().millisecondsSinceEpoch;

    print(
      '🔍 ETAResult.copyWith: old timestamp=$timestamp, new timestamp=$newTimestamp',
    );

    return ETAResult(
      seconds: seconds ?? this.seconds,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      timestamp: newTimestamp,
    );
  }

  @override
  String toString() {
    return 'ETAResult(seconds: $seconds, source: $source, timestamp: $timestamp, confidence: $confidence)';
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
