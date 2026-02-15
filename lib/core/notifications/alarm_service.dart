import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';

class AlarmService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  AlarmService(this._notificationsPlugin);

  /// Initialize alarm system
  Future<void> init() async {
    await Alarm.init();
  }

  Future<void> triggerArrivalAlarm({
    required String destinationName,
    required double distanceMeters,
  }) async {
    print('🚨 AlarmService: Triggering arrival alarm for $destinationName');

    final alarmSettings = AlarmSettings(
      id: 999,
      dateTime: DateTime.now(),
      // ✅ FIX: Use null to use system default alarm sound
      assetAudioPath: 'assets/ring.mp3',
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      volumeSettings: const VolumeSettings.fixed(volume: 1.0),

      notificationSettings: NotificationSettings(
        title: '🚨 Arrived at $destinationName!',
        body:
            'You are ${distanceMeters.toStringAsFixed(0)}m from your destination',
        stopButton: 'Stop Alarm',
        icon: 'notification_icon',
      ),
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      print('✅ AlarmService: Alarm set successfully');
    } catch (e) {
      print('❌ AlarmService: Failed to set alarm: $e');
      rethrow;
    }
  }

  /// Stop the alarm
  Future<void> stopAlarm() async {
    await Alarm.stop(999);
  }

  /// Show high-priority notification
  Future<void> _showHighPriorityNotification({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'arrival_alarm_channel',
      'Arrival Alarms',
      channelDescription: 'Loud alarms when you arrive at destination',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        'alarm',
      ), // assets/raw/alarm.mp3
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        1000,
        500,
        1000,
      ]), // Vibrate pattern
      fullScreenIntent: true, // Show even when locked
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true, // Can't be dismissed easily
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      sound: 'alarm.aiff', // iOS sound file
      interruptionLevel: InterruptionLevel.critical, // Bypass Do Not Disturb
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: 999,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
