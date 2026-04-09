import 'package:flap_app/models/notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notifications_remote_data_source.dart';

class SupabaseNotificationsRemoteDataSource
    implements NotificationsRemoteDataSource {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  Stream<List<AppNotification>> watchNotificationsForUser(String userId) {
    return _c
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((raw) {
      final rows = (raw as List).cast<Map>();
      final list = rows
          .map((e) => AppNotification.fromSupabaseRow(
                Map<String, dynamic>.from(e),
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (list.length > 50) {
        return list.sublist(0, 50);
      }
      return list;
    });
  }

  @override
  Stream<int> watchUnreadCountForUser(String userId) {
    return watchNotificationsForUser(userId).map(
      (list) => list.where((n) => !n.isRead).length,
    );
  }

  @override
  Future<String> insertNotification(AppNotification notification) async {
    final row = notification.toSupabaseInsertRow();
    final res =
        await _c.from('notifications').insert(row).select('id').single();
    return res['id'].toString();
  }

  @override
  Future<void> enqueuePush({
    required String targetUserId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await _c.from('push_notification_queue').insert({
      'target_user_id': targetUserId,
      'title': title,
      'body': body,
      'data': data,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _c.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notificationId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    await _c.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId).eq('is_read', false);
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _c.from('notifications').delete().eq('id', notificationId);
  }

  @override
  Future<List<AppNotification>> fetchAllForUser(String userId) async {
    final rows = await _c
        .from('notifications')
        .select()
        .eq('user_id', userId);
    final list = (rows as List)
        .map((e) =>
            AppNotification.fromSupabaseRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }

  @override
  Future<void> deleteOlderThan(String userId, DateTime before) async {
    await _c
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .lt('created_at', before.toUtc().toIso8601String());
  }
}
