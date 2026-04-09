import 'package:equatable/equatable.dart';
import 'package:flap_app/models/notification.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

class NotificationsStarted extends NotificationsEvent {
  const NotificationsStarted();
}

class NotificationsListUpdated extends NotificationsEvent {
  const NotificationsListUpdated(this.items);

  final List<AppNotification> items;

  @override
  List<Object?> get props => [items];
}

class NotificationMarkReadRequested extends NotificationsEvent {
  const NotificationMarkReadRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class NotificationDeleteRequested extends NotificationsEvent {
  const NotificationDeleteRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class NotificationsMarkAllReadRequested extends NotificationsEvent {
  const NotificationsMarkAllReadRequested();
}
