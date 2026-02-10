import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_reminder/features/reminder/domain/entities/destination_reminder.dart';

/// Foreground service for continuous tracking when app is in background
class ForegroundLocationService {
  static const String _tag = 'ForegroundLocationService';

  bool _isRunning = false;
  StreamSubscription<Position>? _positionSubscription;
  DestinationReminder? _activeReminder;

  /// Start foreground service with continuous tracking
  Future<void> startForegroundService(DestinationReminder reminder) async {
    if (_isRunning) {
      await stopForegroundService();
    }

    _activeReminder = reminder;

    // Request permissions for foreground service
    await _requestPermissions();

    // Initialize the service
    await _initService();

    // Start the service
    await _startService(reminder);

    _isRunning = true;

    // Start location updates
    _startLocationUpdates();

    print('$_tag: Foreground service started');
  }

  /// Stop foreground service
  Future<void> stopForegroundService() async {
    await _positionSubscription?.cancel();
    await FlutterForegroundTask.stopService();

    _isRunning = false;
    _activeReminder = null;

    print('$_tag: Foreground service stopped');
  }

  /// Request permissions for foreground service
  Future<void> _requestPermissions() async {
    // Check notification permission (Android 13+)
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    // Android: Ignore battery optimization
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  /// Initialize the foreground service
  Future<void> _initService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_location_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Tracks your location in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // Every 5 seconds
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service
  Future<void> _startService(DestinationReminder reminder) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 1001, // Unique service ID
        notificationTitle: 'Location Reminder',
        notificationText: 'Tracking your location to: ${reminder.label}',

        notificationButtons: [
          const NotificationButton(id: 'stop_button', text: 'Stop Tracking'),
        ],
        notificationInitialRoute: '/',
        callback: _startCallback,
      );
    }
  }

  /// Callback function for starting the task handler (must be top-level)
  @pragma('vm:entry-point')
  static void _startCallback() {
    FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
  }

  /// Start location updates
  void _startLocationUpdates() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 50, // 50 meters filter
            timeLimit: const Duration(seconds: 30),
          ),
        ).listen(
          (position) {
            if (_activeReminder != null) {
              _checkArrival(position);

              // Send location data to the foreground task handler
              final locationData = {
                'lat': position.latitude,
                'lon': position.longitude,
                'speed': position.speed,
                'timestamp': position.timestamp?.millisecondsSinceEpoch,
              };

              // Send to main isolate if needed
              // FlutterForegroundTask.sendDataToMain(locationData);
            }
          },
          onError: (error) {
            print('$_tag: Location stream error: $error');
          },
        );
  }

  /// Check if arrived at destination
  void _checkArrival(Position position) {
    if (_activeReminder == null) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _activeReminder!.latitude,
      _activeReminder!.longitude,
    );

    print(
      '$_tag: Foreground check - Distance: ${distance.toStringAsFixed(1)}m',
    );

    if (distance <= _activeReminder!.triggerDistanceMeters) {
      _showArrivalNotification(distance);
      stopForegroundService();
    }
  }

  /// Show notification
  void _showArrivalNotification(double distance) {
    FlutterForegroundTask.updateService(
      notificationTitle: '📍 Arrived!',
      notificationText:
          'You reached ${_activeReminder!.label} (${distance.toStringAsFixed(0)}m)',
    );
  }
}

/// Task handler for foreground service
class ForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('ForegroundTaskHandler: onStart - ${starter.name}');

    // You can store data that will be used in the task handler
    await FlutterForegroundTask.saveData(
      key: 'start_time',
      value: timestamp.toString(),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    print('ForegroundTaskHandler: onRepeatEvent - $timestamp');

    // Send data to main isolate if needed
    final data = {
      'event': 'repeat',
      'timestampMillis': timestamp.millisecondsSinceEpoch,
    };
    FlutterForegroundTask.sendDataToMain(data);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('ForegroundTaskHandler: onDestroy - timeout: $isTimeout');

    // Clean up stored data
    await FlutterForegroundTask.removeData(key: 'start_time');
  }

  @override
  void onReceiveData(Object data) {
    print('ForegroundTaskHandler: onReceiveData - $data');

    // Handle data sent from main isolate
    if (data is Map<String, dynamic>) {
      print('Received data from main: $data');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('ForegroundTaskHandler: Button pressed - $id');

    if (id == 'stop_button') {
      // Stop the service when stop button is pressed
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    print('ForegroundTaskHandler: Notification pressed');
    // Notification was tapped - app will be brought to foreground
  }

  @override
  void onNotificationDismissed() {
    print('ForegroundTaskHandler: Notification dismissed');
  }
}
