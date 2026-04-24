import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_auth.dart';
import '../../../../core/di/injection.dart';
import '../../../profile/presentation/profile_user_data_sync.dart';
import '../../../notifications/domain/repositories/notifications_repository.dart';
import '../../domain/entities/mode_navigation_target.dart';
import '../../domain/entities/mode_hero_stats.dart';
import '../cubit/mode_selection_cubit.dart';
import '../cubit/mode_selection_state.dart';
import '../navigation/mode_selection_router.dart';
import '../widgets/mode_art.dart';
import '../widgets/mode_card.dart';
import '../widgets/mode_hero_panel.dart';
import '../widgets/mode_news_section.dart';

@RoutePage()
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ModeSelectionCubit>(),
      child: const _ModeSelectionBody(),
    );
  }
}

class _ModeSelectionBody extends StatefulWidget {
  const _ModeSelectionBody();

  @override
  State<_ModeSelectionBody> createState() => _ModeSelectionBodyState();
}

class _ModeSelectionBodyState extends State<_ModeSelectionBody> {
  StreamSubscription<void>? _profileSyncSub;

  NotificationsRepository get _notificationsRepo => sl<NotificationsRepository>();

  @override
  void initState() {
    super.initState();
    _profileSyncSub = sl<ProfileUserDataSync>().onUpdated.listen((_) {
      if (!mounted) return;
      context.read<ModeSelectionCubit>().refreshProfileDocument();
    });
  }

  @override
  void dispose() {
    _profileSyncSub?.cancel();
    super.dispose();
  }

  String _matchesLabel(Map<String, dynamic>? data, ModeHeroStats? stats) {
    if (stats != null && stats.finishedMatchesPlayed > 0) {
      return stats.finishedMatchesPlayed.toString();
    }
    final raw = data?['totalMatches'] ?? data?['matches'] ?? data?['matchesPlayed'];
    if (raw is num) {
      return raw.toInt().toString();
    }
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f1923),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          BlocBuilder<ModeSelectionCubit, ModeSelectionState>(
            buildWhen: (a, b) => a.profileDocument != b.profileDocument,
            builder: (context, state) {
              final data = state.profileDocument;
              final rating = (data?['rating'] ?? 0.0).toDouble();
              return Row(
                children: [
                  Text(
                    '⭐ ${rating.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sports_soccer, color: Colors.white),
                    onPressed: () =>
                        context.pushModeTarget(ModeNavigationTarget.matches),
                  ),
                  IconButton(
                    icon: const Icon(Icons.video_collection, color: Colors.white),
                    onPressed: () =>
                        context.pushModeTarget(ModeNavigationTarget.videoMain),
                  ),
                  StreamBuilder<int>(
                    stream: _notificationsRepo.getUnreadCount(),
                    builder: (context, notifSnapshot) {
                      final unreadCount = notifSnapshot.data ?? 0;
                      return Stack(
                        children: [
                          IconButton(
                            tooltip: tr('notifications'),
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                            onPressed: () => context.pushModeTarget(
                              ModeNavigationTarget.notifications,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.person, color: Colors.white),
                    onPressed: () =>
                        context.pushModeTarget(ModeNavigationTarget.profile),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<ModeSelectionCubit, ModeSelectionState>(
            builder: (context, state) {
              final cubit = context.read<ModeSelectionCubit>();
              final data = state.profileDocument;
              const matchColors = [Color(0xFF0f9d58), Color(0xFF0c6f3c)];
              const videoColors = [Color(0xFFc62828), Color(0xFF8e24aa)];
              const teamColors = [Color(0xFF1976d2), Color(0xFF0d47a1)];

              final displayName = data?['displayName'] ??
                  data?['name'] ??
                  data?['authorName'] ??
                  data?['email']?.toString().split('@').first ??
                  tr('player');
              final avatarUrl =
                  (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString();
              final rating = (data?['rating'] ?? 0.0).toDouble();
              final coins = (data?['coins'] ?? data?['flCoins'] ?? 0).toString();

              return FutureBuilder<ModeHeroStats>(
                future: state.heroStatsFuture,
                builder: (context, snap) {
                  final stats = snap.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ModeHeroPanel(
                        cubit: cubit,
                        userId: AppAuth.currentUserId ?? '',
                        displayName: displayName,
                        avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                        rating: rating,
                        matchesLabel: _matchesLabel(data, stats),
                        coinsLabel: coins,
                        greeting: state.greetingText,
                        ratingLine: state.ratingLineText,
                        onRefreshGreeting: cubit.refreshGreeting,
                      ),
                      const SizedBox(height: 20),
                      ModeNewsSection(
                        loading: state.newsLoading,
                        items: state.newsItems,
                      ),
                      const SizedBox(height: 24),
                      ModeCard(
                        title: tr('matches'),
                        subtitle: tr('il_d090197fc0'),
                        highlights: [
                          tr('il_e64edb9f1e'),
                          tr('il_68442c9a0e'),
                          tr('il_a0921488a1'),
                        ],
                        icon: Icons.sports_soccer,
                        colors: matchColors,
                        badge: tr('il_25f50629be'),
                        actionLabel: tr('il_5a0f12a92f'),
                        illustration: const ModeArt(
                          type: ModeArtType.matches,
                          colors: matchColors,
                        ),
                        onTap: () =>
                            context.pushModeTarget(ModeNavigationTarget.matches),
                      ),
                      const SizedBox(height: 16),
                      ModeCard(
                        title: tr('videos'),
                        subtitle: tr('il_2862424bdc'),
                        highlights: [
                          tr('il_2f247110e8'),
                          tr('il_6a74de50d1'),
                          tr('il_8ca3167d86'),
                        ],
                        icon: Icons.video_collection,
                        colors: videoColors,
                        badge: tr('il_d9efc2bb26'),
                        actionLabel: tr('il_948ce0fcb1'),
                        illustration: const ModeArt(
                          type: ModeArtType.videos,
                          colors: videoColors,
                        ),
                        onTap: () => context.pushModeTarget(
                          ModeNavigationTarget.videoMain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ModeCard(
                        title: tr('il_1e1a1c078a'),
                        subtitle: tr('il_8d98f0bec9'),
                        highlights: [
                          tr('il_d8280e8655'),
                          tr('il_83be379446'),
                          tr('il_650d92acb0'),
                        ],
                        icon: Icons.groups_2,
                        colors: teamColors,
                        badge: tr('il_a595761987'),
                        actionLabel: tr('il_ff5d6ccdf0'),
                        illustration: const ModeArt(
                          type: ModeArtType.teams,
                          colors: teamColors,
                        ),
                        onTap: () =>
                            context.pushModeTarget(ModeNavigationTarget.teams),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
