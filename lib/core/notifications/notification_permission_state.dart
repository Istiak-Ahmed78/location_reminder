part of 'notification_permission_bloc.dart';

enum NotificationPermissionStatus {
  initial,
  requesting,
  granted,
  denied,
  permanentlyDenied,
}

class NotificationPermissionState extends Equatable {
  final NotificationPermissionStatus status;
  final String? errorMessage;

  const NotificationPermissionState({required this.status, this.errorMessage});

  const NotificationPermissionState.initial()
    : status = NotificationPermissionStatus.initial,
      errorMessage = null;

  NotificationPermissionState copyWith({
    NotificationPermissionStatus? status,
    String? errorMessage,
  }) {
    return NotificationPermissionState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
