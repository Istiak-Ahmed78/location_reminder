import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/eta_result.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/usecases/calculate_local_eta.dart';
import '../../domain/usecases/fetch_api_eta.dart';
import '../../domain/usecases/get_blended_eta.dart';
import '../../data/services/eta_cache_service.dart';
import 'eta_event.dart';
import 'eta_state.dart';
import 'dart:math';

/// BLoC for managing ETA calculations
class ETABloc extends Bloc<ETAEvent, ETAState> {
  final CalculateLocalETA calculateLocalETA;
  final FetchAPIETA fetchAPIETA;
  final GetBlendedETA getBlendedETA;
  final ETACacheService cacheService;

  // Destination coordinates
  double? _destinationLat;
  double? _destinationLon;

  // Last known location for direction detection
  double? _lastLat;
  double? _lastLon;

  // API refresh timer
  Timer? _apiRefreshTimer;

  ETABloc({
    required this.calculateLocalETA,
    required this.fetchAPIETA,
    required this.getBlendedETA,
    required this.cacheService,
  }) : super(ETAState.initial()) {
    on<ETACalculationStarted>(_onCalculationStarted);
    on<ETALocationUpdated>(_onLocationUpdated);
    on<ETAAPIRefreshRequested>(_onAPIRefreshRequested);
    on<ETACalculationStopped>(_onCalculationStopped);
    on<ETAResetRequested>(_onResetRequested);
  }

  /// Handle calculation started
  Future<void> _onCalculationStarted(
    ETACalculationStarted event,
    Emitter<ETAState> emit,
  ) async {
    print(
      '🟡 ETABloc: Calculation started - Destination: ${event.destinationLat}, ${event.destinationLon}',
    );

    _destinationLat = event.destinationLat;
    _destinationLon = event.destinationLon;

    // ✅ FIXED: Emit with isActive: true, eta: null
    emit(
      state.copyWith(
        isActive: true, // ← Must be true!
        eta: null, // ← Clear old ETA
        error: null,
      ),
    );

    print('✅ ETABloc: State emitted - isActive: true, waiting for location...');

    // Start periodic API refresh timer (every 10 minutes)
    _startAPIRefreshTimer();

    // Try to load cached API data
    _loadCachedAPIData(emit);
  }

  /// Handle location update
  Future<void> _onLocationUpdated(
    ETALocationUpdated event,
    Emitter<ETAState> emit,
  ) async {
    print(
      '🟢 ETABloc: Location update received - Lat: ${event.currentLat}, Lon: ${event.currentLon}, Distance: ${event.distance}',
    );

    if (!state.isActive || _destinationLat == null || _destinationLon == null) {
      print(
        '⚠️ ETABloc: Ignoring location update - isActive: ${state.isActive}, hasDestination: ${_destinationLat != null}',
      );
      return;
    }

    // Check if user is moving
    final speed = event.speed ?? 0.0;
    final isMoving = speed >= 0.5; // 0.5 m/s = 1.8 km/h

    // Check if user is moving toward destination
    final isMovingToward = _isMovingToward(
      event.currentLat,
      event.currentLon,
      event.distance,
    );

    // Update last position for next direction check
    _lastLat = event.currentLat;
    _lastLon = event.currentLon;

    // Calculate local ETA
    final localETA = calculateLocalETA(
      currentLocation: UserLocation(
        latitude: event.currentLat,
        longitude: event.currentLon,
        speed: speed,
        timestamp: DateTime.now(),
      ),
      destinationLat: _destinationLat!,
      destinationLon: _destinationLon!,
    );

    print(
      '🟢 ETABloc: Local ETA calculated - ${localETA.seconds}s (${(localETA.seconds / 60).toStringAsFixed(1)}m)',
    );

    // Get cached or current API ETA
    ETAResult? apiETA =
        state.eta?.source == ETASource.api ||
            state.eta?.source == ETASource.cached ||
            state.eta?.source == ETASource.blended
        ? state.eta
        : null;

    // Blend if we have API data
    final finalETA = apiETA != null
        ? getBlendedETA(localETA: localETA, apiETA: apiETA)
        : localETA;

    // Check rate limit status
    final remaining = cacheService.getRemainingRequests();
    final rateLimitStatus = _getRateLimitStatus(remaining);

    // ✅ ADD DEBUG PRINTS BEFORE EMIT
    print('🔍 ETABloc: About to emit new state:');
    print('   Current state timestamp: ${state.timestamp}');
    print('   Current state eta: ${state.eta?.seconds}');
    print('   Current state eta hashCode: ${state.eta?.hashCode}');
    print('   New finalETA seconds: ${finalETA.seconds}');
    print('   New finalETA timestamp: ${finalETA.timestamp}');
    print('   New finalETA hashCode: ${finalETA.hashCode}');

    final newState = state.copyWith(
      eta: finalETA,
      isActive: true,
      isMoving: isMoving,
      isMovingToward: isMovingToward,
      rateLimitStatus: rateLimitStatus,
      remainingAPIRequests: remaining,
      clearError: true,
    );

    // ✅ ADD DEBUG PRINTS AFTER CREATING NEW STATE
    print('🔍 ETABloc: New state created:');
    print('   New state timestamp: ${newState.timestamp}');
    print('   New state eta: ${newState.eta?.seconds}');
    print('   New state eta hashCode: ${newState.eta.hashCode}');
    print('   Old state == New state: ${state == newState}');
    print('   About to call emit()...');

    emit(newState);

    print(
      '✅ ETABloc: State emitted - ETA: ${finalETA.seconds}s, Source: ${finalETA.source}, isActive: true',
    );

    // Auto-refresh API if needed
    if (state.shouldCallAPI() && rateLimitStatus != RateLimitStatus.exceeded) {
      add(const ETAAPIRefreshRequested(isAutomatic: true));
    }
  }

