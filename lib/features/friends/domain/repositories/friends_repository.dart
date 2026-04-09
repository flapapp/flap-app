import 'package:flap_app/models/friend_request.dart';

/// Friends graph + requests (Supabase `user_friends`, `friend_requests`).
abstract class FriendsRepository {
  Stream<List<FriendRequest>> watchIncomingFriendRequests();

  Stream<List<FriendRequest>> watchOutgoingFriendRequests();

  Future<List<Friend>> getUserFriends(String userId);

  Future<bool> sendFriendRequest(String toUserId, {String? message});

  Future<void> respondToFriendRequest(String requestId, bool accept);

  Future<void> cancelFriendRequest(String requestId);

  Future<void> removeFriend(String friendUserId);

  Future<bool> areUsersFriends(String userId1, String userId2);

  Future<int> getPendingRequestsCount();

  Future<List<Map<String, dynamic>>> searchUsers(String query);
}
