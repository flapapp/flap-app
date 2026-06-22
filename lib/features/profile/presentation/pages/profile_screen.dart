import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/football_position.dart';
import 'package:flap_app/city_localization.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import 'package:flap_app/features/badges/presentation/badge_icon.dart';
import '../../../../widgets/team_crest.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../../badges/data/models/badge.dart' as app_badge;
import '../../../teams/data/models/app_team.dart';
import '../../../teams/data/models/team_invite.dart';
import '../../domain/repositories/match_participation_stats_repository.dart';
import '../../domain/repositories/player_badge_endorsement_repository.dart';
import '../../domain/repositories/player_social_repository.dart';
import '../../domain/repositories/profile_team_membership_repository.dart';
import '../../domain/repositories/user_badges_repository.dart';
import '../bloc/profile_bloc.dart';
import '../cubit/profile_overview_cubit.dart';

@RoutePage()
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sl<ProfileBloc>().add(const ProfileEvent.started());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<ProfileBloc>(),
      child: const _ProfileScreenBody(),
    );
  }
}

class _ProfileScreenBody extends StatefulWidget {
  const _ProfileScreenBody();

  @override
  State<_ProfileScreenBody> createState() => _ProfileScreenBodyState();
}

class _ProfileScreenBodyState extends State<_ProfileScreenBody> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ProfileOverviewCubit _overviewCubit;
  Future<Map<String, dynamic>>? _matchStatsFuture;
  String? _matchStatsUserId;
  int _badgeEndorseVersion = 0;

  @override
  void initState() {
    super.initState();
    _overviewCubit = ProfileOverviewCubit(
      authSessionRepository: sl<AuthSessionRepository>(),
      userBadgesRepository: sl<UserBadgesRepository>(),
      playerSocialRepository: sl<PlayerSocialRepository>(),
      teamMembershipRepository: sl<ProfileTeamMembershipRepository>(),
    )..initialize();
  }

  @override
  void dispose() {
    _overviewCubit.close();
    super.dispose();
  }

  Widget _buildTeamsSection() {
    return BlocBuilder<ProfileOverviewCubit, ProfileOverviewState>(
      bloc: _overviewCubit,
      builder: (context, overview) {
        final teams = overview.teams;
        final myUid = overview.userId ??
            sl<AuthSessionRepository>().peekCurrentUser?.uid ??
            '';
        final canCreate = teams.length < 3;
        final loading = overview.status == ProfileOverviewStatus.loading;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Friends section ----
              _sectionHeader(
                tr('profile_friends_row'),
                action: tr('profile_open'),
                onAction: _openFriends,
              ),
              const SizedBox(height: 12),
              _memberRow(
                leading: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FlapColors.blue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border:
                        Border.all(color: FlapColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.group_outlined,
                      size: 18, color: FlapColors.blue),
                ),
                title: tr('profile_friends_row'),
                subtitle: tr('profile_friends_connected',
                    namedArgs: {'count': '${overview.friendsCount}'}),
                onTap: _openFriends,
              ),

              // ---- My clubs section ----
              const SizedBox(height: 10),
              _sectionHeader(
                tr('profile_my_clubs'),
                action: tr('profile_open'),
                onAction: () => context.router.push(const TeamHubRoute()),
              ),
              const SizedBox(height: 12),
              if (loading && teams.isEmpty)
                FlapShimmer(
                  child: Column(
                    children: List.generate(
                      2,
                      (_) => Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: FlapColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: FlapColors.border),
                        ),
                        child: Row(
                          children: const [
                            FlapSkeletonBox(width: 36, height: 36, radius: 10),
                            SizedBox(width: 11),
                            Expanded(
                              child: FlapSkeletonBox(height: 12, radius: 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                for (final team in teams)
                  _memberRow(
                    leading: TeamCrest(
                      teamId: team.id,
                      teamName: team.name,
                      size: 36,
                      borderRadius: 11,
                    ),
                    title: team.name,
                    subtitle: _clubSubtitle(team, myUid),
                    onTap: () => context.router
                        .push(TeamDetailsRoute(teamId: team.id)),
                  ),
                if (canCreate)
                  _memberRow(
                    leading: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FlapColors.green.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: FlapColors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.add,
                          size: 18, color: FlapColors.greenBright),
                    ),
                    title: tr('profile_create_club'),
                    subtitle: null,
                    onTap: () async {
                      final created = await context.router.push<bool>(
                        TeamCreateRoute(existingTeams: teams.length),
                      );
                      if (!context.mounted) return;
                      if (created == true) {
                        await _overviewCubit.refreshTeamsFromServer();
                      }
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title,
      {String? action, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action,
                style: FlapText.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.greenBright)),
          ),
      ],
    );
  }

  String _clubSubtitle(AppTeam team, String myUid) {
    final String role = team.captainId == myUid
        ? tr('il_2e786c488b') // Captain
        : team.viceCaptainIds.contains(myUid)
            ? tr('il_9a9036ab0f') // Vice
            : tr('il_67d783e9bb'); // Squad member
    final String city = (team.city ?? '').trim();
    return city.isEmpty ? role : '$role · ${localizeCity(city)}';
  }

  Widget _memberRow({
    required Widget leading,
    required String title,
    required String? subtitle,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: FlapColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlapColors.border),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? FlapColors.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 11.5, color: FlapColors.muted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: FlapColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildViewStatsButton(Map<String, dynamic> userData) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: FlapColors.primaryButton,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openStats(userData),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.show_chart,
                        size: 18, color: FlapColors.onGreen),
                    const SizedBox(width: 8),
                    Text(tr('profile_view_stats'),
                        style: FlapText.sora(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: FlapColors.onGreen)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInvitesSection() {
    return BlocBuilder<ProfileOverviewCubit, ProfileOverviewState>(
      bloc: _overviewCubit,
      builder: (context, overview) {
        final invites = overview.invites;
        if (invites.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('il_c0d5f0a05a'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...invites.map(_buildInviteCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInviteCard(TeamInvite invite) {
    return FutureBuilder<AppTeam?>(
      future: sl<ProfileTeamMembershipRepository>().getTeam(invite.teamId),
      builder: (context, snapshot) {
        final team = snapshot.data;
        final logoUrl = (team?.logoUrl ?? '').toString();
        final city = (team?.city ?? '').toString();
        final motto =
            (team?.description.isNotEmpty == true ? team!.description : null) ??
            tr('il_e6c2280de7');
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      context.router.push(
                        TeamDetailsRoute(teamId: invite.teamId),
                      );
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF0E1310),
                      backgroundImage: logoUrl.isNotEmpty
                          ? NetworkImage(logoUrl)
                          : null,
                      child: logoUrl.isEmpty
                          ? Text(
                              invite.teamName.isNotEmpty
                                  ? invite.teamName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_rounded,
                                  size: 13, color: Colors.white70),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  localizeCity(city),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          motto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 320;
                  final cancelButton = TextButton(
                    onPressed: () async {
                      await sl<ProfileTeamMembershipRepository>()
                          .respondToInvite(invite: invite, accept: false);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(tr('cancel')),
                  );
                  final joinButton = ElevatedButton(
                    onPressed: () async {
                      try {
                        await sl<ProfileTeamMembershipRepository>()
                            .respondToInvite(invite: invite, accept: true);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('il_b7b3f790f9'))),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                'il_e69e7edfdf',
                                namedArgs: {'e': e.toString()},
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: const Color(0xFF041013),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(tr('il_fd30fe681b')),
                  );
                  if (isTight) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cancelButton,
                        const SizedBox(height: 8),
                        joinButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      cancelButton,
                      const SizedBox(width: 12),
                      joinButton,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the active locale so this screen re-localizes the instant the
    // language is switched (e.g. from the Settings page). `tr()` does not
    // register a dependency on the locale, and this screen lives in the
    // always-alive tab-shell IndexedStack — so without this read it would only
    // reflect a new language after an app restart.
    context.locale;
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFF0E1310),
          drawer: _buildProfileDrawer(state.profile?.legacyUserData),
          body: _buildProfileBody(state),
        );
      },
    );
  }

  Widget _buildProfileBody(ProfileState state) {
    if (state.streamProgress == ProgressStatus.loading &&
        state.profile == null) {
      return _buildProfileSkeleton();
    }
    if (state.streamFailure != null && state.profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.streamFailure.toString(),
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (state.profile == null) {
      return Center(
        child: Text(
          tr('profile_not_found'),
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    return _buildProfileContent(state.profile!.legacyUserData);
  }

  Widget _buildProfileSkeleton() {
    Widget label() => const FlapSkeletonBox(width: 116, height: 16, radius: 7);
    return IgnorePointer(
      child: FlapShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App bar (menu + title) over the header gradient.
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF13241B), FlapColors.bg],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: const [
                        FlapSkeletonBox(width: 28, height: 28, radius: 9),
                        SizedBox(width: 12),
                        FlapSkeletonBox(width: 96, height: 22, radius: 7),
                      ],
                    ),
                  ),
                ),
              ),
              // Profile top: avatar + name + sub.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    FlapSkeletonBox(width: 96, height: 96, radius: 48),
                    SizedBox(height: 14),
                    FlapSkeletonBox(width: 150, height: 22, radius: 8),
                    SizedBox(height: 10),
                    FlapSkeletonBox(width: 180, height: 14, radius: 7),
                  ],
                ),
              ),
              // Rating card.
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: FlapSkeletonBox(
                    width: double.infinity, height: 92, radius: 18),
              ),
              // Wallet + stat grid.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  children: const [
                    FlapSkeletonBox(
                        width: double.infinity, height: 64, radius: 16),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: FlapSkeletonBox(height: 72, radius: 16)),
                        SizedBox(width: 12),
                        Expanded(child: FlapSkeletonBox(height: 72, radius: 16)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: FlapSkeletonBox(height: 72, radius: 16)),
                        SizedBox(width: 12),
                        Expanded(child: FlapSkeletonBox(height: 72, radius: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Badges strip.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: label(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: const [
                    FlapSkeletonBox(width: 86, height: 86, radius: 16),
                    SizedBox(width: 12),
                    FlapSkeletonBox(width: 86, height: 86, radius: 16),
                    SizedBox(width: 12),
                    FlapSkeletonBox(width: 86, height: 86, radius: 16),
                    SizedBox(width: 12),
                    FlapSkeletonBox(width: 86, height: 86, radius: 16),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Teams / members section.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: label(),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    FlapSkeletonBox(
                        width: double.infinity, height: 64, radius: 16),
                    SizedBox(height: 12),
                    FlapSkeletonBox(
                        width: double.infinity, height: 64, radius: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ensureMatchStatsFuture(String userId) {
    if (userId.isEmpty) return;
    if (_matchStatsUserId == userId && _matchStatsFuture != null) return;
    _matchStatsUserId = userId;
    _matchStatsFuture = sl<MatchParticipationStatsRepository>()
        .loadFinishedMatchStats(userId);
  }

  Widget _buildProfileContent(Map<String, dynamic> userData) {
    final displayName =
        userData['name'] ?? userData['displayName'] ?? tr('player');
    final avatarUrl = userData['avatar'] ?? userData['avatarUrl'];
    final rating = (userData['rating'] ?? 0.0).toDouble();
    final matchRating = (userData['matchRating'] ?? rating).toDouble();
    final videoRating = (userData['videoRating'] ?? rating).toDouble();
    final profileUserId = userData['uid'] ??
        sl<AuthSessionRepository>().peekCurrentUser?.uid ??
        '';
    if (profileUserId.isNotEmpty) {
      _ensureMatchStatsFuture(profileUserId);
    }
    final statsFuture = _matchStatsFuture;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: FlapColors.bg,
          title: Text(tr('profile'),
              style: FlapText.sora(fontSize: 22, fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 24, color: FlapColors.text),
            tooltip: tr('profile_more'),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          leadingWidth: 52,
          titleSpacing: 4,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF13241B), FlapColors.bg],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildProfileTop(userData, displayName, avatarUrl, rating),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: _buildRatingCard(rating, matchRating, videoRating),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildStatsCards(userData, statsFuture),
              _buildBadgesSection(userData),
              const SizedBox(height: 22),
              _buildTeamsSection(),
              _buildViewStatsButton(userData),
              const SizedBox(height: 20),
              _buildTeamInvitesSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  String _tierLabel(double r) {
    if (r >= 4.6) return tr('tier_pro');
    if (r >= 4.0) return tr('tier_semipro');
    if (r >= 3.0) return tr('tier_amateur');
    return tr('tier_rookie');
  }

  Widget _buildProfileTop(
    Map<String, dynamic> userData,
    String displayName,
    String? avatarUrl,
    double rating,
  ) {
    final pos = positionLabelForDisplay(userData['position']?.toString());
    final city = localizeCity((userData['city'] ?? '').toString());
    final sub = [pos, city].where((e) => e.trim().isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: FlapColors.green, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildAvatarPlaceholder(displayName),
                    )
                  : _buildAvatarPlaceholder(displayName),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.place_outlined,
                    size: 13, color: FlapColors.muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: FlapColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FlapColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 13, color: FlapColors.gold),
                const SizedBox(width: 6),
                Text(
                  _tierLabel(rating),
                  style: FlapText.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FlapColors.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(
      double rating, double matchRating, double videoRating) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rating.toStringAsFixed(1),
                  style: FlapText.cond(fontSize: 46, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text('/5',
                    style:
                        FlapText.sora(fontSize: 14, color: FlapColors.muted)),
              ),
              const Spacer(),
              Text(tr('profile_overall_rating'),
                  style: FlapText.sora(fontSize: 12, color: FlapColors.muted)),
            ],
          ),
          const SizedBox(height: 16),
          _ratingBreakdownRow(Icons.sports_soccer, tr('profile_rating_match'),
              '70%', matchRating),
          const SizedBox(height: 10),
          _ratingBreakdownRow(Icons.play_arrow_rounded,
              tr('profile_rating_video'), '30%', videoRating),
        ],
      ),
    );
  }

  Widget _ratingBreakdownRow(
      IconData icon, String label, String weight, double value) {
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Row(
            children: [
              Icon(icon, size: 14, color: FlapColors.greenBright),
              const SizedBox(width: 6),
              Text(label,
                  style: FlapText.sora(fontSize: 12, color: FlapColors.muted)),
              const SizedBox(width: 5),
              Text(weight,
                  style: FlapText.sora(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (value / 5).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0x14FFFFFF),
              valueColor: const AlwaysStoppedAnimation(FlapColors.green),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 26,
          child: Text(value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style:
                  FlapText.sora(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildStatsCards(
    Map<String, dynamic> userData,
    Future<Map<String, dynamic>>? statsFuture,
  ) {
    final uid = userData['uid'] ??
        sl<AuthSessionRepository>().peekCurrentUser?.uid ??
        '';
    final resolvedFuture = statsFuture ??
        sl<MatchParticipationStatsRepository>().loadFinishedMatchStats(uid);
    final coins = (userData['coins'] ?? 0) as num;

    return FutureBuilder<Map<String, dynamic>>(
      future: resolvedFuture,
      builder: (context, statsSnap) {
        final sm = statsSnap.data;
        final played = (sm?['matches'] as num?)?.toInt() ??
            ((userData['matchesPlayed'] ??
                    userData['totalMatches'] ??
                    userData['matches'] ??
                    0) as num)
                .toInt();
        final winRate = ((sm?['winRate'] as num?) ?? 0).round();
        final goals = (sm?['totalGoals'] as num?)?.toInt() ??
            ((userData['goals'] ?? 0) as num).toInt();
        final videos = ((userData['videosUploaded'] ?? 0) as num).toInt();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            children: [
              _walletCard(coins),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _pstat(
                      played.toString(),
                      tr('profile_matches_played'),
                      onTap: () =>
                          context.router.push(MatchesRoute(initialTabIndex: 1)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pstat('$winRate%', tr('profile_win_rate_label'),
                        valueColor: FlapColors.greenBright),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _pstat('$goals', tr('profile_goals_scored'),
                        valueColor: FlapColors.gold,
                        icon: Icons.sports_soccer),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pstat('$videos', tr('videos'),
                        onTap: () => context.router
                            .push(VideoMainRoute(myContent: 'videos'))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _walletCard(num coins) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on,
                        size: 22, color: FlapColors.gold),
                    const SizedBox(width: 8),
                    Text(_formatCoins(coins),
                        style: FlapText.cond(fontSize: 26, height: 1)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(tr('profile_coins_balance'),
                    style: FlapText.sora(fontSize: 12, color: FlapColors.muted)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showSettings,
            style: OutlinedButton.styleFrom(
              foregroundColor: FlapColors.text,
              side: const BorderSide(color: FlapColors.borderStrong),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(tr('profile_top_up'),
                style:
                    FlapText.sora(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _pstat(
    String value,
    String label, {
    Color valueColor = FlapColors.text,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: valueColor),
                  const SizedBox(width: 5),
                ],
                Text(value,
                    style:
                        FlapText.cond(fontSize: 24, height: 1, color: valueColor)),
              ],
            ),
            const SizedBox(height: 6),
            Text(label,
                style: FlapText.sora(fontSize: 11.5, color: FlapColors.muted)),
          ],
        ),
      ),
    );
  }

  String _formatCoins(num c) {
    final str = c.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  Widget _buildBadgesSection(Map<String, dynamic> userData) {
    final String userId = userData['uid'] ??
        sl<AuthSessionRepository>().peekCurrentUser?.uid ??
        '';
    return BlocBuilder<ProfileOverviewCubit, ProfileOverviewState>(
      bloc: _overviewCubit,
      builder: (context, overview) {
        final badges = overview.badges;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('il_66d0f523a3'),
                      style: FlapText.sora(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: _openBadgesStore,
                    child: Text(tr('il_9fd728c66c'),
                        style: FlapText.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: FlapColors.greenBright)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (overview.status == ProfileOverviewStatus.loading &&
                  badges.isEmpty)
                SizedBox(
                  height: 112,
                  child: FlapShimmer(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, __) => Container(
                        width: 86,
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
                        decoration: BoxDecoration(
                          color: FlapColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FlapColors.border),
                        ),
                        child: Column(
                          children: const [
                            FlapSkeletonBox(width: 48, height: 48, radius: 15),
                            SizedBox(height: 9),
                            FlapSkeletonBox(height: 10, radius: 5),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (badges.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: FlapColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FlapColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events_outlined,
                          size: 44, color: FlapColors.muted),
                      const SizedBox(height: 8),
                      Text(tr('il_32ae9b80f8'),
                          textAlign: TextAlign.center,
                          style: FlapText.sora(
                              fontSize: 13, color: FlapColors.muted)),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    clipBehavior: Clip.none,
                    itemCount: badges.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _badgeTile(userId, badges[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _badgeTile(String userId, dynamic badge) {
    final c = Color(badge.categoryColor);
    return GestureDetector(
      onTap: () => _endorseBadge(userId, badge),
      child: Container(
        width: 86,
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: c.withValues(alpha: 0.34)),
                  ),
                  child: Icon(flapBadgeIcon(badge.emoji), size: 22, color: c),
                ),
                Positioned(
                  top: -5,
                  right: -7,
                  child: FutureBuilder<BadgeEndorsementInfo>(
                    key: ValueKey(
                        'badge-endorse-${badge.id}-$_badgeEndorseVersion'),
                    future: sl<PlayerBadgeEndorsementRepository>()
                        .getEndorsementInfo(
                      ownerUserId: userId,
                      badgeId: badge.id,
                      currentUserId:
                          sl<AuthSessionRepository>().peekCurrentUser?.uid,
                    ),
                    builder: (context, snap) {
                      final count = snap.data?.count ?? 0;
                      if (count <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: FlapColors.blue,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: FlapColors.bg, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.thumb_up,
                                size: 8, color: Colors.white),
                            const SizedBox(width: 2),
                            Text('$count',
                                style: FlapText.sora(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              badge.localizedName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FlapText.sora(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDrawer(Map<String, dynamic>? userData) {
    // Close the drawer first, then run the action on the next frame so the
    // pop animation doesn't race the pushed route.
    void run(VoidCallback action) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    }

    final displayName = (userData?['name'] ??
            userData?['displayName'] ??
            tr('player'))
        .toString();
    final avatarUrl = (userData?['avatar'] ?? userData?['avatarUrl'])?.toString();
    final pos = positionLabelForDisplay(userData?['position']?.toString());
    final city = localizeCity((userData?['city'] ?? '').toString());
    final sub = [pos, city].where((e) => e.trim().isNotEmpty).join(' · ');

    return Drawer(
      backgroundColor: FlapColors.surfaceSolid,
      width: 312,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [FlapColors.card2, FlapColors.surfaceSolid],
            stops: [0.0, 0.42],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Header: avatar + identity --------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: FlapColors.green.withValues(alpha: 0.55),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: FlapColors.green.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildAvatarPlaceholder(displayName),
                              )
                            : _buildAvatarPlaceholder(displayName),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FlapText.sora(
                                fontSize: 16.5, fontWeight: FontWeight.w800),
                          ),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlapText.sora(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: FlapColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ---- Hairline gradient divider --------------------------------
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FlapColors.green.withValues(alpha: 0.45),
                      FlapColors.border,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // ---- Menu -----------------------------------------------------
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        tr('profile_more').toUpperCase(),
                        style: FlapText.sora(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: FlapColors.muted2,
                        ).copyWith(letterSpacing: 1.4),
                      ),
                    ),
                    _drawerItem(
                      icon: Icons.people_alt_outlined,
                      title: tr('profile_menu_friends'),
                      subtitle: tr('manage_friends'),
                      onTap: () => run(_openFriends),
                    ),
                    _drawerItem(
                      icon: Icons.sports_soccer_outlined,
                      title: tr('my_matches_title'),
                      subtitle: tr('il_224b3a8c5d'),
                      onTap: () => run(_openMyMatches),
                    ),
                    _drawerItem(
                      icon: Icons.play_circle_outline,
                      title: tr('my_videos_title'),
                      subtitle: tr('view_uploaded_videos'),
                      onTap: () => run(_openMyVideos),
                    ),
                    _drawerItem(
                      icon: Icons.emoji_events_outlined,
                      title: tr('my_challenges_title'),
                      subtitle: tr('view_challenges'),
                      onTap: () => run(_openMyChallenges),
                    ),
                    _drawerItem(
                      icon: Icons.workspace_premium_outlined,
                      title: tr('subscriptions_title'),
                      subtitle: tr('manage_subscription'),
                      onTap: () => run(_openSubscriptions),
                    ),
                    _drawerItem(
                      icon: Icons.tune_outlined,
                      title: tr('settings_title'),
                      subtitle: tr('profile_settings'),
                      onTap: () => run(_showSettings),
                    ),
                  ],
                ),
              ),
              // ---- Sign out (pinned) ---------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => run(_signOut),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: FlapColors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: FlapColors.red.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 19, color: FlapColors.red),
                          const SizedBox(width: 12),
                          Text(
                            tr('logout_title'),
                            style: FlapText.sora(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: FlapColors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: FlapColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlapColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FlapColors.green.withValues(alpha: 0.18),
                        FlapColors.green.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: FlapColors.green.withValues(alpha: 0.28)),
                  ),
                  child: Icon(icon, size: 19, color: FlapColors.greenBright),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: FlapColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: FlapColors.muted2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF4caf50)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _endorseBadge(String userId, app_badge.Badge badge) async {
    final currentUserId = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (currentUserId == null) return;

    if (currentUserId == userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_472d788d72'))));
      return;
    }

    final result = await sl<PlayerBadgeEndorsementRepository>().endorseBadge(
      ownerUserId: userId,
      badgeId: badge.id,
      badgeLocalizedName: badge.localizedName,
      endorserUserId: currentUserId,
      badgeCategory: badge.category,
    );

    result.when(
      success: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_5fc81f7ab3', args: [badge.localizedName])),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _badgeEndorseVersion++);
      },
      failure: (f) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              f.when(
                cache: () => tr('something_went_wrong'),
                network: (m) => m ?? tr('connection_error'),
                unexpected: (m) => m ?? tr('something_went_wrong'),
                auth: (_, m) => m ?? tr('login_error'),
              ),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      },
    );
  }

  void _openFriends() {
    context.router.push(const FriendsRoute());
  }

  void _openMyMatches() {
    context.router.push(MatchesRoute(initialTabIndex: 1));
  }

  void _openMyVideos() {
    context.router.push(VideoMainRoute(myContent: 'videos'));
  }

  void _openMyChallenges() {
    context.router.push(VideoMainRoute(myContent: 'challenges'));
  }

  void _openStats(Map<String, dynamic> userData) {
    final uid =
        userData['uid'] ??
        sl<AuthSessionRepository>().peekCurrentUser?.uid ??
        '';
    final statsFuture =
        _matchStatsFuture ??
        sl<MatchParticipationStatsRepository>().loadFinishedMatchStats(uid);
    context.router.push(
      ProfileStatsRoute(statsFuture: statsFuture, userData: userData),
    );
  }

  void _openSubscriptions() {
    context.router.push(const SubscriptionRoute());
  }

  Future<void> _openBadgesStore() async {
    await context.router.push(const BadgesStoreRoute());
    if (!mounted) return;
    await _overviewCubit.refreshProfileSnapshot();
  }

  void _showSettings() {
    context.router.push(const ProfileSettingsRoute());
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141B14),
        title: Text(
          tr('logout_confirm'),
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          tr('logout_confirm_body'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              tr('cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              await sl<AuthSessionRepository>().signOut();
              context.router.replace(const WelcomeRoute());
            },
            child: Text(
              tr('logout'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

@RoutePage()
class ProfileStatsScreen extends StatelessWidget {
  final Future<Map<String, dynamic>> statsFuture;
  final Map<String, dynamic> userData;

  const ProfileStatsScreen({
    super.key,
    required this.statsFuture,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final assistsValue = (userData['assists'] ?? 0) as num;
    final cleanSheetsValue = (userData['cleanSheets'] ?? 0) as num;

    return Scaffold(
      backgroundColor: FlapColors.bg,
      appBar: AppBar(
        backgroundColor: FlapColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 48,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: FlapColors.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('stats_performance'),
                style: FlapText.sora(
                    fontSize: 12.5,
                    color: FlapColors.muted,
                    fontWeight: FontWeight.w500)),
            Text(tr('stats_your_stats'),
                style: FlapText.sora(fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildStatsSkeleton();
          }
          final stats = snapshot.data ??
              const {
                'winRate': 0.0,
                'wins': 0,
                'draws': 0,
                'losses': 0,
                'matches': 0,
                'totalGoals': 0,
                'recentResults': ['-', '-', '-', '-', '-'],
              };
          final winRate = (stats['winRate'] as num?)?.toDouble() ?? 0.0;
          final wins = (stats['wins'] as num?)?.toInt() ?? 0;
          final draws = (stats['draws'] as num?)?.toInt() ?? 0;
          final losses = (stats['losses'] as num?)?.toInt() ?? 0;
          final totalMatchesNum = (stats['matches'] as num?)?.toInt() ??
              ((userData['matchesPlayed'] ?? userData['totalMatches'] ?? 0)
                      as num)
                  .toInt();
          final goalsValueNum = (stats['totalGoals'] as num?)?.toInt() ??
              ((userData['goals'] ?? 0) as num).toInt();
          final goalsPerMatch = totalMatchesNum > 0
              ? (goalsValueNum / totalMatchesNum).toStringAsFixed(2)
              : '0.0';
          final recent = List<String>.from(
            stats['recentResults'] ?? const ['-', '-', '-', '-', '-'],
          );
          final form = recent.where((r) => r != '-').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormChartCard(form, winRate),
                const SizedBox(height: 24),
                Text(tr('stats_this_season'),
                    style:
                        FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  crossAxisCount: 2,
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                  childAspectRatio: 1.9,
                  children: [
                    _statTile(totalMatchesNum.toString(),
                        tr('profile_matches_played')),
                    _statTile('${winRate.toStringAsFixed(0)}%',
                        tr('il_4be2547225'),
                        valueColor: FlapColors.greenBright),
                    _statTile(goalsValueNum.toString(),
                        tr('il_6aecd96fcb', namedArgs: {'goalsPerMatch': goalsPerMatch}),
                        valueColor: FlapColors.gold, icon: Icons.sports_soccer),
                    _statTile(assistsValue.toString(), tr('il_ccccbbe9d0')),
                    _statTile(cleanSheetsValue.toString(), tr('il_73dfe49f88')),
                    _statTile(wins.toString(), tr('stat_wins'),
                        valueColor: FlapColors.greenBright),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    tr('il_0579245845', namedArgs: {
                      'wins': '$wins',
                      'draws': '$draws',
                      'losses': '$losses',
                    }),
                    style: FlapText.sora(
                        fontSize: 11.5, color: FlapColors.muted2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormChartCard(List<String> form, double winRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('il_f86d5d6d2f'),
                      style: FlapText.sora(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    tr('stats_last_n_matches',
                        namedArgs: {'count': '${form.length}'}),
                    style: FlapText.sora(
                        fontSize: 11.5, color: FlapColors.muted),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.show_chart,
                      size: 14, color: FlapColors.greenBright),
                  const SizedBox(width: 4),
                  Text('${winRate.toStringAsFixed(0)}%',
                      style: FlapText.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FlapColors.greenBright)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (form.isEmpty)
            SizedBox(
              height: 128,
              child: Center(
                child: Text(tr('stats_no_matches'),
                    style: FlapText.sora(
                        fontSize: 12.5, color: FlapColors.muted)),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < form.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i == form.length - 1 ? 0 : 7),
                        child: _formBar(form[i], i == form.length - 1),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _formBar(String result, bool highlight) {
    final double frac;
    final Color base;
    switch (result) {
      case 'W':
        frac = 1.0;
        base = FlapColors.green;
        break;
      case 'D':
        frac = 0.62;
        base = FlapColors.amber;
        break;
      default: // L
        frac = 0.34;
        base = FlapColors.red;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: frac,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                  bottom: Radius.circular(3),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: highlight
                      ? [FlapColors.greenBright, FlapColors.greenDeep]
                      : [
                          base.withValues(alpha: 0.55),
                          base.withValues(alpha: 0.14),
                        ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(result,
            style: FlapText.sora(fontSize: 10, color: FlapColors.muted)),
      ],
    );
  }

  Widget _statTile(String value, String label,
      {Color? valueColor, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: valueColor ?? FlapColors.gold),
                const SizedBox(width: 6),
              ],
              Text(value,
                  style: FlapText.cond(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? FlapColors.text)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlapText.sora(fontSize: 11.5, color: FlapColors.muted)),
        ],
      ),
    );
  }

  Widget _buildStatsSkeleton() {
    return FlapShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FlapSkeletonBox(height: 188, radius: 18),
            const SizedBox(height: 24),
            const FlapSkeletonBox(width: 120, height: 16, radius: 6),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 1.9,
              children: List.generate(
                6,
                (_) => const FlapSkeletonBox(
                    height: double.infinity, radius: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
