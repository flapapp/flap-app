import 'package:flap_app/models/notification.dart';

import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._remote);

  final NotificationsRemoteDataSource _remote;

  @override
  Stream<List<AppNotification>> watchNotificationsForUser(String userId) =>
      _remote.watchNotificationsForUser(userId);

  @override
  Stream<int> watchUnreadCountForUser(String userId) =>
      _remote.watchUnreadCountForUser(userId);

  Future<void> _enqueuePushFor(AppNotification n) {
    final payload = Map<String, dynamic>.from(n.data);
    payload.putIfAbsent(
      'type',
      () => n.type.toString().split('.').last,
    );
    return _remote.enqueuePush(
      targetUserId: n.userId,
      title: n.title,
      body: n.message,
      data: payload,
    );
  }

  @override
  Future<String> sendNotification(AppNotification notification) async {
    final id = await _remote.insertNotification(notification);
    await _enqueuePushFor(notification);
    return id;
  }

  @override
  Future<void> sendBulkNotifications(List<AppNotification> notifications) async {
    for (final n in notifications) {
      await _remote.insertNotification(n);
      await _enqueuePushFor(n);
    }
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _remote.markAsRead(notificationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> markAllAsRead(String userId) async {
    try {
      await _remote.markAllAsRead(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _remote.deleteNotification(notificationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final list = await _remote.fetchAllForUser(userId);
      final stats = <String, int>{};
      for (final n in list) {
        final typeKey = n.type.toString().split('.').last;
        stats[typeKey] = (stats[typeKey] ?? 0) + 1;
      }
      return stats;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<bool> clearOldNotifications(String userId, {Duration maxAge = const Duration(days: 30)}) async {
    try {
      final before = DateTime.now().subtract(maxAge);
      await _remote.deleteOlderThan(userId, before);
      return true;
    } catch (_) {
      return false;
    }
  }
}
