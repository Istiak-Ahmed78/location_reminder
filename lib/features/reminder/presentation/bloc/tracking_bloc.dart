import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/notifications/local_notifications_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/destination_reminder.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/usecases/get_active_reminder.dart';
import '../../domain/usecases/get_last_cached_location.dart';
import '../../domain/usecases/watch_position.dart';
import '../../domain/usecases/watch_position_params.dart';

part 'tracking_event.dart';
part 'tracking_state.dart';

/// Manages location tracking and destination reminder monitoring
class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final WatchPosition watchPosition;
  final GetActiveReminder getActiveReminder;
  final GetLastCachedLocation getLastCachedLocation;
  final LocalNotificationsService notifications;

  StreamSubscription<UserLocation>? _locationSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  Timer? _adaptiveTimer;
  double _lastDistance = double.infinity;
  DateTime? _lastLocationTime;
  bool _isLocationOnlyMode = false;
  bool _wasInsideRadius = false; // Track previous state

  TrackingBloc({
    required this.watchPosition,
    required this.getActiveReminder,
    required this.notifications,
    required this.getLastCachedLocation,
  }) : super(const TrackingState.initial()) {
    on<TrackingStarted>(_onStarted);
    on<TrackingStopped>(_onStopped);
    on<TrackingStartedForLocationOnly>(_onStartedForLocationOnly);
    on<_TrackingLocationUpdated>(_onLocationUpdated);
    on<TrackingSettingsAdjusted>(_onSettingsAdjusted);
    on<_TrackingServiceEnabled>(_onServiceEnabled);
    on<_TrackingServiceDisabled>(_onServiceDisabled);
  }

  // ==================== EVENT HANDLERS ====================

  /// Starts tracking with an active reminder
  Future<void> _onStarted(
    TrackingStarted event,
    Emitter<TrackingState> emit,
  ) async {
    print('🚀 [TRACKING] TrackingStarted event received');
    _isLocationOnlyMode = false;
    emit(
      state.copyWith(status: TrackingStatus.loading, clearErrorMessage: true),
    );

    try {
      final reminder = await getActiveReminder(const NoParams());
      print('🚀 [TRACKING] Got active reminder: ${reminder?.label ?? "NULL"}');

      if (reminder == null) {
        print('❌ [TRACKING] No active reminder found!');
        emit(
          state.copyWith(
            status: TrackingStatus.failure,
            errorMessage: 'No active reminder. Save a destination first.',
            clearErrorMessage: false,
          ),
        );
        return;
      }

      print('🚀 [TRACKING] Starting tracking for: ${reminder.label}');
      _resetTrackingState();
      await _cancelAllSubscriptions();

      // ✅ AWAIT this method call
      await _startTrackingWithSettings(
        distanceFilter: 10,
        accuracy: LocationAccuracy.high,
        reminder: reminder,
        emit: emit,
      );

      _setupAdaptiveTimer(reminder, emit);
      _startServiceStatusListener();
      print('✅ [TRACKING] Tracking started successfully');
    } catch (e) {
      print('❌ [TRACKING] Error starting tracking: $e');
      emit(
        state.copyWith(
          status: TrackingStatus.failure,
          errorMessage: e.toString(),
          clearErrorMessage: false,
        ),
      );
    }
  }

  /// Starts location-only mode (no reminder tracking)
  Future<void> _onStartedForLocationOnly(
    TrackingStartedForLocationOnly event,
    Emitter<TrackingState> emit,
  ) async {
    _isLocationOnlyMode = true;
    emit(
      state.copyWith(status: TrackingStatus.loading, clearErrorMessage: true),
    );

    try {
      final result = await getLastCachedLocation(const NoParams());

      await result.fold(
        (failure) async {
          await _startLiveLocationStream(emit);
          _startServiceStatusListener();
        },
        (cachedLocation) async {
          if (cachedLocation != null) {
            emit(
              state.copyWith(
                status: TrackingStatus.tracking,
                current: cachedLocation,
                isLive: false,
                activeReminder: null,
                distanceMeters: null,
                insideRadius: null,
                triggered: false,
                trackingSettings: null,
                clearErrorMessage: true,
              ),
            );
          }

          await _startLiveLocationStream(emit);
          _startServiceStatusListener();
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TrackingStatus.failure,
          errorMessage: e.toString(),
          clearErrorMessage: false,
        ),
      );
    }
  }

  /// Stops all tracking and cleans up resources
  Future<void> _onStopped(
    TrackingStopped event,
    Emitter<TrackingState> emit,
  ) async {
    await _cancelAllSubscriptions();
    _resetTrackingState();
    _isLocationOnlyMode = false;

    emit(
      state.copyWith(
        status: TrackingStatus.idle,
        errorMessage: event.error,
        clearErrorMessage: event.error == null,
      ),
    );
  }

  /// Handles location updates from the stream
  /// Handles location updates from the stream
  Future<void> _onLocationUpdated(
    _TrackingLocationUpdated event,
    Emitter<TrackingState> emit,
  ) async {
    print(
      '🔵 [TRACKING] Location updated: ${event.location.latitude}, ${event.location.longitude}',
    );

    final reminder = state.activeReminder;
    print('🔵 [TRACKING] Active reminder: ${reminder?.label ?? "NULL"}');

    // Location-only mode (no reminder)
    if (reminder == null) {
      print('🟡 [TRACKING] Location-only mode (no reminder)');
      emit(
        state.copyWith(
          status: TrackingStatus.tracking,
          current: event.location,
          isLive: true,
          distanceMeters: null,
          insideRadius: null,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    // ==================== REMINDER TRACKING MODE ====================
    print('🟢 [TRACKING] Reminder tracking mode activated');

    // Calculate distance to destination
    final distance = _calculateDistance(
      event.location.latitude,
      event.location.longitude,
      reminder.latitude,
      reminder.longitude,
    );

    print('🟢 [TRACKING] Calculated distance: ${distance.toStringAsFixed(2)}m');
    print('🟢 [TRACKING] Trigger distance: ${reminder.triggerDistanceMeters}m');

    // Check if inside radius
    final isInsideRadius = distance <= reminder.triggerDistanceMeters;
    print('🟢 [TRACKING] Inside radius: $isInsideRadius');

    // Detect entry into radius (was outside, now inside)
    final justEntered = !_wasInsideRadius && isInsideRadius;
    print(
      '🟢 [TRACKING] Just entered: $justEntered (was inside: $_wasInsideRadius)',
    );

    // Update tracking state
    _lastDistance = distance;
    _lastLocationTime = event.location.timestamp;
    _wasInsideRadius = isInsideRadius;

    // Trigger notification on entry
    if (justEntered && !state.triggered) {
      print('🔔 [TRACKING] Triggering arrival notification!');
      await _triggerArrivalNotification(reminder, distance);

      emit(
        state.copyWith(
          status: TrackingStatus.tracking,
          current: event.location,
          isLive: true,
          distanceMeters: distance,
          insideRadius: isInsideRadius,
          triggered: true, // Mark as triggered
          clearErrorMessage: true,
        ),
      );
    } else {
      print(
        '📍 [TRACKING] Normal update - Distance: ${distance.toStringAsFixed(2)}m',
      );
      // Normal update without notification
      emit(
        state.copyWith(
          status: TrackingStatus.tracking,
          current: event.location,
          isLive: true,
          distanceMeters: distance,
          insideRadius: isInsideRadius,
          clearErrorMessage: true,
        ),
      );
    }

    print(
      '✅ [TRACKING] State emitted - distanceMeters: ${state.distanceMeters}',
    );
  }

  /// Adjusts tracking settings based on distance and movement
  Future<void> _onSettingsAdjusted(
    TrackingSettingsAdjusted event,
    Emitter<TrackingState> emit,
  ) async {
    final reminder = state.activeReminder;
    if (reminder == null) return;

    await _locationSubscription?.cancel();

    // ✅ AWAIT this method call
    await _startTrackingWithSettings(
      distanceFilter: event.distanceFilter,
      accuracy: event.accuracy,
      reminder: reminder,
      emit: emit,
    );
  }

  /// Handles location service being enabled
  Future<void> _onServiceEnabled(
    _TrackingServiceEnabled event,
    Emitter<TrackingState> emit,
  ) async {
    if (_isLocationOnlyMode) {
      await _startLiveLocationStream(emit);
    }
  }

  /// Handles location service being disabled
  Future<void> _onServiceDisabled(
    _TrackingServiceDisabled event,
    Emitter<TrackingState> emit,
  ) async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    emit(
      state.copyWith(
        isLive: false,
        errorMessage:
            'Location service is disabled. Turn it on to get live updates.',
        clearErrorMessage: false,
      ),
    );
  }

  // ==================== LOCATION STREAMING ====================

  /// Starts the live location stream
  Future<void> _startLiveLocationStream(Emitter<TrackingState> emit) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!emit.isDone) {
          emit(
            state.copyWith(
              status: TrackingStatus.tracking,
              isLive: false,
              errorMessage:
                  'Location service is disabled. Turn it on to get live updates.',
              clearErrorMessage: false,
            ),
          );
        }
        return;
      }

      final stream = await watchPosition(
        const WatchPositionParams(
          distanceFilter: 10,
          accuracy: LocationAccuracy.medium,
        ),
      );

      await _locationSubscription?.cancel();

      _locationSubscription = stream.listen(
        (location) => add(_TrackingLocationUpdated(location)),
        onError: (error) {
          if (!isClosed) {
            add(const _TrackingServiceDisabled());
          }
        },
      );
    } catch (e) {
      if (!emit.isDone) {
        emit(
          state.copyWith(
            status: TrackingStatus.tracking,
            isLive: false,
            errorMessage: 'Failed to start location updates: $e',
            clearErrorMessage: false,
          ),
        );
      }
    }
  }

  /// Starts tracking with specific settings for reminder mode
  Future<void> _startTrackingWithSettings({
    required double distanceFilter,
    required LocationAccuracy accuracy,
    required DestinationReminder reminder,
    required Emitter<TrackingState> emit,
  }) async {
    print('⚙️ [TRACKING] Starting tracking with settings:');
    print('   - Distance filter: $distanceFilter');
    print('   - Accuracy: $accuracy');
    print('   - Reminder: ${reminder.label}');

    try {
      final stream = await watchPosition(
        WatchPositionParams(distanceFilter: distanceFilter, accuracy: accuracy),
      );

      await _locationSubscription?.cancel();

      _locationSubscription = stream.listen(
        (location) {
          print('📡 [TRACKING] Location received from stream');
          add(_TrackingLocationUpdated(location));
        },
        onError: (error) {
          print('❌ [TRACKING] Stream error: $error');
          add(TrackingStopped(error: error.toString()));
        },
      );

      if (!emit.isDone) {
        emit(
          state.copyWith(
            status: TrackingStatus.tracking,
            activeReminder: reminder,
            current: null,
            distanceMeters: null,
            insideRadius: null,
            triggered: false,
            trackingSettings: TrackingSettings(
              distanceFilter: distanceFilter,
              accuracy: accuracy.toString(),
              lastUpdated: DateTime.now(),
            ),
            clearErrorMessage: true,
          ),
        );

        print(
          '✅ [TRACKING] Settings applied, activeReminder set: ${reminder.label}',
        );
      }
    } catch (e) {
      print('❌ [TRACKING] Error in _startTrackingWithSettings: $e');
      if (!emit.isDone) {
        add(TrackingStopped(error: e.toString()));
      }
    }
  }

  // ==================== SERVICE STATUS MONITORING ====================

  /// Listens to location service status changes
  void _startServiceStatusListener() {
    _serviceStatusSubscription?.cancel();

    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
      status,
    ) {
      if (status == ServiceStatus.enabled) {
        add(const _TrackingServiceEnabled());
      } else if (status == ServiceStatus.disabled) {
        add(const _TrackingServiceDisabled());
      }
    });
  }

  // ==================== ADAPTIVE TRACKING ====================

  /// Sets up adaptive tracking that adjusts based on distance and movement
  void _setupAdaptiveTimer(
    DestinationReminder reminder,
    Emitter<TrackingState> emit,
  ) {
    _adaptiveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final currentDistance = state.distanceMeters;
      final lastUpdate = _lastLocationTime;

      if (currentDistance == null || lastUpdate == null) return;

      final isMovingToward = currentDistance < _lastDistance;
      final timeSinceLastUpdate = DateTime.now().difference(lastUpdate);

      final (newDistanceFilter, newAccuracy) = _calculateAdaptiveSettings(
        currentDistance: currentDistance,
        isMovingToward: isMovingToward,
        timeSinceLastUpdate: timeSinceLastUpdate,
      );

      final currentSettings = state.trackingSettings;
      final shouldAdjust =
          currentSettings == null ||
          (currentSettings.distanceFilter != newDistanceFilter &&
              (newDistanceFilter / currentSettings.distanceFilter).abs() > 1.5);

      if (shouldAdjust) {
        add(
          TrackingSettingsAdjusted(
            distanceFilter: newDistanceFilter,
            accuracy: newAccuracy,
          ),
        );
      }

      _lastDistance = currentDistance;
    });
  }

  /// Calculates optimal tracking settings based on current conditions
  (double distanceFilter, LocationAccuracy accuracy)
  _calculateAdaptiveSettings({
    required double currentDistance,
    required bool isMovingToward,
    required Duration timeSinceLastUpdate,
  }) {
    double distanceFilter;
    LocationAccuracy accuracy;

    // Base settings on distance
    if (currentDistance > 5000) {
      distanceFilter = 1000;
      accuracy = LocationAccuracy.low;
    } else if (currentDistance > 1000) {
      distanceFilter = 100;
      accuracy = LocationAccuracy.medium;
    } else if (currentDistance > 500) {
      distanceFilter = 50;
      accuracy = LocationAccuracy.medium;
    } else {
      distanceFilter = 10;
      accuracy = LocationAccuracy.high;
    }

    // Reduce frequency if not moving toward destination
    if (!isMovingToward && currentDistance > 1000) {
      distanceFilter *= 2;
    }

    // Reduce frequency if stationary for a long time
    if (timeSinceLastUpdate > const Duration(minutes: 5) &&
        currentDistance > 1000) {
      distanceFilter = 2000;
      accuracy = LocationAccuracy.lowest;
    }

    return (distanceFilter, accuracy);
  }

  // ==================== DISTANCE & NOTIFICATION ====================

  /// Calculates distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Triggers arrival notification
  Future<void> _triggerArrivalNotification(
    DestinationReminder reminder,
    double distance,
  ) async {
    try {
      await notifications.showArrivalNotification(
        title: '📍 Arrived at ${reminder.label}',
        body: 'You are ${distance.toStringAsFixed(0)}m from your destination!',
      );
    } catch (e) {
      print('⚠️ Failed to show notification: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  /// Cancels all active subscriptions
  Future<void> _cancelAllSubscriptions() async {
    await _locationSubscription?.cancel();
    await _serviceStatusSubscription?.cancel();
    _adaptiveTimer?.cancel();
    _locationSubscription = null;
    _serviceStatusSubscription = null;
    _adaptiveTimer = null;
  }

  /// Resets tracking state variables
  void _resetTrackingState() {
    _lastDistance = double.infinity;
    _lastLocationTime = null;
    _wasInsideRadius = false;
  }

  @override
  Future<void> close() async {
    await _cancelAllSubscriptions();
    return super.close();
  }
}
