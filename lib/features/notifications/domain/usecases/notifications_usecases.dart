import 'package:flap_app/models/notification.dart';

import '../repositories/notifications_repository.dart';

/// Application API for the notifications feature (streams + writes).
class NotificationsUseCases {
  NotificationsUseCases(this._repository);

  final NotificationsRepository _repository;

  Stream<List<AppNotification>> watchForUser(String userId) =>
      _repository.watchNotificationsForUser(userId);

  Future<void> markAsRead(String notificationId) =>
      _repository.markAsRead(notificationId);

  Future<void> markAllAsRead(String userId) =>
      _repository.markAllAsRead(userId);

  Future<void> delete(String notificationId) =>
      _repository.deleteNotification(notificationId);
}
