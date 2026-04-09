import 'package:equatable/equatable.dart';
import 'package:flap_app/models/notification.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsReady extends NotificationsState {
  const NotificationsReady({
    required this.notifications,
    this.errorMessage,
  });

  final List<AppNotification> notifications;
  final String? errorMessage;

  NotificationsReady copyWith({
    List<AppNotification>? notifications,
    String? errorMessage,
  }) {
    return NotificationsReady(
      notifications: notifications ?? this.notifications,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [notifications, errorMessage];
}
