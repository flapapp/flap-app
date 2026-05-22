import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app_navigator_key.dart';
import '../../../core/di/injection.dart';
import '../../../router/app_router.dart';
import '../../challenges/data/models/challenge.dart';
import '../../matches/domain/repositories/matches_repository.dart';
import '../data/models/notification.dart';

/// Central routing for notification taps (in-app list + push deep links).
class NotificationRouter {
  NotificationRouter._();

  static BuildContext? get _context => appNavigatorKey.currentContext;

  static StackRouter? get _router {
    final c = _context;
    if (c == null) return null;
    return c.router;
  }

  static String? pickString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static void _snack(String message) {
    final ctx = _context;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// In-app notification row tap.
  static Future<bool> navigateFromAppNotification(AppNotification n) async {
    if (await _navigateByTypeAndData(n.type, n.data)) return true;
    final url = n.actionUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (await _navigateByActionUrl(url, n.data)) return true;
    }
    return false;
  }

  /// FCM / background payload (`data.type`, `matchId` or `match_id`, etc.).
  static Future<bool> navigateFromPushData(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    final type = pickString(data, ['type', 'notification_type']) ?? '';
    return _navigateByPushType(type, data);
  }

  static Future<bool> _navigateByPushType(
    String type,
    Map<String, dynamic> data,
  ) async {
    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
        _router?.push(const FriendsRoute());
        return _router != null;
      case 'challenge_invitation':
      case 'challenge_update':
      case 'challenge_result':
      case 'challenge_completed':
        final id = pickString(data, ['challengeId', 'challenge_id']);
        if (id != null) return _openChallengeById(id);
        break;
      case 'video_vote':
        _router?.push(VideoMainRoute());
        return _router != null;
      case 'match_invite':
        final id = pickString(data, ['matchId', 'match_id']);
        if (id == null) break;
        final payloadType = pickString(data, ['payload_type']);
        if (payloadType == 'match_application_submitted' ||
            data['type']?.toString() == 'match_application_submitted') {
          return _openMatchManagementById(id);
        }
        return _openMatchDetailsById(id);
      case 'match_application_submitted':
        final subId = pickString(data, ['matchId', 'match_id']);
        if (subId != null) return _openMatchManagementById(subId);
        break;
      case 'match_finished':
        final id = pickString(data, ['matchId', 'match_id']);
        if (id != null) return _openMatchRatingById(id);
        break;
      case 'team_match_request':
      case 'team_roster_invite':
        final id = pickString(data, ['matchId', 'match_id']);
        if (id != null) return _openMatchDetailsById(id);
        break;
      case 'team_match_ready':
        final id = pickString(data, ['matchId', 'match_id']);
        if (id != null) return _openMatchManagementById(id);
        break;
      case 'team_invite':
      case 'badge_earned':
      case 'coins_earned':
      case 'rating_changed':
        _router?.push(const ProfileRoute());
        return _router != null;
      case 'team_join_request':
        final tid = pickString(data, ['teamId', 'team_id']);
        if (tid != null) {
          _router?.push(TeamDetailsRoute(teamId: tid));
          return _router != null;
        }
        _router?.push(const TeamHubRoute());
        return _router != null;
      case 'rating_request':
        final ids = data['videoIds'] ?? data['video_ids'];
        if (ids is List && ids.isNotEmpty) {
          return _openVideoById(ids.first.toString());
        }
        _router?.push(VideoMainRoute());
        return _router != null;
    }

