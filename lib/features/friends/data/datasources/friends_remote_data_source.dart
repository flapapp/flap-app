abstract class FriendsRemoteDataSource {
  Stream<List<Map<String, dynamic>>> watchFriendRequestRowsForUser(String userId);

  Future<List<Map<String, dynamic>>> fetchFriendsWithProfiles(String userId);

  Future<String> rpcSendFriendRequest(String toUserId, {String? message});

  Future<void> rpcRespondFriendRequest(String requestId, bool accept);

  Future<void> rpcCancelFriendRequest(String requestId);

  Future<void> rpcRemoveFriendship(String friendUserId);

  Future<bool> fetchAreFriends(String userId1, String userId2);

  Future<int> fetchPendingIncomingCount(String userId);

  Future<List<Map<String, dynamic>>> fetchProfilesForSearch({
    required String excludeUserId,
    int limit,
  });

  Future<Map<String, dynamic>?> fetchFriendRequestById(String requestId);
}
