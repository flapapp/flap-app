import '../../../friends/data/models/friend_request.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import '../../../friends/domain/entities/friendship_state.dart';
import '../../domain/repositories/player_social_repository.dart';

class PlayerSocialRepositoryImpl implements PlayerSocialRepository {
  PlayerSocialRepositoryImpl(this._friends);

  final FriendsRepository _friends;

  @override
  Future<bool> areUsersFriends(String userIdA, String userIdB) {
    return _friends.areUsersFriends(userIdA, userIdB);
  }

  @override
  Future<bool> hasOutgoingPendingRequestTo(String toUserId) async {
    final s = await _friends.friendshipStateWith(toUserId);
    return s.hasPendingOutgoing;
  }

  @override
  Future<FriendshipState> friendshipStateWith(String otherUserId) {
    return _friends.friendshipStateWith(otherUserId);
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
