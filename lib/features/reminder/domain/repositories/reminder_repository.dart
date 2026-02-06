import '../entities/destination_reminder.dart';

abstract class ReminderRepository {
  Future<void> saveActiveReminder(DestinationReminder reminder);
  Future<DestinationReminder?> getActiveReminder();
  Future<void> clearActiveReminder();
}
