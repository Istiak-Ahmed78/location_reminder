part of 'reminder_bloc.dart';

enum ReminderStatus { initial, loading, ready, failure }

class ReminderState extends Equatable {
  final ReminderStatus status;
  final DestinationReminder? active;
  final String? errorMessage;

  const ReminderState({required this.status, this.active, this.errorMessage});

  const ReminderState.initial()
    : status = ReminderStatus.initial,
      active = null,
      errorMessage = null;

  ReminderState copyWith({
    ReminderStatus? status,
    DestinationReminder? active,
    String? errorMessage,
  }) {
    return ReminderState(
      status: status ?? this.status,
      active: active,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, active, errorMessage];
}
