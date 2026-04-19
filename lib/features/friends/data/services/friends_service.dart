import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/core/supabase/coin_ledger.dart';
import 'package:flap_app/core/supabase/supabase_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/friend_request.dart';
import '../../../notifications/data/services/notification_service.dart';

class FriendsService {
  FriendsService();

  SupabaseClient get _client => Supabase.instance.client;

  final NotificationService _notificationService = NotificationService();

  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }
      if (toUserId == currentUser.id) {
        throw Exception('Неможливо додати себе у друзі');
      }

      final areFriends = await areUsersFriends(currentUser.id, toUserId);
      if (areFriends) {
        throw Exception('Ви вже друзі з цим користувачем');
      }

      final existing = await _client
          .from('friend_requests')
          .select('id')
          .eq('from_user_id', currentUser.id)
          .eq('to_user_id', toUserId)
          .eq('status', 'pending')
          .maybeSingle();
      if (existing != null) {
        throw Exception('Запрошення вже надіслано');
      }

      final fromProfile = await _client
          .from('profiles')
          .select('display_name,avatar_url,email')
          .eq('id', currentUser.id)
          .maybeSingle();
      final toProfile = await _client
          .from('profiles')
          .select('display_name,avatar_url,email')
          .eq('id', toUserId)
          .maybeSingle();

      if (fromProfile == null || toProfile == null) {
        throw Exception('Користувача не знайдено');
      }

      final fromName = _profileDisplayName(fromProfile);
      final toName = _profileDisplayName(toProfile);

      final inserted = await _client
          .from('friend_requests')
          .insert(<String, dynamic>{
            'from_user_id': currentUser.id,
            'to_user_id': toUserId,
            'status': 'pending',
            if (message != null && message.isNotEmpty) 'message': message,
          })
          .select('id')
          .single();

      final requestId = inserted['id'] as String;

      await _notificationService.sendFriendRequestNotification(
        toUserId: toUserId,
        fromUserName: fromName,
        requestId: requestId,
      );

      await insertCoinTransaction(
        _client,
        currentUser.id,
        'friend_request_sent',
        3,
        bilingual(
          'Надіслано запрошення в друзі: $toName',
          'Friend invite sent to: $toName',
        ),
      );

      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  String _profileDisplayName(Map<String, dynamic> p) {
    final dn = p['display_name'] as String?;
    if (dn != null && dn.isNotEmpty) return dn;
    final em = p['email'] as String?;
    if (em != null && em.contains('@')) return em.split('@').first;
    return tr('il_b512d97e7c');
  }

  Stream<List<FriendRequest>> getIncomingFriendRequests() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _client
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .eq('to_user_id', currentUser.id)
        .asyncMap((_) => _loadFriendRequests(incoming: true, userId: currentUser.id));
  }

  Stream<List<FriendRequest>> getOutgoingFriendRequests() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _client
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .eq('from_user_id', currentUser.id)
        .asyncMap((_) => _loadFriendRequests(incoming: false, userId: currentUser.id));
  }

  Future<List<FriendRequest>> _loadFriendRequests({
    required bool incoming,
    required String userId,
  }) async {
    final q = _client.from('friend_requests').select('''
          id,
          from_user_id,
          to_user_id,
          status,
          message,
          created_at,
          responded_at,
          from_user_profile:profiles!from_user_id(display_name,avatar_url,email),
          to_user_profile:profiles!to_user_id(display_name,avatar_url,email)
        ''');

    final rows = incoming
        ? await q
            .eq('to_user_id', userId)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
        : await q
            .eq('from_user_id', userId)
            .eq('status', 'pending')
            .order('created_at', ascending: false);

    final list = (rows as List<dynamic>)
        .map((r) => FriendRequest.fromSupabase(Map<String, dynamic>.from(r as Map)))
        .toList();
    return list;
  }

  Future<bool> respondToFriendRequest(String requestId, bool accept) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final row = await _client
          .from('friend_requests')
          .select('''
            id,
            from_user_id,
            to_user_id,
            status,
            message,
            created_at,
            responded_at,
            from_user_profile:profiles!from_user_id(display_name,avatar_url,email),
            to_user_profile:profiles!to_user_id(display_name,avatar_url,email)
          ''')
          .eq('id', requestId)
          .maybeSingle();

      if (row == null) {
        throw Exception('Запрошення не знайдено');
      }

      final request = FriendRequest.fromSupabase(Map<String, dynamic>.from(row));

      if (request.toUserId != currentUser.id) {
        throw Exception('Це не ваше запрошення');
      }

      if (!request.isPending) {
        throw Exception('Запрошення вже оброблено');
      }

      final newStatus = accept
          ? FriendRequestStatus.accepted
          : FriendRequestStatus.declined;

      await _client.from('friend_requests').update(<String, dynamic>{
        'status': newStatus.toString().split('.').last,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);

      if (accept) {
        await _client.from('friendships').insert([
          <String, dynamic>{
            'user_id': request.fromUserId,
            'friend_user_id': request.toUserId,
            'source_request_id': requestId,
          },
          <String, dynamic>{
            'user_id': request.toUserId,
            'friend_user_id': request.fromUserId,
            'source_request_id': requestId,
          },
        ]);

        await insertCoinTransaction(
          _client,
          request.toUserId,
          'friend_added',
          5,
          bilingual(
            'Новий друг: ${request.fromUserName}',
            'New friend: ${request.fromUserName}',
          ),
        );

        await _notificationService.sendFriendAcceptedNotification(
          toUserId: request.fromUserId,
          friendName: request.toUserName,
        );
      }

      return true;
    } catch (e) {
      print('Error responding to friend request: $e');
      rethrow;
    }
  }

  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final row = await _client
          .from('friend_requests')
          .select('from_user_id,status')
          .eq('id', requestId)
          .maybeSingle();

      if (row == null) {
        throw Exception('Запрошення не знайдено');
      }

      if (row['from_user_id'] != currentUser.id) {
        throw Exception('Це не ваше запрошення');
      }

      if (row['status'] != 'pending') {
        throw Exception('Запрошення вже оброблено');
      }

      await _client.from('friend_requests').update(<String, dynamic>{
        'status': FriendRequestStatus.cancelled.toString().split('.').last,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);

      return true;
    } catch (e) {
      print('Error cancelling friend request: $e');
      rethrow;
    }
  }

  Future<List<Friend>> getUserFriends(String userId) async {
    try {
      final rows = await _client
          .from('friendships')
          .select('friend_user_id,created_at')
          .eq('user_id', userId);

      final list = rows as List<dynamic>;
      if (list.isEmpty) return [];

      final friends = <Friend>[];

      for (final r in list) {
        final m = r as Map<String, dynamic>;
        final friendId = m['friend_user_id'] as String;
        final since = asDateTimeOrNull(m['created_at']) ?? DateTime.now();

        final friendDoc = await _client
            .from('profiles')
            .select(
                'id,display_name,email,avatar_url,city,position,last_seen_at')
            .eq('id', friendId)
            .maybeSingle();

        if (friendDoc == null) continue;

        final fd = Map<String, dynamic>.from(friendDoc);
        fd['id'] = friendId;
        friends.add(Friend.fromUserData(fd, since));
      }

      friends.sort((a, b) => a.name.compareTo(b.name));

      return friends;
    } catch (e) {
      print('Error getting user friends: $e');
      return [];
    }
  }

  Future<bool> areUsersFriends(String userId1, String userId2) async {
    try {
      final a = await _client
          .from('friendships')
          .select('id')
          .eq('user_id', userId1)
          .eq('friend_user_id', userId2)
          .maybeSingle();
      if (a != null) return true;
      final b = await _client
          .from('friendships')
          .select('id')
          .eq('user_id', userId2)
          .eq('friend_user_id', userId1)
          .maybeSingle();
      return b != null;
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  Future<bool> removeFriend(String friendId) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final areFriends = await areUsersFriends(currentUser.id, friendId);
      if (!areFriends) {
        throw Exception('Ви не друзі з цим користувачем');
      }

      await _client
          .from('friendships')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('friend_user_id', friendId);
      await _client
          .from('friendships')
          .delete()
          .eq('user_id', friendId)
          .eq('friend_user_id', currentUser.id);

      return true;
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return [];

      if (query.trim().length < 2) return [];

      final queryLower = query.toLowerCase().trim();

      final rows = await _client
          .from('profiles')
          .select(
              'id,display_name,email,first_name,last_name,nickname,avatar_url,city,position')
          .limit(200);

      final users = <Map<String, dynamic>>[];

      for (final raw in rows as List<dynamic>) {
        final userData = Map<String, dynamic>.from(raw as Map);
        final id = userData['id'] as String?;
        if (id == null || id == currentUser.id) continue;

        final dn = (userData['display_name'] ?? '').toString().toLowerCase();
        final em = (userData['email'] ?? '').toString().toLowerCase();
        final fn = (userData['first_name'] ?? '').toString().toLowerCase();
        final ln = (userData['last_name'] ?? '').toString().toLowerCase();
        final nn = (userData['nickname'] ?? '').toString().toLowerCase();

        final searchFields = <String>[
          dn,
          em,
          fn,
          ln,
          nn,
          '$fn $ln',
        ];

        var isMatch = false;
        for (final field in searchFields) {
          if (field.isNotEmpty &&
              (field.startsWith(queryLower) || field.contains(queryLower))) {
            isMatch = true;
            break;
          }
        }

        if (isMatch) {
          if (userData['display_name'] == null &&
              userData['nickname'] != null) {
            userData['display_name'] = userData['nickname'];
          }
          users.add(userData);
        }
      }

      users.sort((a, b) {
        final aName = (a['display_name'] ?? '').toString().toLowerCase();
        final bName = (b['display_name'] ?? '').toString().toLowerCase();

        final aExact = aName == queryLower ? 1 : 0;
        final bExact = bName == queryLower ? 1 : 0;

        if (aExact != bExact) return bExact - aExact;

        final aStartsWith = aName.startsWith(queryLower) ? 1 : 0;
        final bStartsWith = bName.startsWith(queryLower) ? 1 : 0;

        if (aStartsWith != bStartsWith) return bStartsWith - aStartsWith;

        return aName.compareTo(bName);
      });

      return users.take(10).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<int> getPendingRequestsCount() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return 0;

      final rows = await _client
          .from('friend_requests')
          .select('id')
          .eq('to_user_id', currentUser.id)
          .eq('status', 'pending');

      return (rows as List).length;
    } catch (e) {
      print('Error getting pending requests count: $e');
      return 0;
    }
  }
}
