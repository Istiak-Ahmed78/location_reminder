import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:permission_handler/permission_handler.dart';

part 'notification_permission_event.dart';
part 'notification_permission_state.dart';

class NotificationPermissionBloc
    extends Bloc<NotificationPermissionEvent, NotificationPermissionState> {
  NotificationPermissionBloc()
    : super(const NotificationPermissionState.initial()) {
    on<NotificationPermissionChecked>(_onChecked);
    on<NotificationPermissionRequested>(_onRequested);
  }

  Future<void> _onChecked(
    NotificationPermissionChecked event,
    Emitter<NotificationPermissionState> emit,
  ) async {
    // iOS doesn't need POST_NOTIFICATIONS in the same way; Android < 13 doesn't either
    if (!Platform.isAndroid) {
      emit(state.copyWith(status: NotificationPermissionStatus.granted));
      return;
    }

    final status = await Permission.notification.status;
    emit(state.copyWith(status: _map(status), errorMessage: null));
  }

  Future<void> _onRequested(
    NotificationPermissionRequested event,
    Emitter<NotificationPermissionState> emit,
  ) async {
    if (!Platform.isAndroid) {
      emit(state.copyWith(status: NotificationPermissionStatus.granted));
      return;
    }

    emit(state.copyWith(status: NotificationPermissionStatus.requesting));

    final res = await Permission.notification.request();
    emit(state.copyWith(status: _map(res), errorMessage: null));
  }

  NotificationPermissionStatus _map(PermissionStatus s) {
    if (s.isGranted) return NotificationPermissionStatus.granted;
    if (s.isPermanentlyDenied) {
      return NotificationPermissionStatus.permanentlyDenied;
    }
    if (s.isDenied) return NotificationPermissionStatus.denied;
    if (s.isRestricted) return NotificationPermissionStatus.denied;
    if (s.isLimited) return NotificationPermissionStatus.denied;
    return NotificationPermissionStatus.denied;
  }
}
