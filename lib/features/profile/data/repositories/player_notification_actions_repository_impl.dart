import '../../../../services/notification_service.dart';
import '../../domain/repositories/player_notification_actions_repository.dart';

class PlayerNotificationActionsRepositoryImpl
    implements PlayerNotificationActionsRepository {
  PlayerNotificationActionsRepositoryImpl(this._notifications);

  final NotificationService _notifications;

  @override
  Future<bool> sendRatingRequest({
    required List<String> toUserIds,
    required String fromUserName,
    required List<String> videoIds,
  }) {
    return _notifications.sendRatingRequest(
      toUserIds: toUserIds,
      fromUserName: fromUserName,
      videoIds: videoIds,
    );
  }

  @override
  Future<bool> sendChallengeInvitation({
    required String toUserId,
    required String challengeId,
    required String challengeTitle,
    required String creatorName,
    required String challengeType,
  }) {
    return _notifications.sendChallengeInvitation(
      toUserId: toUserId,
      challengeId: challengeId,
      challengeTitle: challengeTitle,
      creatorName: creatorName,
      challengeType: challengeType,
    );
  }
}
