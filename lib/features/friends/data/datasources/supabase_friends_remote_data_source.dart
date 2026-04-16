import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/friend_failure.dart';
import 'friends_remote_data_source.dart';

class SupabaseFriendsRemoteDataSource implements FriendsRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<List<Map<String, dynamic>>> watchFriendRequestRowsForUser(String userId) {
    return _client
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .map((raw) {
          final rows = (raw as List).cast<Map>();
          return rows
              .map((e) => Map<String, dynamic>.from(e))
              .where((row) {
                final from = row['from_user_id']?.toString() ?? '';
                final to = row['to_user_id']?.toString() ?? '';
                return from == userId || to == userId;
              })
              .toList();
        });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFriendsWithProfiles(String userId) async {
    final edges = await _client
        .from('friendships')
        .select('friend_id, created_at')
        .eq('user_id', userId);
    final list = (edges as List).cast<Map>();
    if (list.isEmpty) return [];

    final friendIds = list
        .map((e) => e['friend_id'].toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final profById = <String, Map<String, dynamic>>{};
    if (friendIds.isNotEmpty) {
      final profiles = await _client
          .from('user_profiles')
          .select(
            'id, display_name, first_name, last_name, email, avatar_url, rating, city, position',
          )
          .inFilter('id', friendIds);
      for (final p in (profiles as List).cast<Map>()) {
        profById[p['id'].toString()] = Map<String, dynamic>.from(p);
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      final fid = e['friend_id']?.toString() ?? '';
      final prof = profById[fid];
      if (prof == null) continue;
      out.add({
        'profile': prof,
        'friends_since': e['created_at'],
      });
    }
    return out;
  }

  @override
  Future<String> rpcSendFriendRequest(String toUserId, {String? message}) async {
    try {
      final res = await _client.rpc<dynamic>(
        'send_friend_request',
        params: <String, dynamic>{
          'p_to_user_id': toUserId,
          'p_message': message,
        },
      );
      return res.toString();
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcRespondFriendRequest(String requestId, bool accept) async {
    try {
      await _client.rpc<void>(
        'respond_friend_request',
        params: <String, dynamic>{
          'p_request_id': requestId,
          'p_accept': accept,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcCancelFriendRequest(String requestId) async {
    try {
      await _client.rpc<void>(
        'cancel_friend_request',
        params: <String, dynamic>{'p_request_id': requestId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcRemoveFriendship(String friendUserId) async {
    try {
      await _client.rpc<void>(
        'remove_friendship',
        params: <String, dynamic>{'p_friend_id': friendUserId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<bool> fetchAreFriends(String userId1, String userId2) async {
    final row = await _client
        .from('friendships')
        .select('user_id')
        .eq('user_id', userId1)
        .eq('friend_id', userId2)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<int> fetchPendingIncomingCount(String userId) async {
    final rows = await _client
        .from('friend_requests')
        .select('id')
        .eq('to_user_id', userId)
        .eq('status', 'pending');
    return (rows as List).length;
  }

  @override
  Future<Map<String, dynamic>?> fetchFriendRequestById(String requestId) {
    return _client.from('friend_requests').select().eq('id', requestId).maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProfilesForSearch({
    required String excludeUserId,
    int limit = 300,
  }) async {
    final rows = await _client
        .from('user_profiles')
        .select(
          'id, display_name, first_name, last_name, email, city, avatar_url, rating, position',
        )
        .neq('id', excludeUserId)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  FriendFailure _mapPostgrest(PostgrestException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('not_authenticated')) {
      return const FriendFailure(code: 'not-authenticated', message: 'Not signed in.');
    }
    if (msg.contains('cannot_friend_self')) {
      return const FriendFailure(code: 'self', message: 'Cannot add yourself.');
    }
    if (msg.contains('already_friends')) {
      return const FriendFailure(code: 'already-friends', message: 'Already friends.');
    }
    if (msg.contains('pending_request_exists')) {
      return const FriendFailure(code: 'duplicate', message: 'Invitation already sent.');
    }
    if (msg.contains('target_not_found') || msg.contains('sender_not_found')) {
      return const FriendFailure(code: 'not-found', message: 'User not found.');
    }
    if (msg.contains('request_not_found')) {
      return const FriendFailure(code: 'not-found', message: 'Request not found.');
    }
    if (msg.contains('not_recipient')) {
      return const FriendFailure(code: 'forbidden', message: 'Not your invitation.');
    }
    if (msg.contains('not_sender')) {
      return const FriendFailure(code: 'forbidden', message: 'Not your outgoing request.');
    }
    if (msg.contains('not_pending')) {
      return const FriendFailure(code: 'not-pending', message: 'Request already handled.');
    }
    if (msg.contains('not_friends')) {
      return const FriendFailure(code: 'not-friends', message: 'Not friends with this user.');
    }
    return FriendFailure(code: e.code ?? 'friend-error', message: e.message);
  }
}
