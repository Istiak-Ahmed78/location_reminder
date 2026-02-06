import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/destination_reminder.dart';

abstract class ReminderLocalDataSource {
  Future<void> saveActiveReminder(DestinationReminder reminder);
  Future<DestinationReminder?> getActiveReminder();
  Future<void> clearActiveReminder();
}

class ReminderLocalDataSourceImpl implements ReminderLocalDataSource {
  static const _key = 'active_reminder';

  final SharedPreferences prefs;
  ReminderLocalDataSourceImpl(this.prefs);

  @override
  Future<void> saveActiveReminder(DestinationReminder reminder) async {
    final map = {
      'label': reminder.label,
      'lat': reminder.latitude,
      'lng': reminder.longitude,
      'radius': reminder.radiusMeters,
    };
    await prefs.setString(_key, jsonEncode(map));
  }

  @override
  Future<DestinationReminder?> getActiveReminder() async {
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    return DestinationReminder(
      label: (map['label'] as String?) ?? 'Destination',
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      radiusMeters: (map['radius'] as num).toDouble(),
    );
  }

  @override
  Future<void> clearActiveReminder() async {
    await prefs.remove(_key);
  }
}
