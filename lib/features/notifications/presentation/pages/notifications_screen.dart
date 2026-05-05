import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/di/injection.dart';
import '../../application/notification_router.dart';
import '../../data/models/notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../bloc/notification_bloc.dart';

@RoutePage()
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsRepository get _notificationsRepo => sl<NotificationsRepository>();
  late final NotificationBloc _notificationBloc;

  @override
  void initState() {
    super.initState();
    _notificationBloc = NotificationBloc(_notificationsRepo)
      ..add(const NotificationStarted());
  }

  @override
  void dispose() {
    _notificationBloc.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationBloc>.value(
      value: _notificationBloc,
      child: Scaffold(
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
        body: BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) {
            if (state is NotificationLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4caf50)),
              );
            }
            if (state is NotificationError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      tr('il_d68c419c3c'),
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context
                          .read<NotificationBloc>()
                          .add(const NotificationStarted()),
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
            final notifications =
                state is NotificationLoaded ? state.notifications : <AppNotification>[];
            if (notifications.isEmpty) return _buildEmptyState();
            return _buildNotificationsList(context, notifications);
          },
        ),
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

  Widget _buildNotificationsList(
    BuildContext context,
    List<AppNotification> notifications,
  ) {
    // Group notifications by date
    final groupedNotifications = _groupNotificationsByDate(context, notifications);
    
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
                          if (!notification.isRead)
                            GestureDetector(
                              onTap: () => _markAsRead(notification),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(notification.typeColor)
                                      .withOpacity(0.2),
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

  List<Map<String, dynamic>> _groupNotificationsByDate(
    BuildContext context,
    List<AppNotification> notifications,
  ) {
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
        dateKey = DateFormat.EEEE(context.locale.toString()).format(date);
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

  Future<void> _handleNotificationTap(AppNotification notification) async {
    if (!mounted) return;
    _notificationBloc.add(NotificationMarkReadRequested(notification.id));

    final ok = await NotificationRouter.navigateFromAppNotification(notification);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('something_went_wrong'))),
      );
    }
  }

  void _markAsRead(AppNotification notification) async {
    _notificationBloc.add(NotificationMarkReadRequested(notification.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('il_908aed4260')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _markAllAsRead() async {
    _notificationBloc.add(const NotificationMarkAllReadRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('il_7ff45c5f80')),
        backgroundColor: Colors.green,
      ),
    );
  }
}

