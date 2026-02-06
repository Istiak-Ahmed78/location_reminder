import '../../../../core/usecase/usecase.dart';
import '../entities/destination_reminder.dart';
import '../repositories/reminder_repository.dart';

class SaveActiveReminder extends UseCase<void, DestinationReminder> {
  final ReminderRepository repository;
  SaveActiveReminder(this.repository);

  @override
  Future<void> call(DestinationReminder params) async {
    await repository.saveActiveReminder(params);
  }
}
