import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location_reminder/features/reminder/domain/entities/destination_reminder.dart';
import 'package:location_reminder/features/reminder/data/models/destination_reminder_model.dart';

class BackgroundLocationService {
  static const String _tag = 'BackgroundLocationService';
  static const String _workManagerTask = 'background_location_task';
  static const String _activeReminderKey = 'active_reminder_background';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  BackgroundLocationService(this._notificationsPlugin);

  /// Initialize background tracking
  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );

    // Configure notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'background_location_channel',
      'Background Location Updates',
      description: 'Location updates when app is in background',
      importance: Importance.low,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Start background tracking
  Future<void> startBackgroundTracking() async {
    print('$_tag: Starting background tracking');

    // Check if we have an active reminder
    final prefs = await SharedPreferences.getInstance();
    final reminderJson = prefs.getString(_activeReminderKey);

    if (reminderJson == null) {
      print('$_tag: No active reminder for background tracking');
      return;
    }

    // Parse reminder
    final reminder = DestinationReminderModel.fromJsonString(reminderJson);

    // Register periodic background task (Android)
    await Workmanager().registerPeriodicTask(
      _workManagerTask,
      _workManagerTask,
      frequency: const Duration(minutes: 15), // Check every 15 minutes
      initialDelay: const Duration(seconds: 10),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      // FIX: Changed to ExistingPeriodicWorkPolicy
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );

    print('$_tag: Background task registered for reminder: ${reminder.label}');
  }

  /// Stop background tracking
  Future<void> stopBackgroundTracking() async {
    print('$_tag: Stopping background tracking');
    await Workmanager().cancelByTag(_workManagerTask);
  }

  /// Save active reminder for background tracking
  Future<void> saveActiveReminderForBackground(
    DestinationReminder? reminder,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    if (reminder == null) {
      await prefs.remove(_activeReminderKey);
      await stopBackgroundTracking();
    } else {
      final model = DestinationReminderModel.fromEntity(reminder);
      await prefs.setString(_activeReminderKey, model.toJsonString());
      await startBackgroundTracking();
    }
  }

  /// Check if user has entered trigger radius (called from background)
  static Future<void> checkArrivalInBackground() async {
    print('$_tag: Checking arrival in background');

    try {
      // Get active reminder
      final prefs = await SharedPreferences.getInstance();
      final reminderJson = prefs.getString(_activeReminderKey);

      if (reminderJson == null) {
        return;
      }

      final reminder = DestinationReminderModel.fromJsonString(reminderJson);

      // Get current location with reduced accuracy for battery saving
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
      );

      // Calculate distance
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        reminder.latitude,
        reminder.longitude,
      );

      print(
        '$_tag: Background check - Distance: ${distance.toStringAsFixed(1)}m',
      );

      // Check if inside trigger radius
      if (distance <= reminder.triggerDistanceMeters) {
        await _showArrivalNotification(reminder, distance);

        // Clear reminder since we've arrived
        await prefs.remove(_activeReminderKey);
        await Workmanager().cancelByTag(_workManagerTask);
      }
    } catch (e) {
      print('$_tag: Error in background check: $e');
    }
  }

  /// Show arrival notification from background
  static Future<void> _showArrivalNotification(
    DestinationReminder reminder,
    double distance,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'arrival_background_channel',
          'Arrival Alerts',
          channelDescription: 'Notifications when you arrive in background',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
          autoCancel: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // FIX: Updated method signature
    await FlutterLocalNotificationsPlugin().show(
      id: 1002,
      title: '📍 Arrived at ${reminder.label}',
      body: 'You are ${distance.toStringAsFixed(0)}m from your destination!',
      notificationDetails: platformChannelSpecifics,
    );
  }
}

/// WorkManager callback (must be top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('WorkManager: Task $task started');

    if (task == 'background_location_task') {
      await BackgroundLocationService.checkArrivalInBackground();
    }

    return Future.value(true);
  });
}