  /// Handle API refresh request
  Future<void> _onAPIRefreshRequested(
    ETAAPIRefreshRequested event,
    Emitter<ETAState> emit,
  ) async {
    if (!state.isActive ||
        _destinationLat == null ||
        _destinationLon == null ||
        state.eta == null) {
      return;
    }

    // Check rate limit
    if (state.rateLimitStatus == RateLimitStatus.exceeded) {
      return;
    }

    emit(
      state.copyWith(isFetchingAPI: true, isActive: true),
    ); // ← Keep isActive true

    try {
      final apiETA = await fetchAPIETA(
        currentLat: state.eta!.distanceMeters > 0
            ? _lastLat ?? _destinationLat!
            : _destinationLat!,
        currentLon: state.eta!.distanceMeters > 0
            ? _lastLon ?? _destinationLon!
            : _destinationLon!,
        destinationLat: _destinationLat!,
        destinationLon: _destinationLon!,
        currentSpeed: state.eta!.currentSpeed ?? 0.0,
        distance: state.eta!.distanceMeters,
      );

      if (apiETA != null) {
        // Blend with current local ETA
        final blendedETA = getBlendedETA(localETA: state.eta!, apiETA: apiETA);

        final remaining = cacheService.getRemainingRequests();

        emit(
          state.copyWith(
            eta: blendedETA,
            isActive: true, // ← Keep isActive true
            isFetchingAPI: false,
            lastAPICall: DateTime.now(),
            rateLimitStatus: _getRateLimitStatus(remaining),
            remainingAPIRequests: remaining,
          ),
        );
      } else {
        // API failed, continue with local
        emit(
          state.copyWith(isFetchingAPI: false, isActive: true),
        ); // ← Keep isActive true
      }
    } catch (e) {
      emit(
        state.copyWith(
          isFetchingAPI: false,
          isActive: true, // ← Keep isActive true
          error: 'Failed to fetch API data',
        ),
      );
    }
  }

  /// Handle calculation stopped
  Future<void> _onCalculationStopped(
    ETACalculationStopped event,
    Emitter<ETAState> emit,
  ) async {
    print('🔴 ETABloc: Calculation stopped');

    _stopAPIRefreshTimer();
    calculateLocalETA.reset();

    emit(state.copyWith(isActive: false, eta: null));
  }

  /// Handle reset
  Future<void> _onResetRequested(
    ETAResetRequested event,
    Emitter<ETAState> emit,
  ) async {
    print('🔴 ETABloc: Reset requested');

    _stopAPIRefreshTimer();
    calculateLocalETA.reset();
    _destinationLat = null;
    _destinationLon = null;
    _lastLat = null;
    _lastLon = null;

    emit(ETAState.initial());
  }

  /// Load cached API data on start
  void _loadCachedAPIData(Emitter<ETAState> emit) {
    if (_lastLat == null || _lastLon == null) return;

    final cachedETA = fetchAPIETA.getCached(
      currentLat: _lastLat!,
      currentLon: _lastLon!,
      distance: 0,
      currentSpeed: 0,
    );

    if (cachedETA != null) {
      emit(
        state.copyWith(
          eta: cachedETA,
          isActive: true, // ← Keep isActive true
          lastAPICall: cachedETA.calculatedAt,
        ),
      );
    }
  }

  /// Check if user is moving toward destination
  bool _isMovingToward(double currentLat, double currentLon, double distance) {
    if (_lastLat == null || _lastLon == null) {
      return true; // Assume moving toward on first update
    }

    // Calculate previous distance
    final previousDistance = _calculateDistance(
      _lastLat!,
      _lastLon!,
      _destinationLat!,
      _destinationLon!,
    );

    // If current distance is less than previous, moving toward
    return distance < previousDistance;
  }

  /// Calculate distance between two points
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

  /// Get rate limit status based on remaining requests
  RateLimitStatus _getRateLimitStatus(int remaining) {
    if (remaining <= 0) return RateLimitStatus.exceeded;
    if (remaining < 400) return RateLimitStatus.warning; // < 20%
    return RateLimitStatus.ok;
  }

  /// Start periodic API refresh timer
  void _startAPIRefreshTimer() {
    _stopAPIRefreshTimer();
    _apiRefreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => add(const ETAAPIRefreshRequested(isAutomatic: true)),
    );
  }

  /// Stop API refresh timer
  void _stopAPIRefreshTimer() {
    _apiRefreshTimer?.cancel();
    _apiRefreshTimer = null;
  }

  @override
  Future<void> close() {
    _stopAPIRefreshTimer();
    return super.close();
  }
}
