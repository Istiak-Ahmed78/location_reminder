import '../../../../core/usecase/usecase.dart';
import '../entities/destination_reminder.dart';
import '../repositories/reminder_repository.dart';

class GetActiveReminder extends UseCase<DestinationReminder?, NoParams> {
  final ReminderRepository repository;
  GetActiveReminder(this.repository);

  @override
  Future<DestinationReminder?> call(NoParams params) async {
    return await repository.getActiveReminder();
  }
}
