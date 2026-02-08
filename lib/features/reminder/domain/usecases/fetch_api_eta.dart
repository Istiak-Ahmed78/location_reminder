import '../entities/eta_result.dart';
import '../../data/services/openrouteservice_client.dart';
import '../../data/services/eta_cache_service.dart';

/// Fetch ETA from OpenRouteService API
class FetchAPIETA {
  final OpenRouteServiceClient apiClient;
  final ETACacheService cacheService;

  FetchAPIETA({required this.apiClient, required this.cacheService});

  /// Fetch ETA from API with caching and rate limiting
  Future<ETAResult?> call({
    required double currentLat,
    required double currentLon,
    required double destinationLat,
    required double destinationLon,
    required double currentSpeed, // m/s
    required double distance,
  }) async {
    try {
      // Check rate limit
      if (!await cacheService.incrementRequestCount()) {
        return null; // Rate limit exceeded
      }

      // Detect transport mode
      final profile = apiClient.detectTransportMode(currentSpeed);

      // Fetch from API
      final seconds = await apiClient.getETA(
        startLat: currentLat,
        startLon: currentLon,
        endLat: destinationLat,
        endLon: destinationLon,
        profile: profile,
      );

      if (seconds == null) return null;

      // Cache the result
      await cacheService.cacheETA(
        seconds: seconds,
        lat: currentLat,
        lon: currentLon,
        timestamp: DateTime.now(),
      );

      return ETAResult(
        seconds: seconds,
        source: ETASource.api,
        confidence: 0.95, // API has high confidence
        calculatedAt: DateTime.now(),
        distanceMeters: distance,
        currentSpeed: currentSpeed,
      );
    } on RateLimitException {
      return null;
    } on ApiException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get cached ETA if available
  ETAResult? getCached({
    required double currentLat,
    required double currentLon,
    required double distance,
    required double currentSpeed,
  }) {
    final cached = cacheService.getCachedETA(
      currentLat: currentLat,
      currentLon: currentLon,
    );

    if (cached == null) return null;

    return ETAResult(
      seconds: cached['seconds'] as int,
      source: ETASource.cached,
      confidence: 0.85, // Cached data has slightly lower confidence
      calculatedAt: DateTime.parse(cached['timestamp'] as String),
      distanceMeters: distance,
      currentSpeed: currentSpeed,
    );
  }
}
