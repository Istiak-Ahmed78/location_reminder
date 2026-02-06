part of 'notification_permission_bloc.dart';

abstract class NotificationPermissionEvent extends Equatable {
  const NotificationPermissionEvent();

  @override
  List<Object?> get props => [];
}

class NotificationPermissionChecked extends NotificationPermissionEvent {
  const NotificationPermissionChecked();
}

class NotificationPermissionRequested extends NotificationPermissionEvent {
  const NotificationPermissionRequested();
}
