// lib/core/notifications/local_notifications_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin;

  LocalNotificationsService(this._plugin);

  /// Call once at app startup
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    // ✅ Your plugin requires `settings:`
    await _plugin.initialize(settings: initSettings);
  }

  Future<void> showArrivalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'arrival_channel',
      'Arrival Alerts',
      channelDescription: 'Alerts when you arrive near your destination',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ✅ v17+ signature uses named params like these :contentReference[oaicite:1]{index=1}
    await _plugin.show(
      id: 1001,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
