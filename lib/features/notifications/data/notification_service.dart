import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/matches/domain/repositories/matches_repository.dart';
import 'package:flap_app/features/notifications/data/datasources/supabase_notifications_remote_data_source.dart';
import 'package:flap_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:flap_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:flap_app/features/profile/data/user_settings_service.dart';
import 'package:flap_app/models/match.dart' as app_models;
import 'package:flap_app/models/notification.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/utils/app_navigator.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app / Supabase notifications + high-level send helpers. Persistence uses [NotificationsRepository].
/// Device push (FCM) was removed; server-triggered delivery should use your backend + provider.
class NotificationService {
  NotificationService({NotificationsRepository? notificationsRepository})
      : _repo = notificationsRepository ??
            NotificationsRepositoryImpl(SupabaseNotificationsRemoteDataSource());

  final NotificationsRepository _repo;

  /// Set from `main.dart` so routing can load matches from Supabase when handling notification payloads.
  static MatchesRepository? matchesRepository;

  String? get _userId => AppAuthContext.userId;
  SupabaseClient get _sb => Supabase.instance.client;

  Future<void> initialize() async {
    try {
      if (!await UserSettingsService().isNotificationsEnabled()) {
        await _clearNotificationTokens();
        return;
      }

      AppAuthContext.repository?.authStateChanges.listen((user) async {
        if (user != null) {
          if (!await UserSettingsService().isNotificationsEnabled()) {
            await _clearNotificationTokens(user.id);
          }
        }
      });
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
  }

  Future<void> syncCurrentUserToken() async {
    if (!await UserSettingsService().isNotificationsEnabled()) {
      await _clearNotificationTokens();
    }
  }

  Future<void> _clearNotificationTokens([String? uid]) async {
    final userId = uid ?? _userId;
    if (userId == null) return;
    try {
      await _sb.from('profiles').update({
        'fcm_token': null,
        'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
        'device_tokens': <String>[],
      }).eq('id', userId);
    } catch (e) {
      print('Error clearing FCM tokens: $e');
    }
  }

  /// Handle notification payload (e.g. from a custom push integration) and navigate.
  Future<void> navigateFromNotificationData(Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? '';
    if (type.isEmpty) return;

    final matchAwareTypes = <String>{
      'match_invite',
      'match_application_accepted',
      'match_application_rejected',
      'match_finished',
      'match_application_submitted',
      'team_match_request',
      'team_roster_invite',
      'team_match_ready',
    };

    app_models.Match? match;
    if (matchAwareTypes.contains(type)) {
      final matchId = data['matchId'] as String?;
      if (matchId == null) return;
      try {
        match = await matchesRepository?.fetchMatch(matchId);
      } catch (_) {
        return;
      }
      if (match == null) return;
    }

    if (AppNavigator.navigatorKey.currentContext == null) return;

    switch (type) {
      case 'match_invite':
      case 'match_application_accepted':
      case 'match_application_rejected':
        if (match != null) {
          appRouter.push(MatchDetailsRoute(match: match));
        }
        break;
      case 'match_finished':
      case 'match_application_submitted':
        if (match != null) {
          appRouter.push(MatchManagementRoute(match: match));
        }
        break;
      case 'team_match_request':
      case 'team_roster_invite':
        if (match != null) {
          appRouter.push(MatchDetailsRoute(match: match));
        }
        break;
      case 'team_match_ready':
        if (match != null) {
          appRouter.push(MatchManagementRoute(match: match));
        }
        break;
      case 'team_invite':
        appRouter.push(AppProfileRoute());
        break;
    }
  }

  Future<bool> sendNotification(AppNotification notification) async {
    try {
      await _repo.sendNotification(notification);
      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  Stream<List<AppNotification>> getUserNotifications() {
    final uid = _userId;
    if (uid == null) {
      return Stream.value([]);
    }
    return _repo.watchNotificationsForUser(uid).handleError((error, _) {
      print('Error loading notifications: $error');
    });
  }

  Stream<int> getUnreadCount() {
    final uid = _userId;
    if (uid == null) {
      return Stream.value(0);
    }
    return _repo.watchUnreadCountForUser(uid);
  }

  Future<bool> markAsRead(String notificationId) async {
    return _repo.markAsRead(notificationId);
  }

  Future<bool> markAllAsRead() async {
    final uid = _userId;
    if (uid == null) return false;
    return _repo.markAllAsRead(uid);
  }

  Future<bool> deleteNotification(String notificationId) async {
    return _repo.deleteNotification(notificationId);
  }

  Future<Map<String, int>> getNotificationStats() async {
    final uid = _userId;
    if (uid == null) return {};
    return _repo.getNotificationStats(uid);
  }

  Future<bool> clearOldNotifications() async {
    final uid = _userId;
    if (uid == null) return false;
    return _repo.clearOldNotifications(uid);
  }

  Future<bool> sendBulkNotifications(List<AppNotification> notifications) async {
    try {
      await _repo.sendBulkNotifications(notifications);
      return true;
    } catch (e) {
      print('Error sending bulk notifications: $e');
      return false;
    }
  }

  Future<bool> sendFriendRequestNotification({
    required String toUserId,
    required String fromUserName,
    required String requestId,
  }) async {
    final notification = AppNotification.friendRequest(
      userId: toUserId,
      fromUserName: fromUserName,
      requestId: requestId,
    );
    return sendNotification(notification);
  }

  Future<bool> sendFriendAcceptedNotification({
    required String toUserId,
    required String friendName,
  }) async {
    final notification = AppNotification.friendAccepted(
      userId: toUserId,
      friendName: friendName,
    );
    return sendNotification(notification);
  }

  Future<bool> sendChallengeInviteNotification({
    required String toUserId,
    required String challengeTitle,
    required String challengeId,
    required String creatorName,
  }) async {
    final notification = AppNotification.challengeInvite(
      userId: toUserId,
      challengeTitle: challengeTitle,
      challengeId: challengeId,
      creatorName: creatorName,
    );
    return sendNotification(notification);
  }

  Future<bool> sendChallengeResultNotification({
    required String toUserId,
    required String challengeTitle,
    required String challengeId,
    required int position,
    required int coinsWon,
  }) async {
    final notification = AppNotification.challengeResult(
      userId: toUserId,
      challengeTitle: challengeTitle,
      challengeId: challengeId,
      position: position,
      coinsWon: coinsWon,
    );
    return sendNotification(notification);
  }

  Future<bool> sendChallengeCompletedNotification({
    required String toUserId,
    required String challengeTitle,
    required String challengeId,
  }) async {
    final notification = AppNotification.challengeCompleted(
      userId: toUserId,
      challengeTitle: challengeTitle,
      challengeId: challengeId,
    );
    return sendNotification(notification);
  }

  Future<bool> sendVideoVoteNotification({
    required String toUserId,
    required String videoTitle,
    required String voterName,
    required double rating,
  }) async {
    final notification = AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.videoVote,
      title: I18n.inline('Нова оцінка відео', 'New video rating'),
      message: I18n.inline(
        '$voterName оцінив ваше відео "$videoTitle" на ${rating.toStringAsFixed(2)}',
        '$voterName rated your video "$videoTitle" at ${rating.toStringAsFixed(2)}',
      ),
      data: {
        'videoTitle': videoTitle,
        'voterName': voterName,
        'rating': rating,
      },
      isRead: false,
      createdAt: DateTime.now(),
    );
    return sendNotification(notification);
  }

  Future<bool> sendRatingChangedNotification({
    required String toUserId,
    required String voterName,
    required double rating,
    required double delta,
    required double newRating,
    String? videoTitle,
  }) async {
    final notification = AppNotification.ratingChanged(
      userId: toUserId,
      voterName: voterName,
      rating: rating,
      delta: delta,
      newRating: newRating,
      videoTitle: videoTitle,
    );
    return sendNotification(notification);
  }

  Future<bool> sendRatingRequest({
    required List<String> toUserIds,
    required String fromUserName,
    required List<String> videoIds,
  }) async {
    try {
      final notifications = toUserIds
          .map(
            (uid) => AppNotification.ratingRequest(
              userId: uid,
              fromUserName: fromUserName,
              videoIds: videoIds,
            ),
          )
          .toList();
      return sendBulkNotifications(notifications);
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendBadgeEarnedNotification({
    required String toUserId,
    required String badgeName,
    required String badgeEmoji,
    required String reason,
  }) async {
    final notification = AppNotification.badgeEarned(
      userId: toUserId,
      badgeName: badgeName,
      badgeEmoji: badgeEmoji,
      reason: reason,
    );
    return sendNotification(notification);
  }

  Future<bool> sendCoinsEarnedNotification({
    required String toUserId,
    required int amount,
    required String reason,
  }) async {
    final notification = AppNotification.coinsEarned(
      userId: toUserId,
      amount: amount,
      reason: reason,
    );
    return sendNotification(notification);
  }

  Future<bool> sendChallengeInvitation({
    required String toUserId,
    required String challengeId,
    required String challengeTitle,
    required String creatorName,
    required String challengeType,
  }) async {
    final notification = AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.challengeInvitation,
      title: I18n.inline('Запрошення на челендж!', 'Challenge invitation!'),
      message: I18n.inline(
        '$creatorName запросив вас взяти участь у челенджі "$challengeTitle"',
        '$creatorName invited you to join the "$challengeTitle" challenge',
      ),
      data: {
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'creatorName': creatorName,
        'challengeType': challengeType,
      },
      isRead: false,
      createdAt: DateTime.now(),
    );
    return sendNotification(notification);
  }

  Future<bool> sendChallengeSubmission({
    required String toUserId,
    required String challengeId,
    required String challengeTitle,
    required String participantName,
  }) async {
    final notification = AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.challengeUpdate,
      title: I18n.inline('Нове відео в челенджі!', 'New video in the challenge!'),
      message: I18n.inline(
        '$participantName завантажив відео до челенджу "$challengeTitle"',
        '$participantName uploaded a video to the "$challengeTitle" challenge',
      ),
      data: {
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'participantName': participantName,
      },
      isRead: false,
      createdAt: DateTime.now(),
    );
    return sendNotification(notification);
  }

  Future<bool> sendChallengeVotingStarted({
    required String toUserId,
    required String challengeId,
    required String challengeTitle,
  }) async {
    final notification = AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.challengeUpdate,
      title: I18n.inline('Голосування розпочато!', 'Voting has started!'),
      message: I18n.inline(
        'Розпочалося голосування в челенджі "$challengeTitle". Проголосуйте за найкращі відео!',
        'Voting has started in the "$challengeTitle" challenge. Please vote for the best videos!',
      ),
      data: {
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'action': 'vote',
      },
      isRead: false,
      createdAt: DateTime.now(),
    );
    return sendNotification(notification);
  }

  Future<bool> sendChallengeResults({
    required String toUserId,
    required String challengeId,
    required String challengeTitle,
    required int position,
    required int coinsWon,
  }) async {
    late final String title;
    late final String message;

    switch (position) {
      case 1:
        title = I18n.inline('🥇 Ви перемогли!', '🥇 You won!');
        message = I18n.inline(
          'Вітаємо! Ви зайняли 1 місце в челенджі "$challengeTitle" та отримали $coinsWon монет!',
          'Congratulations! You took 1st place in "$challengeTitle" and earned $coinsWon coins!',
        );
        break;
      case 2:
        title = I18n.inline('🥈 Друге місце!', '🥈 Second place!');
        message = I18n.inline(
          'Чудово! Ви зайняли 2 місце в челенджі "$challengeTitle" та отримали $coinsWon монет!',
          'Great! You took 2nd place in "$challengeTitle" and earned $coinsWon coins!',
        );
        break;
      case 3:
        title = I18n.inline('🥉 Третє місце!', '🥉 Third place!');
        message = I18n.inline(
          'Добре! Ви зайняли 3 місце в челенджі "$challengeTitle" та отримали $coinsWon монет!',
          'Nice! You took 3rd place in "$challengeTitle" and earned $coinsWon coins!',
        );
        break;
      default:
        title = I18n.inline('Челендж завершено', 'Challenge completed');
        message = I18n.inline(
          'Челендж "$challengeTitle" завершено. Дякуємо за участь!',
          'The "$challengeTitle" challenge has ended. Thanks for participating!',
        );
    }

    final notification = AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.challengeResult,
      title: title,
      message: message,
      data: {
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'position': position,
        'coinsWon': coinsWon,
      },
      isRead: false,
      createdAt: DateTime.now(),
    );
    return sendNotification(notification);
  }

