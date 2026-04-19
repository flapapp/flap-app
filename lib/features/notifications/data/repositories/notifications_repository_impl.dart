import '../models/notification.dart';
import '../services/notification_service.dart';
import '../../domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._service);

  final NotificationService _service;

  @override
  Stream<List<AppNotification>> getUserNotifications() {
    return _service.getUserNotifications();
  }

  @override
  Stream<int> getUnreadCount() {
    return _service.getUnreadCount();
  }

  @override
  Future<bool> markAsRead(String notificationId) {
    return _service.markAsRead(notificationId);
  }

  @override
  Future<bool> markAllAsRead() {
    return _service.markAllAsRead();
  }

  @override
  Future<bool> deleteNotification(String notificationId) {
    return _service.deleteNotification(notificationId);
  }
}
