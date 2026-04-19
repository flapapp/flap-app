import '../../data/models/notification.dart';

/// In-app notification inbox and read-state (backed by [NotificationService]).
abstract class NotificationsRepository {
  Stream<List<AppNotification>> getUserNotifications();

  Stream<int> getUnreadCount();

  Future<bool> markAsRead(String notificationId);

  Future<bool> markAllAsRead();

  Future<bool> deleteNotification(String notificationId);
}