  Future<bool> sendBulkChallengeInvitations({
    required List<String> userIds,
    required String challengeId,
    required String challengeTitle,
    required String creatorName,
    required String challengeType,
  }) async {
    try {
      final notifications = userIds
          .map(
            (userId) => AppNotification(
              id: '',
              userId: userId,
              type: NotificationType.challengeInvitation,
              title: I18n.inline('Запрошення на челендж!', 'Challenge invitation!'),
              message: I18n.inline(
                '$creatorName запросив вас взяти участь у челенджі "$challengeTitle"',
                '$creatorName invited you to join the "$challengeTitle" challenge',
              ),
              data: {
                'challengeId': challengeId,
                'challengeTitle': challengeTitle,
                'creatorName': creatorName,
                'challengeType': challengeType,
              },
              isRead: false,
              createdAt: DateTime.now(),
            ),
          )
          .toList();

      return sendBulkNotifications(notifications);
    } catch (e) {
      print('Error sending bulk challenge invitations: $e');
      return false;
    }
  }

  Future<bool> sendTeamRosterInvite({
    required String toUserId,
    required String matchId,
    required String teamName,
    required String teamKey,
  }) async {
    final notification = AppNotification.teamRosterInvite(
      userId: toUserId,
      matchId: matchId,
      teamName: teamName,
      teamKey: teamKey,
    );
    return sendNotification(notification);
  }

