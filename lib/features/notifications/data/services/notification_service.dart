import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/notification.dart';
import '../../../matches/data/models/match.dart' as app_models;
import '../../../matches/data/supabase/match_legacy_remote_mapper.dart';
import '../../../../router/app_router.dart';
import '../../../profile/data/services/user_settings_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/core/config/supabase_env.dart';
import 'package:flap_app/core/supabase/supabase_lookups.dart';

class NotificationService {
  SupabaseClient get _sb => Supabase.instance.client;

  bool get _hasSb =>
      SupabaseEnv.url.isNotEmpty && SupabaseEnv.anonKey.isNotEmpty;

  (String? table, String? id) _relatedMeta(AppNotification n) {
    final d = n.data;
    final mid = d['matchId'] as String?;
    if (mid != null) return ('matches', mid);
    final cid = d['challengeId'] as String?;
    if (cid != null) return ('challenges', cid);
    final vid = d['videoId'] as String?;
    if (vid != null) return ('videos', vid);
    final vids = d['videoIds'];
    if (vids is List && vids.isNotEmpty) {
      return ('videos', vids.first.toString());
    }
    final tid = d['teamId'] as String?;
    if (tid != null) return ('teams', tid);
    return (null, null);
  }

  // Initialize notifications
  Future<void> initialize() async {
    try {
      if (!await UserSettingsService().isNotificationsEnabled()) {
        await _clearNotificationTokens();
        return;
      }

      print('Initializing NotificationService...');
      AppAuth.onAuthStateChange.listen((state) async {
        final u = state.session?.user;
        if (u != null) {
          if (!await UserSettingsService().isNotificationsEnabled()) {
            await _clearNotificationTokens(u.id);
          }
        }
      });

      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
  }

  Future<void> syncCurrentUserToken() async {
    await _clearNotificationTokens();
  }

  Future<void> _saveFCMToken(String token) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null || !_hasSb) return;
    if (!await UserSettingsService().isNotificationsEnabled()) {
      await _clearNotificationTokens(currentUser.id);
      return;
    }
    const platform = 'disabled';
    await _sb.from('push_tokens').upsert(
      <String, dynamic>{
        'user_id': currentUser.id,
        'token': token,
        'platform': platform,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  Future<void> _clearNotificationTokens([String? uid]) async {
    final userId = uid ?? AppAuth.currentUserId;
    if (userId == null || !_hasSb) return;
    await _sb.from('push_tokens').update(<String, dynamic>{
      'revoked_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }

  // Handle foreground messages
  void _handleForegroundMessage(Map<String, dynamic> message) {
    print('Received foreground message: ${message['title']}');
    // Show in-app notification or update UI
  }

  // Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> message) {
  _navigateFromData(message);
}

Future<void> _navigateFromData(Map<String, dynamic> data) async {
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
      if (!_hasSb) return;
      final legacy = await MatchLegacyRemoteMapper.load(_sb, matchId);
      if (legacy == null) return;
      match = app_models.Match.fromLegacyMap(matchId, legacy);
    } catch (_) {
      return;
    }
  }

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
      if (match != null) {
        appRouter.push(MatchDetailsRoute(match: match));
      }
      break;
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
      appRouter.push(const ProfileRoute());
      break;
  }
}

  Future<bool> sendNotification(AppNotification notification) async {
    try {
      if (!_hasSb) return false;
      final typeCode = notification.type.toString().split('.').last;
      final typeId = await SupabaseLookups.notificationTypeId(
        _sb,
        typeCode,
        typeCode,
      );
      final rel = _relatedMeta(notification);
      await _sb.from('notifications').insert(<String, dynamic>{
        'user_id': notification.userId,
        'notification_type_id': typeId,
        'title': notification.title,
        'message': AppNotification.packMessageField(notification),
        if (rel.$1 != null) 'related_table': rel.$1,
        if (rel.$2 != null) 'related_record_id': rel.$2,
        'is_read': notification.isRead,
      });
      try {
        await _sb.from('push_notification_queue').insert(<String, dynamic>{
          'user_id': notification.userId,
          'title': notification.title,
          'message': notification.message,
          'notification_type_id': typeId,
          if (rel.$1 != null) 'related_table': rel.$1,
          if (rel.$2 != null) 'related_record_id': rel.$2,
          'status': 'pending',
        });
      } catch (_) {}
      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  Stream<List<AppNotification>> getUserNotifications() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null || !_hasSb) {
      return Stream.value([]);
    }

    Future<List<AppNotification>> load() async {
      final rows = await _sb
          .from('notifications')
          .select('*, notification_types(code)')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(50);
      final notifications = <AppNotification>[];
      for (final raw in rows as List<dynamic>) {
        try {
          notifications.add(
            AppNotification.fromSupabase(
              Map<String, dynamic>.from(raw as Map),
            ),
          );
        } catch (e) {
          print('Error parsing notification: $e');
        }
      }
      return notifications;
    }

    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser.id)
        .asyncMap((_) => load())
        .handleError((Object error) {
          print('Error loading notifications: $error');
        });
  }

