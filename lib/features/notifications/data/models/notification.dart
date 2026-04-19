import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:flap_app/core/supabase/supabase_date.dart';

import '../../domain/entities/app_notification_entity.dart';

export '../../domain/entities/app_notification_entity.dart';

part 'notification.g.dart';

@JsonSerializable(explicitToJson: true)
class AppNotification extends AppNotificationEntity {
  const AppNotification({
    required super.id,
    required super.userId,
    required super.type,
    required super.title,
    required super.message,
    required super.data,
    required super.createdAt,
    super.isRead = false,
    super.imageUrl,
    super.actionUrl,
  });

  static NotificationType _typeFromCode(String? code) {
    if (code == null || code.isEmpty) {
      return NotificationType.friendRequest;
    }
    return NotificationType.values.firstWhere(
      (e) => e.toString().split('.').last == code,
      orElse: () => NotificationType.friendRequest,
    );
  }

  static Map<String, dynamic> _unpackMessageField(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>?;
      if (j != null && j['v'] == 1) {
        return <String, dynamic>{
          'displayMessage': j['displayMessage'] as String? ?? '',
          'data': Map<String, dynamic>.from(j['data'] as Map? ?? {}),
          'imageUrl': j['imageUrl'] as String?,
          'actionUrl': j['actionUrl'] as String?,
        };
      }
    } catch (_) {}
    return <String, dynamic>{
      'displayMessage': raw,
      'data': <String, dynamic>{},
      'imageUrl': null,
      'actionUrl': null,
    };
  }

  static String packMessageField(AppNotification n) => jsonEncode(<String, dynamic>{
        'v': 1,
        'displayMessage': n.message,
        'data': n.data,
        'imageUrl': n.imageUrl,
        'actionUrl': n.actionUrl,
      });

  factory AppNotification.fromSupabase(Map<String, dynamic> row) {
    final nt = row['notification_types'];
    final code =
        nt is Map ? nt['code'] as String? : null;
    final unpacked = _unpackMessageField(row['message'] as String? ?? '');
    return AppNotification(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      type: _typeFromCode(code),
      title: row['title'] as String? ?? '',
      message: unpacked['displayMessage'] as String,
      data: Map<String, dynamic>.from(unpacked['data'] as Map),
      createdAt: asDateTime(row['created_at']),
      isRead: row['is_read'] as bool? ?? false,
      imageUrl: unpacked['imageUrl'] as String?,
      actionUrl: unpacked['actionUrl'] as String?,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  Map<String, dynamic> toJson() => _$AppNotificationToJson(this);

  // Copy with changes
  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isRead,
    String? imageUrl,
    String? actionUrl,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  // Getters for display
  String get typeIcon {
    switch (type) {
      case NotificationType.friendRequest:
        return '👥';
      case NotificationType.friendAccepted:
        return '✅';
      case NotificationType.challengeInvitation:
        return '⚔️';
      case NotificationType.challengeUpdate:
        return '📹';
      case NotificationType.challengeResult:
        return '🏆';
      case NotificationType.challengeCompleted:
        return '🎉';
      case NotificationType.videoVote:
        return '⭐';
      case NotificationType.matchInvite:
        return '⚽';
      case NotificationType.matchFinished:
        return '🏁';
      case NotificationType.badgeEarned:
        return '🏅';
      case NotificationType.badgeEndorsed:
        return '👍';
      case NotificationType.coinsEarned:
        return '💰';
      case NotificationType.ratingRequest:
        return '⭐';
      case NotificationType.ratingChanged:
        return '📈';
      case NotificationType.teamInvite:
        return '🏟️';
      case NotificationType.teamMatchRequest:
        return '⚽';
      case NotificationType.teamRosterInvite:
        return '📝';
      case NotificationType.teamMatchReady:
        return '🏁';
      case NotificationType.teamJoinRequest:
        return '📥';
    }
  }

  int get typeColor {
    switch (type) {
      case NotificationType.friendRequest:
        return 0xFF2196F3; // Blue
      case NotificationType.friendAccepted:
        return 0xFF4CAF50; // Green
      case NotificationType.challengeInvitation:
        return 0xFFFF9800; // Orange
      case NotificationType.challengeUpdate:
        return 0xFF2196F3; // Blue
      case NotificationType.challengeResult:
        return 0xFFFFD700; // Gold
      case NotificationType.challengeCompleted:
        return 0xFF4CAF50; // Green
      case NotificationType.videoVote:
        return 0xFF9C27B0; // Purple
      case NotificationType.matchInvite:
        return 0xFF4CAF50; // Green
      case NotificationType.matchFinished:
        return 0xFF2196F3; // Blue
      case NotificationType.badgeEarned:
        return 0xFFE91E63; // Pink
      case NotificationType.badgeEndorsed:
        return 0xFFFFD700; // Gold
      case NotificationType.coinsEarned:
        return 0xFFFFD700; // Gold
      case NotificationType.ratingRequest:
        return 0xFF2196F3; // Blue
      case NotificationType.ratingChanged:
        return 0xFFFFD700; // Gold
      case NotificationType.teamInvite:
        return 0xFF00BCD4;
      case NotificationType.teamMatchRequest:
        return 0xFF4CAF50;
      case NotificationType.teamRosterInvite:
        return 0xFFFFC107;
      case NotificationType.teamMatchReady:
        return 0xFF00BCD4;
      case NotificationType.teamJoinRequest:
        return 0xFF42A5F5;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
  return bilingual(
    '${difference.inDays} дн. тому',
    '${difference.inDays} d ago',
  );
} else if (difference.inHours > 0) {
  return bilingual(
    '${difference.inHours} год. тому',
    '${difference.inHours} h ago',
  );
} else if (difference.inMinutes > 0) {
  return bilingual(
    '${difference.inMinutes} хв. тому',
    '${difference.inMinutes} min ago',
  );
} else {
  return tr('il_66f53417d3');
}
  }

  // Factory constructors for different notification types
  static AppNotification friendRequest({
    required String userId,
    required String fromUserName,
    required String requestId,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.friendRequest,
      title: tr('il_ac614bd269'),
      message: bilingual(
        '$fromUserName хоче додати вас у друзі',
        '$fromUserName wants to add you as a friend',
      ),
      data: {
        'requestId': requestId,
        'fromUserName': fromUserName,
      },
      createdAt: DateTime.now(),
      actionUrl: '/friends',
    );
  }

  static AppNotification friendAccepted({
    required String userId,
    required String friendName,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.friendAccepted,
      title: tr('il_7e7ee1c623'),
      message: bilingual(
        '$friendName прийняв ваше запрошення в друзі',
        '$friendName accepted your friend request',
      ),
      data: {
        'friendName': friendName,
      },
      createdAt: DateTime.now(),
      actionUrl: '/friends',
    );
  }

  static AppNotification challengeInvite({
    required String userId,
    required String challengeTitle,
    required String challengeId,
    required String creatorName,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.challengeInvitation,
      title: tr('il_47f0651e42'),
      message: bilingual(
        '$creatorName запросив вас на челендж "$challengeTitle"',
        '$creatorName invited you to the "$challengeTitle" challenge',
      ),
      data: {
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'creatorName': creatorName,
      },
      createdAt: DateTime.now(),
      actionUrl: '/challenge-details/$challengeId',
    );
  }

  static AppNotification challengeResult({
    required String userId,
    required String challengeTitle,
    required String challengeId,
    required int position,
    required int coinsWon,
  }) {
    final ukPosition = position == 1 ? '🥇 1-е' : position == 2 ? '🥈 2-е' : '🥉 3-є';
    final enPosition = position == 1 ? '🥇 1st' : position == 2 ? '🥈 2nd' : '🥉 3rd';
    
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.challengeResult,
      title: tr('il_cba165efd4'),
      message: bilingual(
        'Ви зайняли $ukPosition місце в "$challengeTitle" і отримали $coinsWon монет!',
        'You finished $enPosition in "$challengeTitle" and earned $coinsWon coins!',
      ),
      data: {
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'position': position,
        'coinsWon': coinsWon,
      },
      createdAt: DateTime.now(),
      actionUrl: '/challenge-details/$challengeId',
    );
  }

  static AppNotification challengeCompleted({
    required String userId,
    required String challengeTitle,
    required String challengeId,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.challengeCompleted,
      title: tr('il_4d9daaed13'),
      message: bilingual(
        '«$challengeTitle» завершено. Переглянь результати.',
        '"$challengeTitle" just finished. Check out the winners.',
      ),
      data: {
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
      },
      createdAt: DateTime.now(),
      actionUrl: '/challenge-details/$challengeId',
    );
  }

  static AppNotification videoVote({
    required String userId,
    required String videoTitle,
    required String voterName,
    required double rating,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.videoVote,
      title: tr('il_e54105ee12'),
      message: bilingual(
        '$voterName оцінив ваше відео "$videoTitle" на ${rating.toStringAsFixed(1)} зірок',
        '$voterName rated your video "$videoTitle" ${rating.toStringAsFixed(1)} stars',
      ),
      data: {
        'videoTitle': videoTitle,
        'voterName': voterName,
        'rating': rating,
      },
      createdAt: DateTime.now(),
      actionUrl: '/video-main',
    );
  }

  // Ask to rate my videos
  static AppNotification ratingRequest({
    required String userId,
    required String fromUserName,
    required List<String> videoIds,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.ratingRequest,
      title: tr('il_89e35b78ef'),
      message: bilingual(
        '$fromUserName просить оцінити його відео (${videoIds.length} шт.)',
        '$fromUserName asks you to rate ${videoIds.length} video(s)',
      ),
      data: {
        'fromUserName': fromUserName,
        'videoIds': videoIds,
        'action': 'rate_videos',
      },
      createdAt: DateTime.now(),
      actionUrl: videoIds.isNotEmpty ? '/video/${videoIds.first}' : '/video-main',
    );
  }

  // Rating changed summary
  static AppNotification ratingChanged({
    required String userId,
    required String voterName,
    required double rating,
    required double delta,
    required double newRating,
    String? videoTitle,
  }) {
    final sign = delta >= 0 ? '+' : '';
    final hasVideo = videoTitle != null && videoTitle.isNotEmpty;
    final messageText = hasVideo
    ? bilingual(
        '$voterName оцінив ваше відео "$videoTitle" на ${rating.toStringAsFixed(2)}. Зміна: $sign${delta.toStringAsFixed(2)} → ${newRating.toStringAsFixed(2)}',
        '$voterName rated your video "$videoTitle" ${rating.toStringAsFixed(2)}. Change: $sign${delta.toStringAsFixed(2)} → ${newRating.toStringAsFixed(2)}',
      )
    : bilingual(
        'Ваш рейтинг було оновлено. Зміна: $sign${delta.toStringAsFixed(2)} → ${newRating.toStringAsFixed(2)}',
        'Your rating was updated. Change: $sign${delta.toStringAsFixed(2)} → ${newRating.toStringAsFixed(2)}',
      );
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.ratingChanged,
      title: tr('il_de9ad208de'),
      message: messageText,
      data: {
        'voterName': voterName,
        'rating': rating,
        'delta': delta,
        'newRating': newRating,
        'videoTitle': videoTitle ?? '',
      },
      createdAt: DateTime.now(),
      actionUrl: '/profile',
    );
  }

  static AppNotification teamInvite({
    required String userId,
    required String teamId,
    required String teamName,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.teamInvite,
      title: tr('il_03ff084400'),
      message: bilingual(
        'Вас запросили до команди "$teamName"',
        'You were invited to join "$teamName"',
      ),
      data: {
        'type': 'team_invite',
        'teamId': teamId,
        'teamName': teamName,
      },
      createdAt: DateTime.now(),
      actionUrl: '/profile',
    );
  }

  static AppNotification teamMatchRequest({
    required String userId,
    required String opponentTeamName,
    required String matchId,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.teamMatchRequest,
      title: tr('il_d55adbd76d'),
      message: bilingual(
        'Команда "$opponentTeamName" пропонує матч',
        'Team "$opponentTeamName" is challenging you to a match',
      ),
      data: {
        'type': 'team_match_request',
        'matchId': matchId,
        'opponentTeamName': opponentTeamName,
      },
      createdAt: DateTime.now(),
      actionUrl: '/match-details/$matchId',
    );
  }

  static AppNotification teamRosterInvite({
    required String userId,
    required String matchId,
    required String teamName,
    required String teamKey,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.teamRosterInvite,
      title: tr('il_61658c3091'),
      message: tr('il_f59dcb7976'),
      data: {
        'type': 'team_roster_invite',
        'matchId': matchId,
        'teamName': teamName,
        'teamKey': teamKey,
      },
      createdAt: DateTime.now(),
      actionUrl: '/match-details/$matchId',
    );
  }

  static AppNotification teamJoinRequest({
    required String userId,
    required String teamId,
    required String teamName,
    required String requesterName,
    required String requestId,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.teamJoinRequest,
      title: tr('il_1b52d0e324'),
      message: bilingual(
        '$requesterName хоче приєднатися до "$teamName"',
        '$requesterName wants to join "$teamName"',
      ),
      data: {
        'teamId': teamId,
        'teamName': teamName,
        'requesterName': requesterName,
        'requestId': requestId,
      },
      createdAt: DateTime.now(),
      actionUrl: '/teams',
    );
  }

  static AppNotification teamMatchReady({
    required String userId,
    required String matchId,
    required String teamAName,
    required String teamBName,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.teamMatchReady,
      title: tr('il_e30350b8a9'),
      message: tr('il_0d03de8d63'),
      data: {
        'type': 'team_match_ready',
        'matchId': matchId,
        'teamAName': teamAName,
        'teamBName': teamBName,
      },
      createdAt: DateTime.now(),
      actionUrl: '/match_management',
    );
  }

  static AppNotification badgeEarned({
    required String userId,
    required String badgeName,
    required String badgeEmoji,
    required String reason,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.badgeEarned,
      title: tr('il_40199c7b5f'),
      message: bilingual(
        'Ви отримали бейдж "$badgeEmoji $badgeName" за $reason',
        'You earned the "$badgeEmoji $badgeName" badge for $reason',
      ),
      data: {
        'badgeName': badgeName,
        'badgeEmoji': badgeEmoji,
        'reason': reason,
      },
      createdAt: DateTime.now(),
      actionUrl: '/profile',
    );
  }

  static AppNotification coinsEarned({
    required String userId,
    required int amount,
    required String reason,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.coinsEarned,
      title: tr('il_f3b024a55d'),
      message: bilingual(
        'Ви отримали $amount монет за $reason',
        'You earned $amount coins for $reason',
      ),
      data: {
        'amount': amount,
        'reason': reason,
      },
      createdAt: DateTime.now(),
      actionUrl: '/profile',
    );
  }
}
