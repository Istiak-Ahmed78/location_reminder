import '../entities/eta_result.dart';

/// Blend local GPS ETA with API ETA for optimal accuracy
class GetBlendedETA {
  /// Blend two ETA sources intelligently
  ETAResult call({required ETAResult localETA, required ETAResult apiETA}) {
    // Weight factors based on confidence and freshness
    final localWeight = _calculateWeight(localETA);
    final apiWeight = _calculateWeight(apiETA);

    // Normalize weights
    final totalWeight = localWeight + apiWeight;
    final normalizedLocalWeight = localWeight / totalWeight;
    final normalizedApiWeight = apiWeight / totalWeight;

    // Blend the ETA values
    final blendedSeconds =
        ((localETA.seconds * normalizedLocalWeight) +
                (apiETA.seconds * normalizedApiWeight))
            .round();

    // Calculate blended confidence
    final blendedConfidence =
        ((localETA.confidence * normalizedLocalWeight) +
        (apiETA.confidence * normalizedApiWeight));

    final result = ETAResult(
      seconds: blendedSeconds,
      distanceMeters: localETA.distanceMeters,
      currentSpeed: localETA.currentSpeed,
      source: ETASource.blended,
      calculatedAt: DateTime.now(),
      confidence: blendedConfidence,
      timestamp:
          DateTime.now().millisecondsSinceEpoch, // ← Make sure this is here
    );

    print(
      '🔍 GetBlendedETA: Created ETAResult - seconds: ${result.seconds}, timestamp: ${result.timestamp}',
    );

    return result;
  }

  /// Calculate weight based on confidence and age
  double _calculateWeight(ETAResult eta) {
    // Start with confidence as base weight
    double weight = eta.confidence;

    // Reduce weight for stale data
    final ageMinutes = DateTime.now().difference(eta.calculatedAt).inMinutes;
    if (ageMinutes > 5) {
      weight *= 0.5; // 50% penalty for stale data
    } else if (ageMinutes > 2) {
      weight *= 0.8; // 20% penalty for slightly old data
    }

    // Boost API data slightly (it considers traffic)
    if (eta.source == ETASource.api) {
      weight *= 1.1;
    }

    return weight;
  }
}