    final action = pickString(data, ['actionUrl', 'action_url']);
    if (action != null) {
      return _navigateByActionUrl(action, data);
    }
    return false;
  }

  static Future<bool> _navigateByTypeAndData(
    NotificationType type,
    Map<String, dynamic> data,
  ) async {
    String? readMatchId() => pickString(data, ['matchId', 'match_id']);
    String? readChallengeId() =>
        pickString(data, ['challengeId', 'challenge_id']);
    String? readTeamId() => pickString(data, ['teamId', 'team_id']);
    final payloadKind = data['type']?.toString() ?? '';

    switch (type) {
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        _router?.push(const FriendsRoute());
        return _router != null;
      case NotificationType.challengeInvitation:
      case NotificationType.challengeUpdate:
      case NotificationType.challengeResult:
      case NotificationType.challengeCompleted:
        final id = readChallengeId();
        if (id != null) return _openChallengeById(id);
        break;
      case NotificationType.videoVote:
        _router?.push(VideoMainRoute());
        return _router != null;
      case NotificationType.matchInvite:
        final id = readMatchId();
        if (id == null) break;
        if (payloadKind == 'match_application_submitted') {
          return _openMatchManagementById(id);
        }
        return _openMatchDetailsById(id);
      case NotificationType.matchFinished:
        final id = readMatchId();
        if (id != null) return _openMatchRatingById(id);
        break;
      case NotificationType.teamMatchRequest:
      case NotificationType.teamRosterInvite:
        final id = readMatchId();
        if (id != null) return _openMatchDetailsById(id);
        break;
      case NotificationType.teamMatchReady:
        final id = readMatchId();
        if (id != null) return _openMatchManagementById(id);
        break;
      case NotificationType.teamInvite:
        _router?.push(const ProfileRoute());
        return _router != null;
      case NotificationType.teamJoinRequest:
        final id = readTeamId();
        if (id != null) {
          _router?.push(TeamDetailsRoute(teamId: id));
          return _router != null;
        }
        _router?.push(const TeamHubRoute());
        return _router != null;
      case NotificationType.ratingRequest:
        final ids = data['videoIds'];
        if (ids is List && ids.isNotEmpty) {
          return _openVideoById(ids.first.toString());
        }
        _router?.push(VideoMainRoute());
        return _router != null;
      case NotificationType.ratingChanged:
      case NotificationType.badgeEarned:
      case NotificationType.badgeEndorsed:
      case NotificationType.coinsEarned:
        _router?.push(const ProfileRoute());
        return _router != null;
    }
    return false;
  }

  static Future<bool> _navigateByActionUrl(
    String actionUrl,
    Map<String, dynamic> data,
  ) async {
    var path = actionUrl.trim();
    if (path.startsWith('http')) {
      final u = Uri.tryParse(path);
      path = u?.path ?? path;
    }
    if (!path.startsWith('/')) return false;

    if (path == '/friends') {
      _router?.push(const FriendsRoute());
      return _router != null;
    }
    if (path == '/profile') {
      _router?.push(const ProfileRoute());
      return _router != null;
    }
    if (path == '/video-main') {
      _router?.push(VideoMainRoute());
      return _router != null;
    }
    if (path == '/teams') {
      _router?.push(const TeamHubRoute());
      return _router != null;
    }
    if (path == '/match_management' || path == '/match-management') {
      final id = pickString(data, ['matchId', 'match_id']);
      if (id != null) return _openMatchManagementById(id);
      return false;
    }
    if (path.startsWith('/video/')) {
      final videoId = path.split('/').last;
      return _openVideoById(videoId);
    }
    if (path.startsWith('/challenge-details/')) {
      final challengeId = path.split('/').last;
      return _openChallengeById(challengeId);
    }
    if (path.startsWith('/match/') && path.endsWith('/rate')) {
      final segments = path.split('/');
      if (segments.length >= 3) {
        return _openMatchRatingById(segments[2]);
      }
    }
    if (path.startsWith('/match-details/')) {
      final matchId = path.split('/').last;
      return _openMatchDetailsById(matchId);
    }
    return false;
  }

  static Future<bool> _openChallengeById(String challengeId) async {
    final router = _router;
    if (router == null) return false;
    try {
      final sb = Supabase.instance.client;
      final row = await sb
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .maybeSingle();
      if (row == null) {
        _snack(tr('il_a29799fa76'));
        return false;
      }
      final challenge = Challenge.fromFirestore(
        _NotifMapDoc(challengeId, <String, dynamic>{
          'title': row['title'],
          'description': row['description'],
          'type': '',
          'status': row['status'],
          'entryFee': row['entry_fee'] ?? 0,
          'maxParticipants': row['max_participants'] ?? 0,
          'participants': const <String>[],
          'prizePool': 0,
          'startDate': row['starts_at'],
          'endDate': row['ends_at'],
          'createdAt': row['created_at'],
          'createdBy': row['creator_id'],
          'city': row['city'],
          'isTeamChallenge': false,
          'creatorVideoUrl': '',
          'creatorThumbnailUrl': row['image_url'],
          'submissionDeadline': row['submission_deadline'],
          'votingDeadline': row['voting_deadline'],
        }),
      );
      await router.push(ChallengeDetailsRoute(challenge: challenge));
      return true;
    } catch (e) {
      _snack(tr('il_f5d8bd3f0a', namedArgs: {'e': e.toString()}));
      return false;
    }
  }

  static Future<bool> _openMatchDetailsById(String matchId) async {
    final router = _router;
    if (router == null) return false;
    try {
      final match = await sl<MatchesRepository>().fetchMatchById(matchId);
      if (match == null) {
        _snack(tr('il_6b539d4234', namedArgs: {'matchId': matchId}));
        return false;
      }
      await router.push(MatchDetailsRoute(match: match));
      return true;
    } catch (e) {
      _snack(tr('il_80c7341273', namedArgs: {'e': e.toString()}));
      return false;
    }
  }

  static Future<bool> _openMatchRatingById(String matchId) async {
    final router = _router;
    if (router == null) return false;
    try {
      final match = await sl<MatchesRepository>().fetchMatchById(matchId);
      if (match == null) {
        _snack(tr('il_6b539d4234', namedArgs: {'matchId': matchId}));
        return false;
      }
      await router.push(MatchRatingRoute(match: match));
      return true;
    } catch (e) {
      _snack(tr('il_5eda94340a', namedArgs: {'e': e.toString()}));
      return false;
    }
  }

  static Future<bool> _openMatchManagementById(String matchId) async {
    final router = _router;
    if (router == null) return false;
    try {
      final match = await sl<MatchesRepository>().fetchMatchById(matchId);
      if (match == null) {
        _snack(tr('il_6b539d4234', namedArgs: {'matchId': matchId}));
        return false;
      }
      await router.push(MatchManagementRoute(match: match));
      return true;
    } catch (e) {
      _snack(tr('il_80c7341273', namedArgs: {'e': e.toString()}));
      return false;
    }
  }

  static Future<bool> _openVideoById(String videoId) async {
    final router = _router;
    if (router == null) return false;
    try {
      final sb = Supabase.instance.client;
      final data =
          await sb.from('videos').select().eq('id', videoId).maybeSingle();
      if (data == null) {
        _snack(tr('il_e861519b9c'));
        return false;
      }
      final videoUrl =
          (data['video_url'] ?? data['videoUrl'] ?? '').toString();
      final title = (data['title'] ?? tr('il_d534be829e')).toString();
      if (videoUrl.isEmpty) {
        _snack(tr('il_e1bc626d15'));
        return false;
      }
      await router.push(
        VideoPlayerRoute(
          videoUrl: videoUrl,
          title: title,
          authorName: '',
          videoId: videoId,
        ),
      );
      return true;
    } catch (e) {
      _snack(tr('il_2e74389175', namedArgs: {'e': e.toString()}));
      return false;
    }
  }
}

class _NotifMapDoc {
  _NotifMapDoc(this.id, this._data);
  final String id;
  final Map<String, dynamic> _data;
  Map<String, dynamic> data() => _data;
}
