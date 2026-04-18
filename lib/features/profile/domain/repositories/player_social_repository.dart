import '../../../../models/friend_request.dart';

/// Friend relationship actions for viewing another player (domain).
abstract class PlayerSocialRepository {
  Future<bool> areUsersFriends(String userIdA, String userIdB);

  /// Pending outgoing request from the **current** signed-in user to [toUserId].
  Future<bool> hasOutgoingPendingRequestTo(String toUserId);

  /// Delegates to [FriendsService.sendFriendRequest].
  Future<void> sendFriendRequest(String toUserId);

  Future<int> countFriends(String userId);

  /// Friends linked to [userId] (delegates to [FriendsService.getUserFriends]).
  Future<List<Friend>> listFriendsOfUser(String userId);
}
