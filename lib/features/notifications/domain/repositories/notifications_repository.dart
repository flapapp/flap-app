import 'package:flap_app/models/notification.dart';

/// In-app notifications + push queue (`public.notifications`, `push_notification_queue`).
abstract class NotificationsRepository {
  Stream<List<AppNotification>> watchNotificationsForUser(String userId);

  Stream<int> watchUnreadCountForUser(String userId);

  /// Persists notification and enqueues FCM worker row; returns new row id.
  Future<String> sendNotification(AppNotification notification);

  Future<void> sendBulkNotifications(List<AppNotification> notifications);

  Future<bool> markAsRead(String notificationId);

  Future<bool> markAllAsRead(String userId);

  Future<bool> deleteNotification(String notificationId);

  Future<Map<String, int>> getNotificationStats(String userId);

  Future<bool> clearOldNotifications(String userId, {Duration maxAge});
}
