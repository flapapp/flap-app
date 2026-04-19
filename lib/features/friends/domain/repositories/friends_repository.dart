import '../../data/models/friend_request.dart';

/// Friend requests, search, and friend list operations (domain).
abstract class FriendsRepository {
  Future<bool> sendFriendRequest(String toUserId, {String? message});

  Stream<List<FriendRequest>> getIncomingFriendRequests();

  Stream<List<FriendRequest>> getOutgoingFriendRequests();

  Future<bool> respondToFriendRequest(String requestId, bool accept);

  Future<bool> cancelFriendRequest(String requestId);

  Future<List<Friend>> getUserFriends(String userId);

  Future<bool> areUsersFriends(String userId1, String userId2);

  Future<bool> removeFriend(String friendId);

  Future<List<Map<String, dynamic>>> searchUsers(String query);

  Future<int> getPendingRequestsCount();
}
