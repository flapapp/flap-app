import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/models/friend_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/friends_repository.dart';
import '../datasources/friends_remote_data_source.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this._remote, this._profileRepo);

  final FriendsRemoteDataSource _remote;
  final UserProfileRepository _profileRepo;
  final NotificationService _notifications = NotificationService();

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  @override
  Stream<List<FriendRequest>> watchIncomingFriendRequests() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _remote.watchFriendRequestRowsForUser(uid).map((rows) {
      final list = rows
          .map(FriendRequest.fromSupabaseRow)
          .where(
            (r) => r.toUserId == uid && r.status == FriendRequestStatus.pending,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<List<FriendRequest>> watchOutgoingFriendRequests() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _remote.watchFriendRequestRowsForUser(uid).map((rows) {
      final list = rows
          .map(FriendRequest.fromSupabaseRow)
          .where(
            (r) => r.fromUserId == uid && r.status == FriendRequestStatus.pending,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<List<Friend>> getUserFriends(String userId) async {
    final rows = await _remote.fetchFriendsWithProfiles(userId);
    final out = <Friend>[];
    for (final row in rows) {
      final prof = row['profile'] as Map<String, dynamic>?;
      if (prof == null) continue;
      final since = FriendRequest.parseRowTimestamp(row['friends_since']);
      out.add(Friend.fromProfileRow(profile: prof, friendsSince: since));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    final requestId = await _remote.rpcSendFriendRequest(toUserId, message: message);
    final meId = AppAuthContext.userId;
    if (meId == null) return true;
    final me = await _profileRepo.loadProfile(meId);
    final name = me?.resolveDisplayName().isNotEmpty == true
        ? me!.resolveDisplayName()
        : 'Friend';
    await _notifications.sendFriendRequestNotification(
      toUserId: toUserId,
      fromUserName: name,
      requestId: requestId,
    );
    return true;
  }

  @override
  Future<void> respondToFriendRequest(String requestId, bool accept) async {
    Map<String, dynamic>? before;
    try {
      before = await _remote.fetchFriendRequestById(requestId);
    } catch (_) {}
    await _remote.rpcRespondFriendRequest(requestId, accept);
    if (!accept) return;
    final fromId = before?['from_user_id']?.toString();
    if (fromId == null || fromId.isEmpty) return;
    final meId = AppAuthContext.userId;
    if (meId == null) return;
    final me = await _profileRepo.loadProfile(meId);
    final name = me?.resolveDisplayName().isNotEmpty == true
        ? me!.resolveDisplayName()
        : 'Friend';
    await _notifications.sendFriendAcceptedNotification(
      toUserId: fromId,
      friendName: name,
    );
  }

  @override
  Future<void> cancelFriendRequest(String requestId) =>
      _remote.rpcCancelFriendRequest(requestId);

  @override
  Future<void> removeFriend(String friendUserId) =>
      _remote.rpcRemoveFriendship(friendUserId);

  @override
  Future<bool> areUsersFriends(String userId1, String userId2) =>
      _remote.fetchAreFriends(userId1, userId2);

  @override
  Future<int> getPendingRequestsCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    return _remote.fetchPendingIncomingCount(uid);
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return [];
    final q = query.trim();
    if (q.length < 2) return [];
    final queryLower = q.toLowerCase();

    final rows = await _remote.fetchProfilesForSearch(
      excludeUserId: currentUser.id,
      limit: 300,
    );

    final users = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final userData = Map<String, dynamic>.from(raw);
      final id = userData['id']?.toString() ?? '';
      if (id.isEmpty || id == currentUser.id) continue;

      final name = (userData['name'] ?? '').toString().toLowerCase();
      final displayName = (userData['display_name'] ?? '').toString().toLowerCase();
      final email = (userData['email'] ?? '').toString().toLowerCase();
      final surname = (userData['surname'] ?? '').toString().toLowerCase();
      final searchFields = <String>[
        name,
        displayName,
        email,
        surname,
        '$name $surname'.trim(),
      ];
      var isMatch = false;
      for (final field in searchFields) {
        if (field.isNotEmpty &&
            (field.startsWith(queryLower) || field.contains(queryLower))) {
          isMatch = true;
          break;
        }
      }
      if (!isMatch) continue;

      userData['displayName'] = userData['display_name'];
      userData['name'] = userData['name'] ?? userData['display_name'];
      userData['avatarUrl'] = userData['avatar_url'];
      users.add(userData);
    }

    users.sort((a, b) {
      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      final aExact = aName == queryLower ? 1 : 0;
      final bExact = bName == queryLower ? 1 : 0;
      if (aExact != bExact) return bExact - aExact;
      final aStarts = aName.startsWith(queryLower) ? 1 : 0;
      final bStarts = bName.startsWith(queryLower) ? 1 : 0;
      if (aStarts != bStarts) return bStarts - aStarts;
      return aName.compareTo(bName);
    });

    return users.take(10).toList();
  }
}
