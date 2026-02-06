import '../../domain/entities/destination_reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminder_local_datasource.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final ReminderLocalDataSource local;
  ReminderRepositoryImpl(this.local);

  @override
  Future<void> saveActiveReminder(DestinationReminder reminder) {
    return local.saveActiveReminder(reminder);
  }

  @override
  Future<DestinationReminder?> getActiveReminder() {
    return local.getActiveReminder();
  }

  @override
  Future<void> clearActiveReminder() {
    return local.clearActiveReminder();
  }
}
