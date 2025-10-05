import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';
import 'video_player_screen.dart';
import '../models/match.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23),
        elevation: 0,
        title: const Text(
          '🔔 Сповіщення',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read, color: Colors.white),
            onPressed: _markAllAsRead,
            tooltip: 'Позначити все як прочитане',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getUserNotifications(),
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
                    'Помилка завантаження',
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
                    label: const Text('Спробувати знову'),
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
          const Text(
            'Немає сповіщень',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Тут з\'являться ваші сповіщення\nпро друзів, челенджі та відео',
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
    return Container(
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
                                      'Позначити',
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
        dateKey = 'Сьогодні';
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        dateKey = 'Вчора';
      } else if (now.difference(date).inDays < 7) {
        final weekdays = ['Неділя', 'Понеділок', 'Вівторок', 'Середа', 'Четвер', 'П\'ятниця', 'Субота'];
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
    final priorityOrder = ['Сьогодні', 'Вчора'];
    
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
      await _notificationService.markAsRead(notification.id);
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
        print('🔔 NOTIFICATION: matchInvite clicked');
        print('🔔 NOTIFICATION: notification.data = ${notification.data}');
        final matchId = notification.data['matchId'] as String?;
        print('🔔 NOTIFICATION: extracted matchId = $matchId');
        if (matchId != null && matchId.isNotEmpty) {
          print('🔔 NOTIFICATION: Calling _openMatchById...');
          await _openMatchById(matchId);
          return;
        }
        // Fallback для старих сповіщень без matchId
        print('⚠️ NOTIFICATION: matchId is null, checking action...');
        final action = notification.data['action'] as String?;
        if (action == 'open_matches') {
          print('🔔 NOTIFICATION: Navigating to /matches (fallback)');
          Navigator.pushNamed(context, '/matches');
          return;
        }
        break;
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        _navigateToAction('/friends');
        return;
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
          const SnackBar(content: Text('Челендж не знайдено')),
        );
        return;
      }
      final challenge = Challenge.fromFirestore(doc);
      if (!mounted) return;
      Navigator.pushNamed(context, '/challenge-details', arguments: challenge);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка відкриття челенджу: $e')),
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
          SnackBar(content: Text('Матч не знайдено: $matchId')),
        );
        return;
      }
      final match = Match.fromFirestore(doc);
      print('🔍 NOTIFICATION: Match loaded: ${match.title}');
      if (!mounted) return;
      print('🔍 NOTIFICATION: Navigating to match-details...');
      Navigator.pushNamed(context, '/match-details', arguments: match);
      print('✅ NOTIFICATION: Navigation complete');
    } catch (e) {
      print('❌ NOTIFICATION: Error opening match: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка відкриття матчу: $e')),
      );
    }
  }
  void _navigateToAction(String actionUrl) {
    if (actionUrl.startsWith('/')) {
      if (actionUrl == '/friends') {
        Navigator.pushNamed(context, '/friends');
      } else if (actionUrl == '/profile') {
        Navigator.pushNamed(context, '/profile');
      } else if (actionUrl == '/video-main') {
        Navigator.pushNamed(context, '/video-main');
      } else if (actionUrl.startsWith('/video/')) {
        final videoId = actionUrl.split('/').last;
        _openVideoById(videoId);
      } else if (actionUrl.startsWith('/challenge-details/')) {
        final challengeId = actionUrl.split('/').last;
        Navigator.pushNamed(context, '/challenge-details', arguments: challengeId);
      }
    }
  }

  Future<void> _openVideoById(String videoId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Відео не знайдено')),
        );
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final videoUrl = (data['videoUrl'] ?? '').toString();
      final title = (data['title'] ?? 'Відео').toString();
      if (videoUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Посилання на відео відсутнє')),
        );
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: videoUrl,
            title: title,
            authorName: '',
            videoId: videoId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка відкриття відео: $e')),
      );
    }
  }

  void _markAsRead(AppNotification notification) async {
    await _notificationService.markAsRead(notification.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Позначено як прочитане'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _markAllAsRead() async {
    final success = await _notificationService.markAllAsRead();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Всі сповіщення позначені як прочитані'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteNotification(AppNotification notification) async {
    final success = await _notificationService.deleteNotification(notification.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сповіщення видалено'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}



