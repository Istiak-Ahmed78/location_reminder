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

  /// Trigger loud alarm when destination is reached
  Future<void> triggerArrivalAlarm({
    required String destinationName,
    required double distanceMeters,
  }) async {
    // Create alarm settings
    final alarmSettings = AlarmSettings(
      id: 999,
      dateTime: DateTime.now(),
      assetAudioPath: 'assets/ring.mp3',
      loopAudio: true,
      vibrate: true,

      volumeSettings: const VolumeSettings.fixed(volume: 1.0),

      notificationSettings: NotificationSettings(
        title: '🚨 ARRIVED AT $destinationName',
        body: 'You are ${distanceMeters.toInt()}m from your destination!',
        stopButton: 'Stop Alarm',
        icon: 'notification_icon',
      ),

      androidFullScreenIntent: true,
    );

    await Alarm.set(alarmSettings: alarmSettings);

    // Also show notification for redundancy
    await _showHighPriorityNotification(
      title: '🚨 ARRIVED AT $destinationName',
      body: 'You are ${distanceMeters.toInt()}m from your destination!',
    );
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
