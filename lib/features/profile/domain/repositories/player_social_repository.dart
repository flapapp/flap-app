import '../../../friends/data/models/friend_request.dart';
import '../../../friends/domain/entities/friendship_state.dart';

/// Friend relationship actions for viewing another player (domain).
abstract class PlayerSocialRepository {
  Future<bool> areUsersFriends(String userIdA, String userIdB);

  /// Pending outgoing request from the **current** signed-in user to [toUserId].
  Future<bool> hasOutgoingPendingRequestTo(String toUserId);

  /// Full friendship / pending-request state for the signed-in user vs [otherUserId].
  Future<FriendshipState> friendshipStateWith(String otherUserId);

  /// Delegates to [FriendsRepository.sendFriendRequest].
  Future<void> sendFriendRequest(String toUserId);

  Future<int> countFriends(String userId);

  /// Friends linked to [userId] (delegates to [FriendsRepository.getUserFriends]).
  Future<List<Friend>> listFriendsOfUser(String userId);
}
