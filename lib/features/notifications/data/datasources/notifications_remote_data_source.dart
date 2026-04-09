import 'package:flap_app/models/notification.dart';

abstract class NotificationsRemoteDataSource {
  Stream<List<AppNotification>> watchNotificationsForUser(String userId);

  Stream<int> watchUnreadCountForUser(String userId);

  Future<String> insertNotification(AppNotification notification);

  Future<void> enqueuePush({
    required String targetUserId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  });

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead(String userId);

  Future<void> deleteNotification(String notificationId);

  Future<List<AppNotification>> fetchAllForUser(String userId);

  Future<void> deleteOlderThan(String userId, DateTime before);
}
