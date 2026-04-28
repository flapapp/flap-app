import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/notification.dart';
import '../../../matches/data/models/match.dart' as app_models;
import '../../../matches/data/supabase/match_legacy_remote_mapper.dart';
import '../../../../router/app_router.dart';
import '../../../profile/data/services/user_settings_service.dart';
import 'fcm_transport_service.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/core/config/supabase_env.dart';

class NotificationService {
  NotificationService({FcmTransportService? transportService})
      : _transportService = transportService ?? FcmTransportService();

  SupabaseClient get _sb => Supabase.instance.client;
  final FcmTransportService _transportService;
  final Set<String> _processedMessageKeys = <String>{};

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
      await _transportService.initialize(
        onForegroundMessage: _handleForegroundRemoteMessage,
        onNotificationTap: _navigateFromData,
        onToken: _saveFCMToken,
      );
      AppAuth.onAuthStateChange.listen((state) async {
        final u = state.session?.user;
        if (u != null) {
          if (!await UserSettingsService().isNotificationsEnabled()) {
            await _clearNotificationTokens(u.id);
          } else {
            await syncCurrentUserToken();
          }
        } else {
          await _clearNotificationTokens();
        }
      });

      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
  }

  Future<void> syncCurrentUserToken() async {
    if (!await UserSettingsService().isNotificationsEnabled()) {
      await _clearNotificationTokens();
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _saveFCMToken(token);
  }

  Future<void> _saveFCMToken(String token) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null || !_hasSb) return;
    if (!await UserSettingsService().isNotificationsEnabled()) {
      await _clearNotificationTokens(currentUser.id);
      return;
    }
    final platform = _devicePlatform;
    if (platform == null) return;
    await _sb.functions.invoke(
      'notification-command',
      body: <String, dynamic>{
        'action': 'register_push_token',
        'token': token,
        'platform': platform,
      },
    );
  }

  String? get _devicePlatform {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return null;
  }

  Future<void> _clearNotificationTokens([String? uid]) async {
    final userId = uid ?? AppAuth.currentUserId;
    if (userId == null || !_hasSb) return;
    await _sb.functions.invoke(
      'notification-command',
      body: <String, dynamic>{
        'action': 'revoke_push_tokens',
        'user_id': userId,
      },
    );
  }

  Future<void> _handleForegroundRemoteMessage(RemoteMessage message) async {
    final key = _messageKey(message.data);
    if (key != null && !_processedMessageKeys.add(key)) {
      return;
    }
    if (key != null && _processedMessageKeys.length > 300) {
      _processedMessageKeys.remove(_processedMessageKeys.first);
    }
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

String? _messageKey(Map<String, dynamic> data) {
  final notificationId = data['notification_id']?.toString();
  if (notificationId != null && notificationId.isNotEmpty) return notificationId;
  final queueId = data['queue_id']?.toString();
  if (queueId != null && queueId.isNotEmpty) return queueId;
  final type = data['type']?.toString() ?? '';
  final matchId = data['matchId']?.toString() ?? '';
  final challengeId = data['challengeId']?.toString() ?? '';
  final videoId = data['videoId']?.toString() ?? '';
  if (type.isEmpty) return null;
  return '$type|$matchId|$challengeId|$videoId';
}

  Future<bool> sendNotification(AppNotification notification) async {
    try {
      if (!_hasSb) return false;
      final rel = _relatedMeta(notification);
      await _sb.functions.invoke(
        'notification-command',
        body: <String, dynamic>{
          'action': 'enqueue_notification',
          'notification': <String, dynamic>{
            'user_id': notification.userId,
            'type_code': notification.type.toString().split('.').last,
            'title': notification.title,
            'message': notification.message,
            'data': notification.data,
            'image_url': notification.imageUrl,
            'action_url': notification.actionUrl,
            'is_read': notification.isRead,
            if (rel.$1 != null) 'related_table': rel.$1,
            if (rel.$2 != null) 'related_record_id': rel.$2,
          },
          'idempotency_key': _messageKey(notification.data) ??
              '${notification.userId}|${notification.type.name}|${notification.createdAt.toUtc().millisecondsSinceEpoch}',
        },
      );
      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  Future<bool> emitDomainEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    try {
      if (!_hasSb) return false;
      await _sb.functions.invoke(
        'notification-command',
        body: <String, dynamic>{
          'action': 'emit_domain_event',
          'event_type': eventType,
          'payload': payload,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'idempotency_key': idempotencyKey,
        },
      );
      return true;
    } catch (_) {
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
    return emitDomainEvent(
      eventType: 'friend_request_created',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'from_user_name': fromUserName,
        'request_id': requestId,
      },
      idempotencyKey: 'friend_request:$requestId',
    );
  }

  // Send challenge result notification
  Future<bool> sendChallengeResultNotification({
    required String toUserId,
    required String challengeTitle,
    required String challengeId,
    required int position,
    required int coinsWon,
  }) async {
    return emitDomainEvent(
      eventType: 'challenge_result_ready',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'challenge_id': challengeId,
        'challenge_title': challengeTitle,
        'position': position,
        'coins_won': coinsWon,
      },
      idempotencyKey: 'challenge_result:$challengeId:$toUserId:$position',
    );
  }

  Future<bool> sendChallengeCompletedNotification({
    required String toUserId,
    required String challengeTitle,
    required String challengeId,
  }) async {
    return emitDomainEvent(
      eventType: 'challenge_completed',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'challenge_id': challengeId,
        'challenge_title': challengeTitle,
      },
      idempotencyKey: 'challenge_completed:$challengeId:$toUserId',
    );
  }

  // Send video vote notification
  Future<bool> sendVideoVoteNotification({
  required String toUserId,
  required String videoTitle,
  required String voterName,
  required double rating,
}) async {
  return emitDomainEvent(
    eventType: 'video_vote_recorded',
    payload: <String, dynamic>{
      'to_user_id': toUserId,
      'video_title': videoTitle,
      'voter_name': voterName,
      'rating': rating,
    },
    idempotencyKey: 'video_vote:$toUserId:$voterName:$videoTitle:${rating.toStringAsFixed(2)}',
  );
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
    return emitDomainEvent(
      eventType: 'rating_changed',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'voter_name': voterName,
        'rating': rating,
        'delta': delta,
        'new_rating': newRating,
        'video_title': videoTitle,
      },
      idempotencyKey:
          'rating_changed:$toUserId:$voterName:${newRating.toStringAsFixed(2)}',
    );
  }

  // Send request to rate my videos to selected friend(s)
  Future<bool> sendRatingRequest({
    required List<String> toUserIds,
    required String fromUserName,
    required List<String> videoIds,
  }) async {
    return emitDomainEvent(
      eventType: 'rating_request_created',
      payload: <String, dynamic>{
        'to_user_ids': toUserIds,
        'from_user_name': fromUserName,
        'video_ids': videoIds,
      },
      idempotencyKey: 'rating_request:$fromUserName:${videoIds.join(",")}:${toUserIds.join(",")}',
    );
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
  return emitDomainEvent(
    eventType: 'challenge_invite_created',
    payload: <String, dynamic>{
      'to_user_id': toUserId,
      'challenge_id': challengeId,
      'challenge_title': challengeTitle,
      'creator_name': creatorName,
      'challenge_type': challengeType,
    },
    idempotencyKey: 'challenge_invite:$challengeId:$toUserId',
  );
}

  // Challenge submission notification
  Future<bool> sendChallengeSubmission({
  required String toUserId,
  required String challengeId,
  required String challengeTitle,
  required String participantName,
}) async {
  return emitDomainEvent(
    eventType: 'challenge_submission_uploaded',
    payload: <String, dynamic>{
      'to_user_id': toUserId,
      'challenge_id': challengeId,
      'challenge_title': challengeTitle,
      'participant_name': participantName,
    },
    idempotencyKey: 'challenge_submission:$challengeId:$toUserId:$participantName',
  );
}

  // Send challenge invitations to multiple users
  Future<bool> sendBulkChallengeInvitations({
    required List<String> userIds,
    required String challengeId,
    required String challengeTitle,
    required String creatorName,
    required String challengeType,
  }) async {
    return emitDomainEvent(
      eventType: 'challenge_invite_bulk_created',
      payload: <String, dynamic>{
        'to_user_ids': userIds,
        'challenge_id': challengeId,
        'challenge_title': challengeTitle,
        'creator_name': creatorName,
        'challenge_type': challengeType,
      },
      idempotencyKey: 'challenge_bulk:$challengeId:${userIds.join(",")}',
    );
  }

  Future<bool> sendTeamRosterInvite({
    required String toUserId,
    required String matchId,
    required String teamName,
    required String teamKey,
  }) async {
    return emitDomainEvent(
      eventType: 'team_roster_invite_created',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'match_id': matchId,
        'team_name': teamName,
        'team_key': teamKey,
      },
      idempotencyKey: 'team_roster:$matchId:$toUserId:$teamKey',
    );
  }

  Future<bool> sendTeamInviteNotification({
    required String toUserId,
    required String teamId,
    required String teamName,
  }) async {
    return emitDomainEvent(
      eventType: 'team_invite_created',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'team_id': teamId,
        'team_name': teamName,
      },
      idempotencyKey: 'team_invite:$teamId:$toUserId',
    );
  }

  Future<bool> sendTeamMatchRequestNotification({
    required String toUserId,
    required String matchId,
    required String opponentTeamName,
  }) async {
    return emitDomainEvent(
      eventType: 'team_match_request_created',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'match_id': matchId,
        'opponent_team_name': opponentTeamName,
      },
      idempotencyKey: 'team_match_request:$matchId:$toUserId',
    );
  }

  Future<bool> sendTeamJoinRequestNotification({
    required String toUserId,
    required String teamId,
    required String teamName,
    required String requesterName,
    required String requestId,
  }) async {
    return emitDomainEvent(
      eventType: 'team_join_request_created',
      payload: <String, dynamic>{
        'to_user_id': toUserId,
        'team_id': teamId,
        'team_name': teamName,
        'requester_name': requesterName,
        'request_id': requestId,
      },
      idempotencyKey: 'team_join:$requestId:$toUserId',
    );
  }
  Future<bool> sendMatchInvite({
  required String toUserId,
  required String matchId,
  required String organizerName,
  String? title,
  String? body,
}) async {
  return emitDomainEvent(
    eventType: 'match_invite_created',
    payload: <String, dynamic>{
      'to_user_id': toUserId,
      'match_id': matchId,
      'organizer_name': organizerName,
      'title_override': title,
      'body_override': body,
    },
    idempotencyKey: 'match_invite:$matchId:$toUserId',
  );
}

