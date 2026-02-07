import '../../../../core/error/exceptions.dart';
import '../../domain/entities/destination_reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminder_local_datasource.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final ReminderLocalDataSource localDataSource;

  ReminderRepositoryImpl({required this.localDataSource});

  @override
  Future<void> saveActiveReminder(DestinationReminder reminder) async {
    try {
      await localDataSource.saveActiveReminder(reminder);
    } on CacheException catch (e) {
      throw Exception('Failed to save reminder: ${e.message}');
    }
  }

  @override
  Future<DestinationReminder?> getActiveReminder() async {
    try {
      return await localDataSource.getActiveReminder();
    } on CacheException catch (e) {
      throw Exception('Failed to get reminder: ${e.message}');
    }
  }

  @override
  Future<void> clearActiveReminder() async {
    try {
      await localDataSource.clearActiveReminder();
    } on CacheException catch (e) {
      throw Exception('Failed to clear reminder: ${e.message}');
    }
  }
}
