import '../../data/models/friend_request.dart';
import '../entities/friendship_state.dart';

/// Friend requests, search, and friend list operations (domain).
abstract class FriendsRepository {
  Future<bool> sendFriendRequest(String toUserId, {String? message});

  Stream<List<FriendRequest>> getIncomingFriendRequests();

  Stream<List<FriendRequest>> getOutgoingFriendRequests();

  /// Pending incoming requests (snapshot; same data as [getIncomingFriendRequests] stream).
  Future<List<FriendRequest>> fetchPendingIncomingFriendRequests();

  /// Pending outgoing requests (snapshot; same data as [getOutgoingFriendRequests] stream).
  Future<List<FriendRequest>> fetchPendingOutgoingFriendRequests();

  Future<bool> respondToFriendRequest(String requestId, bool accept);

  Future<bool> cancelFriendRequest(String requestId);

  Future<List<Friend>> getUserFriends(String userId);

  Future<bool> areUsersFriends(String userId1, String userId2);

  /// Friendship flags and any pending request ids between the signed-in user and [otherUserId].
  Future<FriendshipState> friendshipStateWith(String otherUserId);

  Future<bool> removeFriend(String friendId);

  Future<List<Map<String, dynamic>>> searchUsers(String query);

  Future<int> getPendingRequestsCount();
}
