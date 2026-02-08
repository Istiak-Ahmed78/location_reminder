import '../entities/eta_result.dart';

/// Blend local GPS and API ETA for best accuracy
class GetBlendedETA {
  static const Duration _apiMaxAge = Duration(minutes: 15);

  /// Blend local and API ETA based on freshness and confidence
  ETAResult call({required ETAResult localETA, ETAResult? apiETA}) {
    // If no API data, use local
    if (apiETA == null) {
      return localETA;
    }

    // If API data is too old, use local
    final apiAge = DateTime.now().difference(apiETA.calculatedAt);
    if (apiAge > _apiMaxAge) {
      return localETA;
    }

    // Calculate weights based on API freshness
    final apiWeight = _calculateAPIWeight(apiAge);
    final localWeight = 1.0 - apiWeight;

    // Blend ETA values
    final blendedSeconds =
        (apiETA.seconds * apiWeight + localETA.seconds * localWeight).round();

    // Blend confidence
    final blendedConfidence =
        (apiETA.confidence * apiWeight + localETA.confidence * localWeight)
            .clamp(0.0, 1.0);

    return ETAResult(
      seconds: blendedSeconds,
      source: ETASource.blended,
      confidence: blendedConfidence,
      calculatedAt: DateTime.now(),
      distanceMeters: localETA.distanceMeters,
      currentSpeed: localETA.currentSpeed,
    );
  }

  /// Calculate API weight based on age (newer = higher weight)
  double _calculateAPIWeight(Duration age) {
    final ageMinutes = age.inMinutes.toDouble();
    final maxAgeMinutes = _apiMaxAge.inMinutes.toDouble();

    // Linear decay: 100% at 0 min, 0% at 15 min
    final weight = 1.0 - (ageMinutes / maxAgeMinutes);
    return weight.clamp(0.0, 1.0);
  }
}
