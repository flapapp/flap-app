import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import '../../../../core/di/injection.dart';
import '../../../challenges/data/models/challenge.dart';
import '../../../matches/data/models/match.dart';
import '../../data/models/notification.dart';
import '../../../../router/app_router.dart';
import '../../domain/repositories/notifications_repository.dart';

@RoutePage()
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsRepository get _notificationsRepo => sl<NotificationsRepository>();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23),
        elevation: 0,
        title: Text(
          tr('il_209f1f8c24'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read, color: Colors.white),
            onPressed: _markAllAsRead,
            tooltip: tr('il_d7592650e1'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationsRepo.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4caf50)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('il_d68c419c3c'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: Text(tr('il_d8b8392e2c')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4caf50),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return _buildNotificationsList(notifications);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 60,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('il_cbce2040cc'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('il_66cbe43baa'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<AppNotification> notifications) {
    // Group notifications by date
    final groupedNotifications = _groupNotificationsByDate(notifications);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedNotifications.length,
      itemBuilder: (context, index) {
        final group = groupedNotifications[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                group['date'] as String,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Notifications for this date
            ...((group['notifications'] as List<AppNotification>)
                .map((notification) => _buildNotificationCard(notification))
                .toList()),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _notificationsRepo.deleteNotification(notification.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('il_e3f244f1ba')),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationTap(notification),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? Colors.white.withOpacity(0.03)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: notification.isRead
                      ? Colors.white.withOpacity(0.1)
                      : Color(notification.typeColor).withOpacity(0.3),
                  width: notification.isRead ? 1 : 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(notification.typeColor).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      notification.typeIcon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: notification.isRead 
                                    ? FontWeight.w500 
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(notification.typeColor),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            notification.timeAgo,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          // Action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!notification.isRead)
                                GestureDetector(
                                  onTap: () => _markAsRead(notification),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, 
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(notification.typeColor).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      tr('il_50c8b81faf'),
                                      style: TextStyle(
                                        color: Color(notification.typeColor),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _deleteNotification(notification),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupNotificationsByDate(List<AppNotification> notifications) {
    final groups = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    Map<String, List<AppNotification>> dateGroups = {};
    
    for (final notification in notifications) {
      final date = notification.createdAt;
      String dateKey;
      
      if (_isSameDay(date, now)) {
        dateKey = tr('il_2b065c7c9c');
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        dateKey = tr('il_566181254b');
      } else if (now.difference(date).inDays < 7) {
        final weekdays = currentAppLanguageCode() == 'en' 
            ? ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
            : ['Неділя', 'Понеділок', 'Вівторок', 'Середа', 'Четвер', 'П\'ятниця', 'Субота'];
        dateKey = weekdays[date.weekday % 7];
      } else {
        dateKey = '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      }
      
      if (!dateGroups.containsKey(dateKey)) {
        dateGroups[dateKey] = [];
      }
      dateGroups[dateKey]!.add(notification);
    }
    
    // Convert to list and maintain order
    final sortedKeys = dateGroups.keys.toList();
    final priorityOrder = [tr('il_2b065c7c9c'), tr('il_566181254b')];
    
    sortedKeys.sort((a, b) {
      final aIndex = priorityOrder.indexOf(a);
      final bIndex = priorityOrder.indexOf(b);
      
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      } else if (aIndex != -1) {
        return -1;
      } else if (bIndex != -1) {
        return 1;
      } else {
        return b.compareTo(a); // Reverse chronological for dates
      }
    });
    
    for (final key in sortedKeys) {
      groups.add({
        'date': key,
        'notifications': dateGroups[key]!,
      });
    }
    
    return groups;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _handleNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      await _notificationsRepo.markAsRead(notification.id);
    }

    if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) {
      final action = notification.actionUrl!;
      if (action.startsWith('/challenge-details/')) {
        final challengeId = action.split('/').last;
        await _openChallengeById(challengeId);
        return;
      }
      _navigateToAction(action);
      return;
    }

    // Fallback by type if actionUrl відсутній у старих записах
    switch (notification.type) {
      case NotificationType.challengeInvitation:
      case NotificationType.challengeUpdate:
      case NotificationType.challengeResult:
        final challengeId = notification.data['challengeId'] as String?;
        if (challengeId != null && challengeId.isNotEmpty) {
          await _openChallengeById(challengeId);
          return;
        }
        break;
        case NotificationType.matchInvite:
      final matchId = notification.data['matchId'] as String?;
      if (matchId != null && matchId.isNotEmpty) {
        await _openMatchById(matchId);
        return;
      }
      break;

    case NotificationType.matchFinished:
      final matchId = (notification.data['matchId'] ??
              notification.data['match_id'] ??
              notification.data['id']) as String?;
      if (matchId != null && matchId.isNotEmpty) {
        await _openMatchRatingById(matchId);
        return;
      }
      break;

      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        _navigateToAction('/friends');
        return;
      case NotificationType.teamRosterInvite:
        final rosterMatchId = notification.data['matchId'] as String?;
        if (rosterMatchId != null && rosterMatchId.isNotEmpty) {
          await _openMatchById(rosterMatchId);
          return;
        }
        break;
      default:
        _navigateToAction('/video-main');
        return;
    }
  }

  Future<void> _openChallengeById(String challengeId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('challenges').doc(challengeId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_a29799fa76'))),
        );
        return;
      }
      final challenge = Challenge.fromFirestore(doc);
      if (!mounted) return;
      context.router.push(ChallengeDetailsRoute(challenge: challenge));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_f5d8bd3f0a'))),
      );
    }
  }

    Future<void> _openMatchRatingById(String matchId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_6b539d4234'))),
        );
        return;
      }
      final match = Match.fromFirestore(doc);
      if (!mounted) return;
      context.router.push(MatchRatingRoute(match: match));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_5eda94340a'))),
      );
    }
  }

  
    Future<void> _openMatchById(String matchId) async {
    print('🔍 NOTIFICATION: Opening match with ID: $matchId');
    try {
      final doc = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();
      print('🔍 NOTIFICATION: Match doc exists: ${doc.exists}');
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_6b539d4234'))),
        );
        return;
      }
      final match = Match.fromFirestore(doc);
      print('🔍 NOTIFICATION: Match loaded: ${match.title}');
      if (!mounted) return;
      print('🔍 NOTIFICATION: Navigating to match-details...');
      context.router.push(MatchDetailsRoute(match: match));
      print('✅ NOTIFICATION: Navigation complete');
    } catch (e) {
      print('❌ NOTIFICATION: Error opening match: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_80c7341273'))),
      );
    }
  }
    void _navigateToAction(String actionUrl) {
    if (actionUrl.startsWith('/')) {
      if (actionUrl == '/friends') {
        context.router.push(const FriendsRoute());
      } else if (actionUrl == '/profile') {
        context.router.push(const ProfileRoute());
      } else if (actionUrl == '/video-main') {
        context.router.push(VideoMainRoute());
      } else if (actionUrl.startsWith('/video/')) {
        final videoId = actionUrl.split('/').last;
        _openVideoById(videoId);
      } else if (actionUrl.startsWith('/challenge-details/')) {
        final challengeId = actionUrl.split('/').last;
        _openChallengeById(challengeId);
      } else if (actionUrl.startsWith('/match/') && actionUrl.endsWith('/rate')) {
        final segments = actionUrl.split('/');
        if (segments.length >= 3) {
          final matchId = segments[2];
          _openMatchRatingById(matchId);
        }
      } else if (actionUrl.startsWith('/match-details/')) {
        final matchId = actionUrl.split('/').last;
        _openMatchById(matchId);
      }
    }
  }

  Future<void> _openVideoById(String videoId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_e861519b9c'))),
        );
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final videoUrl = (data['videoUrl'] ?? '').toString();
      final title = (data['title'] ?? tr('il_d534be829e')).toString();
      if (videoUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_e1bc626d15'))),
        );
        return;
      }
      if (!mounted) return;
      context.router.push(
        VideoPlayerRoute(
          videoUrl: videoUrl,
          title: title,
          authorName: '',
          videoId: videoId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_2e74389175'))),
      );
    }
  }

  void _markAsRead(AppNotification notification) async {
    await _notificationsRepo.markAsRead(notification.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('il_908aed4260')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _markAllAsRead() async {
    final success = await _notificationsRepo.markAllAsRead();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_7ff45c5f80')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteNotification(AppNotification notification) async {
    final success = await _notificationsRepo.deleteNotification(notification.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_f9caffd585')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}



