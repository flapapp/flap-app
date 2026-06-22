import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_auth.dart';
import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../matches/presentation/pages/matches_screen.dart';
import '../../../teams/presentation/pages/team_hub_screen.dart';
import '../../../video/presentation/pages/video_main_screen.dart';
import '../../../profile/presentation/pages/profile_screen.dart';
import '../../../profile/presentation/profile_user_data_sync.dart';
import '../../../notifications/domain/repositories/notifications_repository.dart';
import '../../domain/entities/mode_navigation_target.dart';
import '../../domain/entities/mode_hero_stats.dart';
import '../cubit/mode_selection_cubit.dart';
import '../cubit/mode_selection_state.dart';
import '../navigation/mode_selection_router.dart';
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

  // Bottom-nav tab shell. Tabs are built lazily on first visit and kept alive
  // by the IndexedStack so switching is instant and preserves state.
  static const List<String> _navIds = [
    'home',
    'matches',
    'videos',
    'teams',
    'profile',
  ];
  int _tab = 0;
  final Set<int> _visited = <int>{0};

  void _selectTab(int index) {
    if (index < 0 || index >= _navIds.length) return;
    setState(() {
      _tab = index;
      _visited.add(index);
    });
  }

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

  /// Position · city subtitle from the profile document, if present.
  String _subtitle(Map<String, dynamic>? data) {
    final parts = <String>[];
    final pos = (data?['position'] ?? data?['preferredPosition'] ?? '')
        .toString()
        .trim();
    final city =
        (data?['city'] ?? data?['location'] ?? '').toString().trim();
    if (pos.isNotEmpty) parts.add(pos);
    if (city.isNotEmpty) parts.add(city);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the active locale so the bottom-nav labels and the inline
    // Home tab re-localize instantly when the language is switched. `tr()` does
    // not register a dependency on the locale; the other tab screens (Matches /
    // Videos / Teams / Profile) each do the same read in their own build.
    context.locale;
    return Scaffold(
      backgroundColor: FlapColors.bg,
      body: IndexedStack(
        index: _tab,
        children: [
          _visited.contains(0) ? _buildHomeTab(context) : const SizedBox.shrink(),
          _visited.contains(1) ? const MatchesScreen() : const SizedBox.shrink(),
          _visited.contains(2) ? const VideoMainScreen() : const SizedBox.shrink(),
          _visited.contains(3) ? const TeamHubScreen() : const SizedBox.shrink(),
          _visited.contains(4) ? const ProfileScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: FlapBottomNav(
        activeId: _navIds[_tab],
        onSelect: (id) => _selectTab(_navIds.indexOf(id)),
        items: [
          FlapNavItem(
              icon: Icons.home_rounded,
              label: tr('mode_nav_home'),
              id: 'home'),
          FlapNavItem(
              icon: Icons.sports_soccer,
              label: tr('matches'),
              id: 'matches'),
          FlapNavItem(
              icon: Icons.play_arrow_rounded,
              label: tr('videos'),
              id: 'videos'),
          FlapNavItem(
              icon: Icons.shield_outlined,
              label: tr('il_1e1a1c078a'),
              id: 'teams'),
          FlapNavItem(
              icon: Icons.person_rounded,
              label: tr('profile'),
              id: 'profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return Stack(
      children: [
        // Radial green glow behind the top of the screen.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: FlapColors.screenGlow),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: BlocBuilder<ModeSelectionCubit, ModeSelectionState>(
                  builder: (context, state) {
                    final cubit = context.read<ModeSelectionCubit>();
                    final data = state.profileDocument;

                    final displayName = data?['displayName'] ??
                        data?['name'] ??
                        data?['authorName'] ??
                        data?['email']?.toString().split('@').first ??
                        tr('player');
                    final avatarUrl =
                        (data?['avatarUrl'] ?? data?['avatar'] ?? '')
                            .toString();
                    final rating = (data?['rating'] ?? 0.0).toDouble();
                    final coins =
                        (data?['coins'] ?? data?['flCoins'] ?? 0).toString();

                    return FutureBuilder<ModeHeroStats>(
                      future: state.heroStatsFuture,
                      builder: (context, snap) {
                        final stats = snap.data;
                        return ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                              child: ModeHeroPanel(
                                cubit: cubit,
                                userId: AppAuth.currentUserId ?? '',
                                displayName: displayName,
                                avatarUrl:
                                    avatarUrl.isNotEmpty ? avatarUrl : null,
                                subtitle: _subtitle(data),
                                rating: rating,
                                matchesLabel: _matchesLabel(data, stats),
                                coinsLabel: coins,
                              ),
                            ),
                            FlapSectionHeader(
                              title: tr('mode_for_you'),
                              actionLabel: tr('see_all'),
                              onAction: () => context.pushModeTarget(
                                  ModeNavigationTarget.notifications),
                              padding:
                                  const EdgeInsets.fromLTRB(22, 22, 22, 12),
                            ),
                            ModeNewsSection(
                              loading: state.newsLoading,
                              items: state.newsItems,
                            ),
                            FlapSectionHeader(
                              title: tr('mode_jump_in'),
                              padding:
                                  const EdgeInsets.fromLTRB(22, 22, 22, 12),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  ModeCard(
                                    title: tr('matches'),
                                    subtitle: tr('il_d090197fc0'),
                                    icon: Icons.sports_soccer,
                                    accent: FlapColors.green,
                                    onTap: () => _selectTab(1),
                                  ),
                                  const SizedBox(height: 12),
                                  ModeCard(
                                    title: tr('videos'),
                                    subtitle: tr('il_2862424bdc'),
                                    icon: Icons.play_arrow_rounded,
                                    accent: FlapColors.amber,
                                    onTap: () => _selectTab(2),
                                  ),
                                  const SizedBox(height: 12),
                                  ModeCard(
                                    title: tr('il_1e1a1c078a'),
                                    subtitle: tr('il_8d98f0bec9'),
                                    icon: Icons.shield_outlined,
                                    accent: FlapColors.blue,
                                    onTap: () => _selectTab(3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<ModeSelectionCubit, ModeSelectionState>(
      buildWhen: (a, b) => a.profileDocument != b.profileDocument,
      builder: (context, state) {
        final data = state.profileDocument;
        final displayName = (data?['displayName'] ??
                data?['name'] ??
                data?['authorName'] ??
                data?['email']?.toString().split('@').first ??
                tr('player'))
            .toString();
        final firstName = displayName.split(RegExp(r'\s+')).first;
        final avatarUrl =
            (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('welcome_back'),
                      style: FlapText.sora(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: FlapColors.muted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.21,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StreamBuilder<int>(
                stream: _notificationsRepo.getUnreadCount(),
                builder: (context, notifSnapshot) {
                  final unread = notifSnapshot.data ?? 0;
                  return FlapIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: tr('notifications'),
                    dot: unread > 0,
                    onTap: () => context
                        .pushModeTarget(ModeNavigationTarget.notifications),
                  );
                },
              ),
              const SizedBox(width: 12),
              PlayerAvatarButton(
                userId: AppAuth.currentUserId ?? '',
                displayName: displayName,
                avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                size: 42,
                backgroundColor: FlapColors.green,
                borderColor: FlapColors.green,
                borderWidth: 2,
                // Switch to the Profile tab rather than pushing a new screen.
                onTap: () => _selectTab(4),
              ),
            ],
          ),
        );
      },
    );
  }
}