Future<bool> sendMatchApplicationSubmitted({
  required String toOrganizerId,
  required String matchId,
  required String applicantName,
}) async {
  return emitDomainEvent(
    eventType: 'match_application_submitted',
    payload: <String, dynamic>{
      'to_user_id': toOrganizerId,
      'match_id': matchId,
      'applicant_name': applicantName,
    },
    idempotencyKey: 'match_apply:$matchId:$toOrganizerId:$applicantName',
  );
}

Future<bool> sendMatchApplicationAccepted({
  required String toUserId,
  required String matchId,
  required String organizerName,
}) async {
  return emitDomainEvent(
    eventType: 'match_application_accepted',
    payload: <String, dynamic>{
      'to_user_id': toUserId,
      'match_id': matchId,
      'organizer_name': organizerName,
    },
    idempotencyKey: 'match_accept:$matchId:$toUserId',
  );
}

Future<bool> sendMatchApplicationRejected({
  required String toUserId,
  required String matchId,
  required String organizerName,
}) async {
  return emitDomainEvent(
    eventType: 'match_application_rejected',
    payload: <String, dynamic>{
      'to_user_id': toUserId,
      'match_id': matchId,
      'organizer_name': organizerName,
    },
    idempotencyKey: 'match_reject:$matchId:$toUserId',
  );
}

Future<bool> sendMatchFinished({
  required String toUserId,
  required String matchId,
  required String teamAName,
  required String teamBName,
  required int teamAScore,
  required int teamBScore,
}) async {
  return emitDomainEvent(
    eventType: 'match_finished',
    payload: <String, dynamic>{
      'to_user_id': toUserId,
      'match_id': matchId,
      'team_a_name': teamAName,
      'team_b_name': teamBName,
      'team_a_score': teamAScore,
      'team_b_score': teamBScore,
    },
    idempotencyKey: 'match_finished:$matchId:$toUserId',
  );
}
}