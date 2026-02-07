import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/destination_reminder.dart';
import '../../domain/usecases/clear_active_reminder.dart';
import '../../domain/usecases/get_active_reminder.dart';
import '../../domain/usecases/save_active_reminder.dart';

part 'reminder_event.dart';
part 'reminder_state.dart';

class ReminderBloc extends Bloc<ReminderEvent, ReminderState> {
  final SaveActiveReminder saveActiveReminder;
  final GetActiveReminder getActiveReminder;
  final ClearActiveReminder clearActiveReminder;

  ReminderBloc({
    required this.saveActiveReminder,
    required this.getActiveReminder,
    required this.clearActiveReminder,
  }) : super(const ReminderState.initial()) {
    on<ReminderLoaded>(_onLoaded);
    on<ReminderSaved>(_onSaved);
    on<ReminderCleared>(_onCleared);
  }

  Future<void> _onLoaded(
    ReminderLoaded event,
    Emitter<ReminderState> emit,
  ) async {
    emit(state.copyWith(status: ReminderStatus.loading, errorMessage: null));
    try {
      final reminder = await getActiveReminder(const NoParams());
      emit(state.copyWith(status: ReminderStatus.ready, active: reminder));
    } catch (e) {
      emit(
        state.copyWith(
          status: ReminderStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSaved(
    ReminderSaved event,
    Emitter<ReminderState> emit,
  ) async {
    emit(state.copyWith(status: ReminderStatus.loading, errorMessage: null));
    try {
      await saveActiveReminder(event.reminder);
      emit(
        state.copyWith(status: ReminderStatus.ready, active: event.reminder),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReminderStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCleared(
    ReminderCleared event,
    Emitter<ReminderState> emit,
  ) async {
    emit(state.copyWith(status: ReminderStatus.loading, clearError: true));
    try {
      await clearActiveReminder(const NoParams());
      emit(
        state.copyWith(
          status: ReminderStatus.ready,
          clearActive: true,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReminderStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
