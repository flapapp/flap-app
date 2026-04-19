import '../models/friend_request.dart';
import '../services/friends_service.dart';
import '../../domain/repositories/friends_repository.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this._friends);

  final FriendsService _friends;

  @override
  Future<bool> sendFriendRequest(String toUserId, {String? message}) {
    return _friends.sendFriendRequest(toUserId, message: message);
  }

  @override
  Stream<List<FriendRequest>> getIncomingFriendRequests() {
    return _friends.getIncomingFriendRequests();
  }

  @override
  Stream<List<FriendRequest>> getOutgoingFriendRequests() {
    return _friends.getOutgoingFriendRequests();
  }

  @override
  Future<bool> respondToFriendRequest(String requestId, bool accept) {
    return _friends.respondToFriendRequest(requestId, accept);
  }

  @override
  Future<bool> cancelFriendRequest(String requestId) {
    return _friends.cancelFriendRequest(requestId);
  }

  @override
  Future<List<Friend>> getUserFriends(String userId) {
    return _friends.getUserFriends(userId);
  }

  @override
  Future<bool> areUsersFriends(String userId1, String userId2) {
    return _friends.areUsersFriends(userId1, userId2);
  }

  @override
  Future<bool> removeFriend(String friendId) {
    return _friends.removeFriend(friendId);
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) {
    return _friends.searchUsers(query);
  }

  @override
  Future<int> getPendingRequestsCount() {
    return _friends.getPendingRequestsCount();
  }
}
