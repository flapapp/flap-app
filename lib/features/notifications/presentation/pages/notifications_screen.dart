import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
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
        backgroundColor: FlapColors.bg,
        appBar: AppBar(
          backgroundColor: FlapColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 66,
          leadingWidth: 60,
          titleSpacing: 0,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _glassIconButton(
                  Icons.chevron_left, () => Navigator.pop(context)),
            ),
          ),
          title: Text(
            tr('il_209f1f8c24'),
            style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _glassIconButton(
                Icons.done_all_rounded,
                _markAllAsRead,
                size: 18,
                tooltip: tr('il_d7592650e1'),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
          child: BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state is NotificationLoading) {
                return _buildLoadingSkeleton();
              }
              if (state is NotificationError) {
                return _buildErrorState(context, state.message);
              }
              final notifications = state is NotificationLoaded
                  ? state.notifications
                  : <AppNotification>[];
              if (notifications.isEmpty) return _buildEmptyState();
              return _buildNotificationsList(context, notifications);
            },
          ),
        ),
      ),
    );
  }

  Widget _glassIconButton(IconData icon, VoidCallback onTap,
      {double size = 19, String? tooltip}) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: FlapColors.border),
        ),
        child: Icon(icon, color: FlapColors.text, size: size),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  // ── States ─────────────────────────────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    return FlapShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlapColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlapColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FlapSkeletonBox(width: 44, height: 44, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    FlapSkeletonBox(width: 150, height: 13, radius: 6),
                    SizedBox(height: 9),
                    FlapSkeletonBox(width: double.infinity, height: 11, radius: 6),
                    SizedBox(height: 6),
                    FlapSkeletonBox(width: 80, height: 10, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlapColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 40, color: FlapColors.red),
            ),
            const SizedBox(height: 20),
            Text(
              tr('il_d68c419c3c'),
              style: FlapText.sora(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => context
                  .read<NotificationBloc>()
                  .add(const NotificationStarted()),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  gradient: FlapColors.primaryButton,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: FlapColors.onGreen, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      tr('il_d8b8392e2c'),
                      style: FlapText.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FlapColors.onGreen),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlapColors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: FlapColors.green.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 46, color: FlapColors.greenBright),
            ),
            const SizedBox(height: 22),
            Text(
              tr('il_cbce2040cc'),
              style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              tr('il_66cbe43baa'),
              textAlign: TextAlign.center,
              style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────

  Widget _buildNotificationsList(
    BuildContext context,
    List<AppNotification> notifications,
  ) {
    final groupedNotifications =
        _groupNotificationsByDate(context, notifications);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: groupedNotifications.length,
      itemBuilder: (context, index) {
        final group = groupedNotifications[index];
        final items = group['notifications'] as List<AppNotification>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
              child: Text(
                (group['date'] as String).toUpperCase(),
                style: FlapText.sora(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: FlapColors.muted2,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final notification in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildNotificationCard(notification),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final accent = _accentFor(notification.type);
    final unread = !notification.isRead;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread
                ? accent.withValues(alpha: 0.07)
                : FlapColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.35)
                  : FlapColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Typed icon tile.
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Icon(_iconFor(notification.type),
                    color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: FlapText.sora(
                              fontSize: 14.5,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: FlapText.sora(
                          fontSize: 13,
                          color: const Color(0xFFC2CAC4),
                          height: 1.35),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          notification.timeAgo,
                          style: FlapText.sora(
                              fontSize: 11.5, color: FlapColors.muted),
                        ),
                        const Spacer(),
                        if (unread)
                          GestureDetector(
                            onTap: () => _markAsRead(notification),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                tr('il_50c8b81faf'),
                                style: FlapText.sora(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
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
    );
  }

  /// Maps each notification type to a Material icon (design uses typed glyphs
  /// rather than the model's emoji).
  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.friendAccepted:
        return Icons.how_to_reg_rounded;
      case NotificationType.challengeInvitation:
        return Icons.bolt_rounded;
      case NotificationType.challengeUpdate:
        return Icons.videocam_rounded;
      case NotificationType.challengeResult:
        return Icons.emoji_events_rounded;
      case NotificationType.challengeCompleted:
        return Icons.celebration_rounded;
      case NotificationType.videoVote:
        return Icons.star_rounded;
      case NotificationType.matchInvite:
        return Icons.sports_soccer_rounded;
      case NotificationType.matchFinished:
        return Icons.sports_score_rounded;
      case NotificationType.badgeEarned:
        return Icons.military_tech_rounded;
      case NotificationType.badgeEndorsed:
        return Icons.thumb_up_alt_rounded;
      case NotificationType.coinsEarned:
        return Icons.monetization_on_rounded;
      case NotificationType.ratingRequest:
        return Icons.rate_review_rounded;
      case NotificationType.ratingChanged:
        return Icons.trending_up_rounded;
      case NotificationType.teamInvite:
        return Icons.groups_rounded;
      case NotificationType.teamMatchRequest:
        return Icons.sports_soccer_rounded;
      case NotificationType.teamRosterInvite:
        return Icons.assignment_ind_rounded;
      case NotificationType.teamMatchReady:
        return Icons.sports_score_rounded;
      case NotificationType.teamJoinRequest:
        return Icons.group_add_rounded;
    }
  }

  /// Maps each type to a Flap-palette accent so the list stays on-brand.
  Color _accentFor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
      case NotificationType.challengeUpdate:
      case NotificationType.matchFinished:
      case NotificationType.ratingRequest:
      case NotificationType.teamInvite:
      case NotificationType.teamMatchReady:
      case NotificationType.teamJoinRequest:
        return FlapColors.blue;
      case NotificationType.friendAccepted:
      case NotificationType.challengeCompleted:
      case NotificationType.matchInvite:
      case NotificationType.teamMatchRequest:
        return FlapColors.greenBright;
      case NotificationType.challengeInvitation:
      case NotificationType.teamRosterInvite:
        return FlapColors.amber;
      case NotificationType.challengeResult:
      case NotificationType.videoVote:
      case NotificationType.badgeEarned:
      case NotificationType.badgeEndorsed:
      case NotificationType.coinsEarned:
      case NotificationType.ratingChanged:
        return FlapColors.gold;
    }
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
        backgroundColor: FlapColors.green,
      ),
    );
  }
}
