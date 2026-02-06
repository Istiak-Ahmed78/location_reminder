import '../../../../core/usecase/usecase.dart';
import '../repositories/reminder_repository.dart';

class ClearActiveReminder extends UseCase<void, NoParams> {
  final ReminderRepository repository;
  ClearActiveReminder(this.repository);

  @override
  Future<void> call(NoParams params) async {
    await repository.clearActiveReminder();
  }
}
