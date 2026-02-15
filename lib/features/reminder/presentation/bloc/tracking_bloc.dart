import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_reminder/core/background/background_location_service.dart';
import 'package:location_reminder/core/background/foreground_location_service.dart';
import 'package:location_reminder/core/notifications/alarm_service.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_event.dart';

import '../../../../core/notifications/local_notifications_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/destination_reminder.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/usecases/get_active_reminder.dart';
import '../../domain/usecases/get_last_cached_location.dart';
import '../../domain/usecases/watch_position.dart';
import '../../domain/usecases/watch_position_params.dart';
import 'eta_bloc.dart';

part 'tracking_event.dart';
part 'tracking_state.dart';

/// Manages location tracking and destination reminder monitoring
class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final BackgroundLocationService backgroundService;
  final ForegroundLocationService foregroundService;
  final WatchPosition watchPosition;
  final GetActiveReminder getActiveReminder;
  final GetLastCachedLocation getLastCachedLocation;
  final LocalNotificationsService notifications;
  final ETABloc etaBloc;
  final AlarmService alarmService;

  StreamSubscription<UserLocation>? _locationSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  Timer? _adaptiveTimer;
  double _lastDistance = double.infinity;
  DateTime? _lastLocationTime;
  bool _isLocationOnlyMode = false;
  bool _wasInsideRadius = false;
  bool _alarmTriggered = false; // ← NEW: Prevent multiple alarm triggers

  TrackingBloc({
    required this.watchPosition,
    required this.getActiveReminder,
    required this.notifications,
    required this.getLastCachedLocation,
    required this.etaBloc,
    required this.backgroundService,
    required this.foregroundService,
    required this.alarmService,
  }) : super(const TrackingState.initial()) {
    _initializeBackgroundServices();
    _setupAppLifecycleListener();

    on<TrackingStarted>(_onStarted);
    on<TrackingStopped>(_onStopped);
    on<TrackingStartedForLocationOnly>(_onStartedForLocationOnly);
    on<_TrackingLocationUpdated>(_onLocationUpdated);
    on<TrackingSettingsAdjusted>(_onSettingsAdjusted);
    on<_TrackingServiceEnabled>(_onServiceEnabled);
    on<_TrackingServiceDisabled>(_onServiceDisabled);
  }

  // ==================== INITIALIZATION ====================

  Future<void> _initializeBackgroundServices() async {
    try {
      await backgroundService.initialize();
      print('✅ TrackingBloc: Background services initialized');
    } catch (e) {
      print('❌ TrackingBloc: Failed to initialize background services: $e');
    }
  }

  void _setupAppLifecycleListener() {
    AppLifecycleListener(
      onStateChange: (state) {
        print('📱 App lifecycle: $state');

        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) {
          _onAppToBackground();
        } else if (state == AppLifecycleState.resumed) {
          _onAppToForeground();
        } else if (state == AppLifecycleState.detached) {
          _onAppClosed();
        }
      },
    );
  }

  // ==================== EVENT HANDLERS ====================

  /// Starts tracking with an active reminder
  Future<void> _onStarted(
    TrackingStarted event,
    Emitter<TrackingState> emit,
  ) async {
    print('🚀 TrackingBloc: Starting tracking with reminder...');

    _isLocationOnlyMode = false;
    emit(
      state.copyWith(status: TrackingStatus.loading, clearErrorMessage: true),
    );

    try {
      final reminder = await getActiveReminder(const NoParams());

      if (reminder == null) {
        print('⚠️ TrackingBloc: No active reminder found');
        emit(
          state.copyWith(
            status: TrackingStatus.failure,
            errorMessage: 'No active reminder. Save a destination first.',
            clearErrorMessage: false,
          ),
        );
        return;
      }

      print('✅ TrackingBloc: Active reminder found: ${reminder.label}');

      // Save reminder for background service
      await backgroundService.saveActiveReminderForBackground(reminder);

      // Reset tracking state
      _resetTrackingState();
      await _cancelAllSubscriptions();

      // Start ETA calculation
      print('🎯 TrackingBloc: Starting ETA calculation...');
      etaBloc.add(
        ETACalculationStarted(
          destinationLat: reminder.latitude,
          destinationLon: reminder.longitude,
        ),
      );

      // Start location tracking
      print('📍 TrackingBloc: Starting location tracking...');
      await _startTrackingWithSettings(
        distanceFilter: 10,
        accuracy: LocationAccuracy.high,
        reminder: reminder,
      );

      emit(
        state.copyWith(
          status: TrackingStatus.tracking,
          activeReminder: reminder,
          isLive: false,
          trackingSettings: TrackingSettings(
            distanceFilter: 10,
            accuracy: LocationAccuracy.high.toString(),
            lastUpdated: DateTime.now(),
          ),
          clearErrorMessage: true,
        ),
      );

      // Setup adaptive tracking and service monitoring
      _setupAdaptiveTimer(reminder, emit);
      _startServiceStatusListener();

      print('✅ TrackingBloc: Tracking started successfully');
    } catch (e) {
      print('❌ TrackingBloc: Error starting tracking: $e');
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
    print('🚀 TrackingBloc: Starting location-only mode...');

    _isLocationOnlyMode = true;
    emit(
      state.copyWith(status: TrackingStatus.loading, clearErrorMessage: true),
    );

    try {
      // Try to get cached location first
      final result = await getLastCachedLocation(const NoParams());

      await result.fold(
        (failure) async {
          print('⚠️ TrackingBloc: No cached location, starting live stream');
          await _startLiveLocationStream(emit);
          _startServiceStatusListener();
        },
        (cachedLocation) async {
          if (cachedLocation != null) {
            print('✅ TrackingBloc: Using cached location');
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

      print('✅ TrackingBloc: Location-only mode started');
    } catch (e) {
      print('❌ TrackingBloc: Error starting location-only mode: $e');
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
    print('🛑 TrackingBloc: Stopping tracking...');

    // Stop background services
    await backgroundService.saveActiveReminderForBackground(null);
    await foregroundService.stopForegroundService();

    // Cancel subscriptions
    await _cancelAllSubscriptions();

    // Reset state
    _resetTrackingState();
    _isLocationOnlyMode = false;

    // Stop ETA calculation
    etaBloc.add(const ETACalculationStopped());

    emit(
      state.copyWith(
        status: TrackingStatus.idle,
        isLive: false,
        errorMessage: event.error,
        clearErrorMessage: event.error == null,
      ),
    );

    print('✅ TrackingBloc: Tracking stopped');
  }

  /// Handles location updates
  Future<void> _onLocationUpdated(
    _TrackingLocationUpdated event,
    Emitter<TrackingState> emit,
  ) async {
    final location = event.location;
    _lastLocationTime = DateTime.now();

    print(
      '📍 TrackingBloc: Location updated - Lat: ${location.latitude}, Lon: ${location.longitude}',
    );

    if (state.activeReminder != null) {
      final reminder = state.activeReminder!;

      // Calculate distance to destination
      final distance = _calculateDistance(
        location.latitude,
        location.longitude,
        reminder.latitude,
        reminder.longitude,
      );

      print(
        '📏 TrackingBloc: Distance to destination: ${distance.toStringAsFixed(2)}m',
      );

      // Check if inside trigger radius
      final isInsideRadius = distance <= reminder.triggerDistanceMeters;
      final justEntered =
          isInsideRadius && !_wasInsideRadius && !_alarmTriggered;

      if (justEntered) {
        print(
          '🚨 TrackingBloc: Just entered trigger radius! Triggering alarm...',
        );
        await _triggerArrivalAlarm(reminder, distance);
      }

      _wasInsideRadius = isInsideRadius;
      _lastDistance = distance;

      // Send location update to ETABloc
      etaBloc.add(
        ETALocationUpdated(
          currentLat: location.latitude,
          currentLon: location.longitude,
          speed: location.speed ?? 0.0,
          distance: distance,
        ),
      );

      emit(
        state.copyWith(
          current: location,
          distanceMeters: distance,
          insideRadius: isInsideRadius,
          status: TrackingStatus.tracking,
          isLive: true,
        ),
      );
    } else {
      print('⚠️ TrackingBloc: No active reminder, location-only mode');

      emit(
        state.copyWith(
          current: location,
          status: TrackingStatus.tracking,
          isLive: true,
        ),
      );
    }
  }

  /// Adjusts tracking settings based on distance and movement
  Future<void> _onSettingsAdjusted(
    TrackingSettingsAdjusted event,
    Emitter<TrackingState> emit,
  ) async {
    final reminder = state.activeReminder;
    if (reminder == null) return;

    print(
      '⚙️ TrackingBloc: Adjusting settings - distanceFilter: ${event.distanceFilter}, accuracy: ${event.accuracy}',
    );

    await _locationSubscription?.cancel();

    await _startTrackingWithSettings(
      distanceFilter: event.distanceFilter,
      accuracy: event.accuracy,
      reminder: reminder,
    );
  }

  /// Handles location service being enabled
  Future<void> _onServiceEnabled(
    _TrackingServiceEnabled event,
    Emitter<TrackingState> emit,
  ) async {
    print('✅ TrackingBloc: Location service enabled');

    if (_isLocationOnlyMode) {
      await _startLiveLocationStream(emit);
    } else if (state.activeReminder != null) {
      await _startTrackingWithSettings(
        distanceFilter: 10,
        accuracy: LocationAccuracy.high,
        reminder: state.activeReminder!,
      );
    }
  }

  /// Handles location service being disabled
  Future<void> _onServiceDisabled(
    _TrackingServiceDisabled event,
    Emitter<TrackingState> emit,
  ) async {
    print('⚠️ TrackingBloc: Location service disabled');

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    emit(
      state.copyWith(
        isLive: false,
        status: TrackingStatus.tracking,
        errorMessage:
            'Location service is disabled. Turn it on to get live updates.',
        clearErrorMessage: false,
      ),
    );
  }

  // ==================== APP LIFECYCLE HANDLERS ====================

  Future<void> _onAppToBackground() async {
    if (state.activeReminder != null) {
      print('📱 TrackingBloc: Switching to background tracking');

      // Stop foreground location stream to save battery
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // Start foreground service (Android) or background task
      if (Platform.isAndroid) {
        await foregroundService.startForegroundService(state.activeReminder!);
      } else if (Platform.isIOS) {
        await backgroundService.startBackgroundTracking();
      }

      // Update state to show background mode
      emit(
        state.copyWith(
          isLive: false,
          isInBackground: true,
          status: TrackingStatus.tracking,
        ),
      );

      print('✅ TrackingBloc: Background tracking started');
    }
  }

  Future<void> _onAppToForeground() async {
    if (state.activeReminder != null) {
      print('📱 TrackingBloc: Switching to foreground tracking');

      // Stop background services
      await foregroundService.stopForegroundService();
      await backgroundService.stopBackgroundTracking();

      // Restart foreground location stream
      await _startTrackingWithSettings(
        distanceFilter: 10,
        accuracy: LocationAccuracy.high,
        reminder: state.activeReminder!,
      );

      emit(
        state.copyWith(
          isLive: true,
          isInBackground: false,
          status: TrackingStatus.tracking,
        ),
      );

      print('✅ TrackingBloc: Foreground tracking resumed');
    }
  }

  Future<void> _onAppClosed() async {
    print(
      '📱 TrackingBloc: App closed, ensuring background tracking continues',
    );

    if (state.activeReminder != null) {
      await backgroundService.saveActiveReminderForBackground(
        state.activeReminder,
      );
    }
  }

  // ==================== LOCATION STREAMING ====================

  /// Starts the live location stream
  Future<void> _startLiveLocationStream(Emitter<TrackingState> emit) async {
    print('📍 TrackingBloc: Starting live location stream...');

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        print('⚠️ TrackingBloc: Location service is disabled');
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
        (location) {
          print('📍 TrackingBloc: Location received from stream');
          add(_TrackingLocationUpdated(location));
        },
        onError: (error) {
          print('❌ TrackingBloc: Location stream error: $error');
          if (!isClosed) {
            add(const _TrackingServiceDisabled());
          }
        },
      );

      print('✅ TrackingBloc: Live location stream started');
    } catch (e) {
      print('❌ TrackingBloc: Error starting live location stream: $e');
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

  /// Starts tracking with specific settings
  Future<void> _startTrackingWithSettings({
    required double distanceFilter,
    required LocationAccuracy accuracy,
    required DestinationReminder reminder,
  }) async {
    print('📍 TrackingBloc: Starting tracking with settings...');
    print('   distanceFilter: $distanceFilter, accuracy: $accuracy');

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('   Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        print('⚠️ TrackingBloc: Location service is disabled!');
        return;
      }

      final stream = await watchPosition(
        WatchPositionParams(distanceFilter: distanceFilter, accuracy: accuracy),
      );

      await _locationSubscription?.cancel();

      _locationSubscription = stream.listen(
        (location) {
          print('📍 TrackingBloc: Location received from stream');
          add(_TrackingLocationUpdated(location));
        },
        onError: (error) {
          print('❌ TrackingBloc: Location stream error: $error');
          if (!isClosed) {
            add(const _TrackingServiceDisabled());
          }
        },
        onDone: () {
          print('⚠️ TrackingBloc: Location stream closed');
        },
      );

      print('✅ TrackingBloc: Location subscription set up successfully');
    } catch (e) {
      print('❌ TrackingBloc: Error in _startTrackingWithSettings: $e');
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
        print('✅ TrackingBloc: Location service enabled (from stream)');
        add(const _TrackingServiceEnabled());
      } else if (status == ServiceStatus.disabled) {
        print('⚠️ TrackingBloc: Location service disabled (from stream)');
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
    _adaptiveTimer?.cancel();

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
        print(
          '⚙️ TrackingBloc: Adjusting adaptive settings - distanceFilter: $newDistanceFilter',
        );
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

    if (!isMovingToward && currentDistance > 1000) {
      distanceFilter *= 2;
    }

    if (timeSinceLastUpdate > const Duration(minutes: 5) &&
        currentDistance > 1000) {
      distanceFilter = 2000;
      accuracy = LocationAccuracy.lowest;
    }

    return (distanceFilter, accuracy);
  }

  // ==================== DISTANCE & ALARM ====================

  /// Calculates distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Triggers arrival alarm when destination is reached
  Future<void> _triggerArrivalAlarm(
    DestinationReminder reminder,
    double distance,
  ) async {
    if (_alarmTriggered) {
      print('⚠️ TrackingBloc: Alarm already triggered, skipping');
      return;
    }

    _alarmTriggered = true;
    print('🚨 TrackingBloc: ARRIVAL TRIGGERED - ${reminder.label}');
    print('   Distance: ${distance.toStringAsFixed(2)}m');

    try {
      // Trigger ALARM (not notification)
      await alarmService.triggerArrivalAlarm(
        destinationName: reminder.label,
        distanceMeters: distance,
      );

      print('✅ TrackingBloc: Alarm triggered successfully');

      // Stop tracking after a short delay to ensure alarm is set
      await Future.delayed(const Duration(milliseconds: 500));
      add(const TrackingStopped());
    } catch (e) {
      print('❌ TrackingBloc: Error triggering alarm: $e');
      _alarmTriggered = false; // Reset flag on error
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
    _alarmTriggered = false; // ← Reset alarm flag
  }

  @override
  Future<void> close() async {
    print('🛑 TrackingBloc: Closing...');
    await foregroundService.stopForegroundService();
    await backgroundService.stopBackgroundTracking();
    await _cancelAllSubscriptions();
    return super.close();
  }
}
