part of 'notification_bloc.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class NotificationStarted extends NotificationEvent {
  const NotificationStarted();
}

class NotificationUpdated extends NotificationEvent {
  const NotificationUpdated(this.notifications);

  final List<AppNotification> notifications;

  @override
  List<Object?> get props => [notifications];
}

class NotificationMarkReadRequested extends NotificationEvent {
  const NotificationMarkReadRequested(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

class NotificationMarkAllReadRequested extends NotificationEvent {
  const NotificationMarkAllReadRequested();
}

class NotificationDeleteRequested extends NotificationEvent {
  const NotificationDeleteRequested(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}
