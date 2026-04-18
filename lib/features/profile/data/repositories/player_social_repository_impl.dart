import '../../../../models/friend_request.dart';
import '../../../../services/friends_service.dart';
import '../../domain/repositories/player_social_repository.dart';

class PlayerSocialRepositoryImpl implements PlayerSocialRepository {
  PlayerSocialRepositoryImpl(this._friends);

  final FriendsService _friends;

  @override
  Future<bool> areUsersFriends(String userIdA, String userIdB) {
    return _friends.areUsersFriends(userIdA, userIdB);
  }

  @override
  Future<bool> hasOutgoingPendingRequestTo(String toUserId) async {
    final outgoing = await _friends.getOutgoingFriendRequests().first;
    return outgoing.any((request) => request.toUserId == toUserId);
  }

  @override
  Future<void> sendFriendRequest(String toUserId) {
    return _friends.sendFriendRequest(toUserId);
  }

  @override
  Future<int> countFriends(String userId) async {
    final friends = await _friends.getUserFriends(userId);
    return friends.length;
  }

  @override
  Future<List<Friend>> listFriendsOfUser(String userId) {
    return _friends.getUserFriends(userId);
  }
}
