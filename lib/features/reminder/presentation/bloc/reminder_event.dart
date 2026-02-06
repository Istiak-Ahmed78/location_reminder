part of 'reminder_bloc.dart';

abstract class ReminderEvent extends Equatable {
  const ReminderEvent();

  @override
  List<Object?> get props => [];
}

class ReminderLoaded extends ReminderEvent {
  const ReminderLoaded();
}

class ReminderSaved extends ReminderEvent {
  final DestinationReminder reminder;
  const ReminderSaved(this.reminder);

  @override
  List<Object?> get props => [reminder];
}

class ReminderCleared extends ReminderEvent {
  const ReminderCleared();
}