  Future<bool> sendTeamMatchReadyNotification({
    required String toUserId,
    required String matchId,
    required String teamAName,
    required String teamBName,
  }) async {
    final notification = AppNotification.teamMatchReady(
      userId: toUserId,
      matchId: matchId,
      teamAName: teamAName,
      teamBName: teamBName,
    );
    return sendNotification(notification);
  }

  Future<bool> sendTeamJoinRequestNotification({
    required String toUserId,
    required String teamId,
    required String teamName,
    required String requesterName,
    required String requestId,
  }) async {
    final notification = AppNotification.teamJoinRequest(
      userId: toUserId,
      teamId: teamId,
      teamName: teamName,
      requesterName: requesterName,
      requestId: requestId,
    );
    return sendNotification(notification);
  }

  Future<bool> sendMatchInvite({
    required String toUserId,
    required String matchId,
    required String organizerName,
    String? title,
    String? body,
  }) async {
    final localizedTitle =
        title ?? I18n.inline('Запрошення на матч', 'Match invitation');
    final localizedBody = body ??
        I18n.inline(
            '$organizerName запросив(ла) вас на матч',
            '$organizerName invited you to a match');
    return sendNotification(AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.matchInvite,
      title: localizedTitle,
      message: localizedBody,
      data: {'type': 'match_invite', 'matchId': matchId},
      createdAt: DateTime.now(),
    ));
  }

  Future<bool> sendMatchApplicationSubmitted({
    required String toOrganizerId,
    required String matchId,
    required String applicantName,
  }) async {
    return sendNotification(AppNotification(
      id: '',
      userId: toOrganizerId,
      type: NotificationType.matchInvite,
      title: I18n.inline('Нова заявка на матч', 'New match application'),
      message: I18n.inline(
        '$applicantName подав(ла) заявку на участь у вашому матчі',
        '$applicantName applied to join your match',
      ),
      data: {'type': 'match_application_submitted', 'matchId': matchId},
      createdAt: DateTime.now(),
    ));
  }

  Future<bool> sendMatchApplicationAccepted({
    required String toUserId,
    required String matchId,
    required String organizerName,
  }) async {
    return sendNotification(AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.matchInvite,
      title: I18n.inline('Заявку підтверджено', 'Application approved'),
      message: I18n.inline(
        '$organizerName підтвердив(ла) вашу участь у матчі',
        '$organizerName approved your participation in the match',
      ),
      data: {'type': 'match_application_accepted', 'matchId': matchId},
      createdAt: DateTime.now(),
    ));
  }

  Future<bool> sendMatchApplicationRejected({
    required String toUserId,
    required String matchId,
    required String organizerName,
  }) async {
    return sendNotification(AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.matchInvite,
      title: I18n.inline('Заявку відхилено', 'Application declined'),
      message: I18n.inline(
        '$organizerName відхилив(ла) вашу заявку на матч',
        '$organizerName declined your match application',
      ),
      data: {'type': 'match_application_rejected', 'matchId': matchId},
      createdAt: DateTime.now(),
    ));
  }

  Future<bool> sendMatchFinished({
    required String toUserId,
    required String matchId,
    required String teamAName,
    required String teamBName,
    required int teamAScore,
    required int teamBScore,
  }) async {
    final score = '$teamAName $teamAScore:$teamBScore $teamBName';
    return sendNotification(AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.matchFinished,
      title: I18n.inline('Матч завершено', 'Match finished'),
      message: I18n.inline(
        'Матч завершено: $score. Поставте оцінки гравцям.',
        'Full time: $score. Please rate the players.',
      ),
      data: {'type': 'match_finished', 'matchId': matchId},
      actionUrl: '/match/$matchId/rate',
      createdAt: DateTime.now(),
    ));
  }
}
