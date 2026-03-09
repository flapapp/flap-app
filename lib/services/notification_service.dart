import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification.dart';
import 'package:flutter/foundation.dart';
import '../models/match.dart' as app_models;
import '../utils/app_navigator.dart';
import '../utils/i18n.dart';
import 'user_settings_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Collection reference
  CollectionReference get _notificationsCollection => 
      _firestore.collection('notifications');

  // Initialize notifications
  Future<void> initialize() async {
    if (kIsWeb) {
     print('Running on web - skipping notification initialization');
     return;
   }
    try {
      if (!await UserSettingsService().isNotificationsEnabled()) {
        await _clearNotificationTokens();
        return;
      }

      print('Initializing NotificationService...');

      // Request permission for notifications
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        print('FCM token obtained: ${token.substring(0, 20)}...');
        await _saveFCMToken(token);
      } else {
        print('Failed to get FCM token');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveFCMToken);
      FirebaseAuth.instance.authStateChanges().listen((user) async {
  if (user != null) {
    if (await UserSettingsService().isNotificationsEnabled()) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
      }
    } else {
      await _clearNotificationTokens(user.uid);
    }
  }
});

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) {
  _handleNotificationTap(initial);
}

      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
  }

  // Save FCM token to user document
  Future<void> _saveFCMToken(String token) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      if (!await UserSettingsService().isNotificationsEnabled()) {
        await _clearNotificationTokens(currentUser.uid);
        return;
      }
      await _firestore.collection('users').doc(currentUser.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'deviceTokens': FieldValue.arrayUnion([token]),
      });
    }
  }

  Future<void> _clearNotificationTokens([String? uid]) async {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) return;
    await _firestore.collection('users').doc(userId).set({
      'fcmToken': FieldValue.delete(),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'deviceTokens': <String>[],
    }, SetOptions(merge: true));
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.notification?.title}');
    // Show in-app notification or update UI
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
  _navigateFromData(message.data);
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
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (!doc.exists) return;
      match = app_models.Match.fromFirestore(doc);
    } catch (_) {
      return;
    }
  }

  final nav = AppNavigator.navigatorKey.currentState;
  if (nav == null) return;

  switch (type) {
    case 'match_invite':
    case 'match_application_accepted':
    case 'match_application_rejected':
      if (match != null) {
        nav.pushNamed('/match-details', arguments: match);
      }
      break;
    case 'match_finished':
    case 'match_application_submitted':
      if (match != null) {
        nav.pushNamed('/match_management', arguments: match);
      }
      break;
    case 'team_match_request':
      if (match != null) {
        nav.pushNamed('/match-details', arguments: match);
      }
      break;
    case 'team_roster_invite':
      if (match != null) {
        nav.pushNamed('/match-details', arguments: match);
      }
      break;
    case 'team_match_ready':
      if (match != null) {
        nav.pushNamed('/match_management', arguments: match);
      }
      break;
    case 'team_invite':
      nav.pushNamed('/profile');
      break;
  }
}

  // Send notification to user
  Future<bool> sendNotification(AppNotification notification) async {
    try {
      // Save notification to Firestore
      final docRef = await _notificationsCollection.add(notification.toFirestore());
      
      // Send push notification via Cloud Function
      await _firestore.collection('pushNotifications').add({
        'userId': notification.userId,
        'title': notification.title,
        'message': notification.message,
        'data': notification.data,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  // Get user's notifications
  Stream<List<AppNotification>> getUserNotifications() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Simplified query to avoid composite index requirement
    return _notificationsCollection
        .where('userId', isEqualTo: currentUser.uid)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          print('Notifications loaded: ${snapshot.docs.length} documents');
          final notifications = snapshot.docs
              .map((doc) {
                try {
                  return AppNotification.fromFirestore(doc);
                } catch (e) {
                  print('Error parsing notification ${doc.id}: $e');
                  return null;
                }
              })
              .where((notification) => notification != null)
              .cast<AppNotification>()
              .toList();
          
          // Sort on client side to avoid index requirement
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        })
        .handleError((error) {
          print('Error loading notifications: $error');
          return [];
        });
  }

  // Get unread notifications count
  Stream<int> getUnreadCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final batch = _firestore.batch();
      final unreadNotifications = await _notificationsCollection
          .where('userId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
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
      final batch = _firestore.batch();
      
      for (final notification in notifications) {
        final docRef = _notificationsCollection.doc();
        batch.set(docRef, notification.toFirestore());
        
        // Also queue for push notification
        final pushRef = _firestore.collection('pushNotifications').doc();
        batch.set(pushRef, {
          'userId': notification.userId,
          'title': notification.title,
          'message': notification.message,
          'data': notification.data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error sending bulk notifications: $e');
      return false;
    }
  }

  // Get notification statistics
  Future<Map<String, int>> getNotificationStats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return {};

      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final stats = <String, int>{};
      
      for (final doc in notifications.docs) {
        final notification = AppNotification.fromFirestore(doc);
        final typeKey = notification.type.toString().split('.').last;
        stats[typeKey] = (stats[typeKey] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting notification stats: $e');
      return {};
    }
  }

  // Clear old notifications (older than 30 days)
  Future<bool> clearOldNotifications() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final oldNotifications = await _notificationsCollection
          .where('userId', isEqualTo: currentUser.uid)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
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
  final localizedTitle = title ?? I18n.inline('Запрошення на матч', 'Match invitation');
  final localizedBody = body ?? I18n.inline('$organizerName запросив(ла) вас на матч',
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