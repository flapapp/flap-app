/// Wraps in-app notification side-effects used from player profile flows.
abstract class PlayerNotificationActionsRepository {
  Future<bool> sendRatingRequest({
    required List<String> toUserIds,
    required String fromUserName,
    required List<String> videoIds,
  });

  Future<bool> sendChallengeInvitation({
    required String toUserId,
    required String challengeId,
    required String challengeTitle,
    required String creatorName,
    required String challengeType,
  });
}
