/// Challenges the current user can invite [targetPlayerId] to join.
abstract class PlayerChallengeInviteRepository {
  Future<List<Map<String, dynamic>>> listInvitableChallenges({
    required String creatorUserId,
    required String targetPlayerId,
  });
}
