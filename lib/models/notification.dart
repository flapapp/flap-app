import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  friendRequest,
  friendAccepted,
  challengeInvitation,
  challengeUpdate,
  challengeResult,
  challengeCompleted,
  videoVote,
  matchInvite,
  matchFinished,
  badgeEarned,
  badgeEndorsed,
  coinsEarned,
  ratingRequest,
  ratingChanged,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;
  final String? imageUrl;
  final String? actionUrl;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.createdAt,
    this.isRead = false,
    this.imageUrl,
    this.actionUrl,
  });

  // Factory constructor from Firestore
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => NotificationType.friendRequest,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
    };
  }

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
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} дн. тому';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} год. тому';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} хв. тому';
    } else {
      return 'Щойно';
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
      title: 'Нове запрошення в друзі',
      message: '$fromUserName хоче додати вас у друзі',
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
      title: 'Запрошення прийнято!',
      message: '$friendName прийняв ваше запрошення в друзі',
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
      title: 'Запрошення на челендж',
      message: '$creatorName запросив вас на челендж "$challengeTitle"',
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
    final positionText = position == 1 ? '🥇 1-е' : position == 2 ? '🥈 2-е' : '🥉 3-є';
    
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.challengeResult,
      title: 'Результати челенджу!',
      message: 'Ви зайняли $positionText місце в "$challengeTitle" і отримали $coinsWon монет!',
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
      title: 'Нова оцінка відео',
      message: '$voterName оцінив ваше відео "$videoTitle" на ${rating.toStringAsFixed(1)} зірок',
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
      title: 'Запит оцінки відео',
      message: '$fromUserName просить оцінити його відео (${videoIds.length} шт.)',
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
        ? '$voterName оцінив ваше відео "$videoTitle" на ${rating.toStringAsFixed(2)}. Зміна: $sign${delta.toStringAsFixed(2)} → ${newRating.toStringAsFixed(2)}'
        : 'Ваш рейтинг було оновлено. Зміна: $sign${delta.toStringAsFixed(2)} → ${newRating.toStringAsFixed(2)}';
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.ratingChanged,
      title: 'Новий рейтинг',
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
      title: 'Новий бейдж!',
      message: 'Ви отримали бейдж "$badgeEmoji $badgeName" за $reason',
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
      title: 'Монети нараховано!',
      message: 'Ви отримали $amount монет за $reason',
      data: {
        'amount': amount,
        'reason': reason,
      },
      createdAt: DateTime.now(),
      actionUrl: '/profile',
    );
  }
}
