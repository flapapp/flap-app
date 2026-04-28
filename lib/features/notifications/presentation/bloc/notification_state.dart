part of 'notification_bloc.dart';

sealed class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

class NotificationLoaded extends NotificationState {
  const NotificationLoaded(this.notifications);

  final List<AppNotification> notifications;

  @override
  List<Object?> get props => [notifications];
}

class NotificationError extends NotificationState {
  const NotificationError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
