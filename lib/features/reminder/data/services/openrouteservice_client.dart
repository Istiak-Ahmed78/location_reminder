import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for OpenRouteService API
class OpenRouteServiceClient {
  final String apiKey;
  final http.Client httpClient;

  static const String _baseUrl = 'https://api.openrouteservice.org';
  static const Duration _timeout = Duration(seconds: 10);

  OpenRouteServiceClient({required this.apiKey, http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  /// Fetch ETA from OpenRouteService
  /// Returns duration in seconds, or null if failed
  Future<int?> getETA({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String profile =
        'driving-car', // driving-car, foot-walking, cycling-regular
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/v2/directions/$profile?start=$startLon,$startLat&end=$endLon,$endLat',
      );

      final response = await httpClient
          .get(
            url,
            headers: {
              'Authorization': apiKey,
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final duration =
            data['features'][0]['properties']['summary']['duration'] as num;
        return duration.toInt();
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        throw RateLimitException('API rate limit exceeded');
      } else {
        throw ApiException(
          'API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e is RateLimitException || e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to fetch ETA: $e');
    }
  }

  /// Detect transport mode based on speed (m/s)
  String detectTransportMode(double speedMs) {
    final speedKmh = speedMs * 3.6;

    if (speedKmh < 8) {
      return 'foot-walking'; // < 8 km/h = walking
    } else if (speedKmh < 25) {
      return 'cycling-regular'; // 8-25 km/h = cycling
    } else {
      return 'driving-car'; // > 25 km/h = driving
    }
  }

  void dispose() {
    httpClient.close();
  }
}

/// Exception thrown when API rate limit is exceeded
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when API request fails
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