  Stream<int> getUnreadCount() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null || !_hasSb) {
      return Stream.value(0);
    }

    Future<int> count() async {
      final rows = await _sb
          .from('notifications')
          .select('id')
          .eq('user_id', currentUser.id)
          .eq('is_read', false);
      return (rows as List).length;
    }

    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser.id)
        .asyncMap((_) => count());
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      if (!_hasSb) return false;
      await _sb.from('notifications').update(<String, dynamic>{
        'is_read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null || !_hasSb) return false;

      await _sb.from('notifications').update(<String, dynamic>{
        'is_read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', currentUser.id).eq('is_read', false);
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      if (!_hasSb) return false;
      await _sb.from('notifications').delete().eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  // Helper methods for sending specific notifications
  
  // Send friend request notification
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
    return await sendNotification(notification);
  }

  // Send friend accepted notification
  Future<bool> sendFriendAcceptedNotification({
    required String toUserId,
    required String friendName,
  }) async {
    final notification = AppNotification.friendAccepted(
      userId: toUserId,
      friendName: friendName,
    );
    return await sendNotification(notification);
  }

  // Send challenge invite notification
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
    return await sendNotification(notification);
  }

  // Send challenge result notification
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
    return await sendNotification(notification);
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
    return await sendNotification(notification);
  }

  // Send video vote notification
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
    title: tr('il_e54105ee12'),
    message: bilingual(
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
  return await sendNotification(notification);
}

  // Send a rating change summary notification
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
    return await sendNotification(notification);
  }

  // Send request to rate my videos to selected friend(s)
  Future<bool> sendRatingRequest({
    required List<String> toUserIds,
    required String fromUserName,
    required List<String> videoIds,
  }) async {
    try {
      final notifications = toUserIds.map((uid) => AppNotification.ratingRequest(
        userId: uid,
        fromUserName: fromUserName,
        videoIds: videoIds,
      )).toList();
      return await sendBulkNotifications(notifications);
    } catch (e) {
      return false;
    }
  }

  // Send badge earned notification
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
    return await sendNotification(notification);
  }

  // Send coins earned notification
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
    return await sendNotification(notification);
  }

  // Send bulk notifications (for challenge results)
  Future<bool> sendBulkNotifications(List<AppNotification> notifications) async {
    try {
      if (!_hasSb) return false;
      for (final notification in notifications) {
        await sendNotification(notification);
      }
      return true;
    } catch (e) {
      print('Error sending bulk notifications: $e');
      return false;
    }
  }

  Future<Map<String, int>> getNotificationStats() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null || !_hasSb) return {};

      final rows = await _sb
          .from('notifications')
          .select('notification_types(code)')
          .eq('user_id', currentUser.id);

      final stats = <String, int>{};

      for (final raw in rows as List<dynamic>) {
        final m = raw as Map<String, dynamic>;
        final nt = m['notification_types'];
        final code = nt is Map ? nt['code'] as String? : null;
        if (code == null) continue;
        stats[code] = (stats[code] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting notification stats: $e');
      return {};
    }
  }

  Future<bool> clearOldNotifications() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null || !_hasSb) return false;

      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();

      await _sb
          .from('notifications')
          .delete()
          .eq('user_id', currentUser.id)
          .lt('created_at', thirtyDaysAgo);
      return true;
    } catch (e) {
      print('Error clearing old notifications: $e');
      return false;
    }
  }

  // Challenge invitation notification
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
    title: tr('il_f9b41369d5'),
    message: bilingual(
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
  return await sendNotification(notification);
}

  // Challenge submission notification
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
    title: tr('il_7ce51873c6'),
    message: bilingual(
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
  return await sendNotification(notification);
}

  // Challenge voting started notification
  Future<bool> sendChallengeVotingStarted({
  required String toUserId,
  required String challengeId,
  required String challengeTitle,
}) async {
  final notification = AppNotification(
    id: '',
    userId: toUserId,
    type: NotificationType.challengeUpdate,
    title: tr('il_8da8637d80'),
    message: bilingual(
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
  return await sendNotification(notification);
}

  // Challenge results notification
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
      title = tr('il_0901974591');
      message = bilingual(
        'Вітаємо! Ви зайняли 1 місце в челенджі "$challengeTitle" та отримали $coinsWon монет!',
        'Congratulations! You took 1st place in "$challengeTitle" and earned $coinsWon coins!',
      );
      break;
    case 2:
      title = tr('il_1c3e8ad54d');
      message = bilingual(
        'Чудово! Ви зайняли 2 місце в челенджі "$challengeTitle" та отримали $coinsWon монет!',
        'Great! You took 2nd place in "$challengeTitle" and earned $coinsWon coins!',
      );
      break;
    case 3:
      title = tr('il_c7c21b29c5');
      message = bilingual(
        'Добре! Ви зайняли 3 місце в челенджі "$challengeTitle" та отримали $coinsWon монет!',
        'Nice! You took 3rd place in "$challengeTitle" and earned $coinsWon coins!',
      );
      break;
    default:
      title = tr('il_6011c9f25a');
      message = bilingual(
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
  return await sendNotification(notification);
}

  // Send challenge invitations to multiple users
  Future<bool> sendBulkChallengeInvitations({
    required List<String> userIds,
    required String challengeId,
    required String challengeTitle,
    required String creatorName,
    required String challengeType,
  }) async {
    try {
      final notifications = userIds.map((userId) => AppNotification(
        id: '',
        userId: userId,
        type: NotificationType.challengeInvitation,
        title: tr('il_f9b41369d5'),
        message: bilingual(
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
      )).toList();

      return await sendBulkNotifications(notifications);
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
    return await sendNotification(notification);
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
    return await sendNotification(notification);
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
    return await sendNotification(notification);
  }
  Future<bool> sendMatchInvite({
  required String toUserId,
  required String matchId,
  required String organizerName,
  String? title,
  String? body,
}) async {
  final localizedTitle = title ?? tr('il_bfaa223845');
  final localizedBody = body ?? tr('il_2a17d067e3');
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
    title: tr('il_8b79eee0c4'),
    message: bilingual(
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
    title: tr('il_c491d848c2'),
    message: bilingual(
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
    title: tr('il_149be53f9a'),
    message: bilingual(
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
    title: tr('il_dc00754e01'),
    message: bilingual(
      'Матч завершено: $score. Поставте оцінки гравцям.',
      'Full time: $score. Please rate the players.',
    ),
    data: {'type': 'match_finished', 'matchId': matchId},
    actionUrl: '/match/$matchId/rate',
    createdAt: DateTime.now(),
  ));
}
}