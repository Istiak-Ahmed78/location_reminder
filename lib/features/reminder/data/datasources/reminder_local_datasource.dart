import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/destination_reminder.dart';
import '../models/destination_reminder_model.dart';

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
    try {
      final model = DestinationReminderModel.fromEntity(reminder);
      final jsonString = model.toJsonString();
      await prefs.setString(_key, jsonString);
    } catch (e) {
      throw CacheException('Failed to save reminder: $e');
    }
  }

  @override
  Future<DestinationReminder?> getActiveReminder() async {
    try {
      final jsonString = prefs.getString(_key);
      if (jsonString == null) return null;

      return DestinationReminderModel.fromJsonString(jsonString);
    } catch (e) {
      throw CacheException('Failed to get reminder: $e');
    }
  }

  @override
  Future<void> clearActiveReminder() async {
    try {
      await prefs.remove(_key);
    } catch (e) {
      throw CacheException('Failed to clear reminder: $e');
    }
  }
}
