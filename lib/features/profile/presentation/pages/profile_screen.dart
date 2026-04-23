import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/football_position.dart';
import '../../../../utils/city_catalog.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../router/app_router.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../../badges/data/models/badge.dart' as app_badge;
import '../../../teams/data/models/app_team.dart';
import '../../../teams/data/models/team_stats.dart';
import '../../../teams/data/models/team_invite.dart';
import '../../domain/repositories/match_participation_stats_repository.dart';
import '../../domain/repositories/player_badge_endorsement_repository.dart';
import '../../domain/repositories/player_social_repository.dart';
import '../../domain/repositories/profile_team_membership_repository.dart';
import '../../domain/repositories/team_stats_repository.dart';
import '../../domain/repositories/user_badges_repository.dart';
import '../../../teams/presentation/pages/team_details_screen.dart';
import '../../../teams/presentation/pages/team_create_screen.dart';
import '../bloc/profile_bloc.dart';

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
  List<app_badge.Badge> _userBadges = [];
  int _friendsCount = 0;
  Stream<List<AppTeam>>? _teamsStream;
  Stream<List<TeamInvite>>? _teamInvitesStream;
  String? _userId;
  Future<Map<String, dynamic>>? _matchStatsFuture;
  String? _matchStatsUserId;
  bool _donationPromptCheckStarted = false;
  bool _donationDialogVisible = false;

  @override
  void initState() {
    super.initState();
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (uid != null) {
      _userId = uid;
      _loadUserBadges();
      _loadFriendsCount();
      final teams = sl<ProfileTeamMembershipRepository>();
      _teamsStream = teams.watchUserTeams(uid);
      _teamInvitesStream = teams.watchInvites(uid);
    }
  }

  _DonationConfig _getDonationConfig() {
    final isEnglish = currentAppLanguageCode().toLowerCase().startsWith('en');
    if (isEnglish) {
      return const _DonationConfig(
        imageAssetPath: 'assets/donate/en_donate.png',
        donateUrl: 'https://www.privat24.ua/send/j1gih',
      );
    }
    return const _DonationConfig(
      imageAssetPath: 'assets/donate/ua_donate.png',
      donateUrl: 'https://www.privat24.ua/send/j1gh1',
    );
  }

  Future<void> _setDonationPromptDismissed() async {
    if (!mounted) return;
    context.read<ProfileBloc>().add(
          const ProfileEvent.donationPromptDismissRequested(),
        );
  }

  Future<void> _openDonationLink(String link) async {
    final uri = Uri.parse(link);
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } catch (_) {}
    }
    if (launched) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('il_7c78703c2a'),
        ),
      ),
    );
  }

  void _showDonationDialog() {
    _donationDialogVisible = true;
    final config = _getDonationConfig();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr('il_e8c3f980cf'),
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('il_edc3fc8e6d'),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async => _openDonationLink(config.donateUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(config.imageAssetPath, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('il_f3bab18f57'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _setDonationPromptDismissed();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text(tr('il_f7f8a139c1')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('il_7d9eb7acb1')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              await _openDonationLink(config.donateUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4caf50),
              foregroundColor: Colors.white,
            ),
            child: Text(tr('il_c91ee0f279')),
          ),
        ],
      ),
    ).whenComplete(() {
      _donationDialogVisible = false;
    });
  }

  void _loadUserBadges() async {
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (uid != null) {
      final badges = await sl<UserBadgesRepository>().getUserBadges(uid);
      setState(() {
        _userBadges = badges;
      });
    }
  }

  void _loadFriendsCount() async {
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (uid != null) {
      final count = await sl<PlayerSocialRepository>().countFriends(uid);
      setState(() {
        _friendsCount = count;
      });
    }
  }

  Widget _buildTeamsSection() {
    if (_teamsStream == null) return const SizedBox.shrink();
    return StreamBuilder<List<AppTeam>>(
      stream: _teamsStream,
      builder: (context, snapshot) {
        final teams = snapshot.data ?? const [];
        final canCreate = teams.length < 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    tr('il_9bccdf7bea'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: canCreate
                        ? () async {
                            if (_userId == null) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TeamCreateScreen(existingTeams: teams.length),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      tr('il_4759498ac2'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(20),
                child: LinearProgressIndicator(),
              )
            else if (teams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('il_a6742b3a72'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('il_747ca024e8'),
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: canCreate
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeamCreateScreen(
                                      existingTeams: teams.length,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Text(tr('il_284ff194f8')),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return _TeamCard(
                      team: team,
                      teamStatsStream:
                          sl<TeamStatsRepository>().watchTeamStats(team.id),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamDetailsScreen(teamId: team.id),
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: teams.length,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTeamInvitesSection() {
    if (_teamInvitesStream == null) return const SizedBox.shrink();
    return StreamBuilder<List<TeamInvite>>(
      stream: _teamInvitesStream,
      builder: (context, snapshot) {
        final invites = snapshot.data ?? const [];
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
        final motto = (team?.description.isNotEmpty == true
                ? team!.description
                : null) ??
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamDetailsScreen(teamId: invite.teamId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF1A2737),
                      backgroundImage:
                          logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
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
                          Text(
                            '📍 $city',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
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
                      await sl<ProfileTeamMembershipRepository>().respondToInvite(
                        invite: invite,
                        accept: false,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
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
                        await sl<ProfileTeamMembershipRepository>().respondToInvite(
                          invite: invite,
                          accept: true,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('il_b7b3f790f9')),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr('il_e69e7edfdf',
                                  namedArgs: {'e': e.toString()}),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF36D399),
                      foregroundColor: const Color(0xFF041013),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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
    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (prev, curr) =>
          curr.streamProgress == ProgressStatus.success &&
          curr.profile != null &&
          !curr.profile!.settings.hideDonationPrompt &&
          prev.streamProgress != ProgressStatus.success,
      listener: (context, state) {
        if (_donationPromptCheckStarted) return;
        _donationPromptCheckStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _donationDialogVisible) return;
          _showDonationDialog();
        });
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF0f0f23),
          body: _buildProfileBody(state),
        );
      },
    );
  }

  Widget _buildProfileBody(ProfileState state) {
    if (state.streamProgress == ProgressStatus.loading && state.profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
      );
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
          bilingual('Профіль не знайдено', 'Profile not found'),
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    return _buildProfileContent(state.profile!.legacyUserData);
  }

  void _ensureMatchStatsFuture(String userId) {
    if (userId.isEmpty) return;
    if (_matchStatsUserId == userId && _matchStatsFuture != null) return;
    _matchStatsUserId = userId;
    _matchStatsFuture =
        sl<MatchParticipationStatsRepository>().loadFinishedMatchStats(userId);
  }

  Widget _buildProfileContent(Map<String, dynamic> userData) {
    final displayName = userData['name'] ?? userData['displayName'] ?? tr('player');
    final avatarUrl = userData['avatar'] ?? userData['avatarUrl'];
    final rating = (userData['rating'] ?? 0.0).toDouble();
    final coins = userData['coins'] ?? 0;
    final profileUserId =
        userData['uid'] ?? sl<AuthSessionRepository>().peekCurrentUser?.uid ?? '';
    if (profileUserId.isNotEmpty) {
      _ensureMatchStatsFuture(profileUserId);
    }
    final statsFuture = _matchStatsFuture;
    
    return CustomScrollView(
      slivers: [
        // App bar with gradient
                SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: const Color(0xFF0f0f23),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: _showSettings,
            ),
          ],
        ),

                SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f0f23),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _buildProfileHeader(
              userData,
              displayName,
              avatarUrl,
              rating,
              coins,
              statsFuture,
            ),
          ),
        ),
        
        // Content
        SliverToBoxAdapter(
          child: Column(
            children: [
  _buildStatsCards(userData),
  _buildBadgesSection(userData),
  _buildTeamsSection(),
  const SizedBox(height: 20),
  _buildTeamInvitesSection(),
  _buildActionsMenu(userData),
  const SizedBox(height: 20),
],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
      Map<String, dynamic> userData,
      String displayName,
      String? avatarUrl,
      double rating,
      int coins,
      Future<Map<String, dynamic>>? statsFuture) {
    final userId =
        userData['uid'] ?? sl<AuthSessionRepository>().peekCurrentUser?.uid ?? '';
    return FutureBuilder<Map<String, dynamic>>(
      future: statsFuture ??
          sl<MatchParticipationStatsRepository>().loadFinishedMatchStats(userId),
      builder: (context, snapshot) {
        final stats = snapshot.data ??
            {
              'winRate': 0.0,
              'recentResults': ['-', '-', '-', '-', '-'],
              'wins': 0,
              'draws': 0,
              'losses': 0,
            };
        final recentResults = List<String>.from(stats['recentResults'] as List);
        final winRate = (stats['winRate'] as num).toDouble();
        final wdlText =
            '${stats['wins'] ?? 0}W · ${stats['draws'] ?? 0}D · ${stats['losses'] ?? 0}L';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF162035), Color(0xFF0F1624)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4caf50).withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
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
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${positionLabelForDisplay(userData['position']?.toString())} • ${CityCatalog.labelForDisplay((userData['city'] ?? '').toString())}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tr('il_02354d6492'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final pills = [
                                  _profilePill(
                                    icon: Icons.star_border_rounded,
                                    label: tr('rating'),
                                    value: rating.toStringAsFixed(2),
                                    accent: const Color(0xFFFFD54F),
                                  ),
                                  _profilePill(
                                    icon: Icons.sports_soccer,
                                    label: tr('matches'),
                                    value:
                                        ((userData['matchesPlayed'] ?? 0) as num)
                                            .toString(),
                                    accent: const Color(0xFF4CAF50),
                                  ),
                                  _profilePill(
                                    icon: Icons.percent,
                                    label: 'Win rate',
                                    value: '${winRate.toStringAsFixed(0)}%',
                                    accent: const Color(0xFF64B5F6),
                                  ),
                                  _profilePill(
                                    icon: Icons.sports,
                                    label: tr('il_116cd3982a'),
                                    value:
                                        ((userData['goals'] ?? 0) as num).toString(),
                                    accent: const Color(0xFFFF7043),
                                  ),
                                ];
                                final isCompact = constraints.maxWidth < 500;
                                final columns = isCompact ? 2 : 4;
                                final spacing = 10.0;
                                final itemWidth = columns == 1
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth -
                                            spacing * (columns - 1)) /
                                        columns;
                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: pills
                                      .map(
                                        (pill) => SizedBox(
                                          width: itemWidth,
                                          child: pill,
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('il_f86d5d6d2f'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              wdlText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 6,
                          children: recentResults
                              .take(5)
                              .map((result) => buildResultTile(result))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profilePill({
    required IconData icon,
    required String label,
    required String value,
    Color? accent,
  }) {
    final primary = accent ?? Colors.white70;
    final bg = (accent ?? Colors.white).withOpacity(0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (accent ?? Colors.white).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> userData) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              tr('matches'),
              (userData['matchesPlayed'] ?? 0).toString(),
              Icons.sports_soccer,
              const Color(0xFF4caf50),
              onTap: () => context.router.push(
                MatchesRoute(initialTabIndex: 1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              tr('videos'),
              (userData['videosUploaded'] ?? 0).toString(),
              Icons.videocam,
              const Color(0xFFFF6B35),
              onTap: () =>
                  context.router.push(VideoMainRoute(myContent: 'videos')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              tr('friends'),
              _friendsCount.toString(),
              Icons.people,
              const Color(0xFF2196F3),
              onTap: () => _openFriends(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.25),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection(Map<String, dynamic> userData) {
  final String userId =
      userData['uid'] ?? sl<AuthSessionRepository>().peekCurrentUser?.uid ?? '';
  return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('il_66d0f523a3'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _openBadgesStore,
                child: Text(
                  tr('il_9fd728c66c'),
                  style: const TextStyle(color: Color(0xFF4caf50)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_userBadges.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('il_32ae9b80f8'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _userBadges.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final badge = _userBadges[index];
                  return FutureBuilder<BadgeEndorsementInfo>(
                    future: sl<PlayerBadgeEndorsementRepository>().getEndorsementInfo(
                      ownerUserId: userId,
                      badgeId: badge.id,
                      currentUserId:
                          sl<AuthSessionRepository>().peekCurrentUser?.uid,
                    ),
                    builder: (context, endorsementSnapshot) {
                      final endorsementCount =
                          endorsementSnapshot.data?.count ?? 0;

                      return SizedBox(
                        width: 220,
                        child: GestureDetector(
                          onTap: () => _endorseBadge(userId, badge),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(badge.categoryColor).withOpacity(0.15),
                                    border: Border.all(
                                      color: Color(badge.categoryColor).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      badge.emoji,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        badge.localizedName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Color(badge.categoryColor).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Color(badge.categoryColor).withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          badge.rarityText,
                                          style: TextStyle(
                                            color: Color(badge.categoryColor),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1F2A44),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.thumb_up, size: 14, color: Colors.blueAccent.shade100),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$endorsementCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.greenAccent.shade200,
                                            size: 18,
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
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(Map<String, dynamic> userData) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildActionItem(
            bilingual('👥 Друзі', '👥 Friends'),
            tr('manage_friends'),
            Icons.people,
            () => _openFriends(),
          ),
             _buildActionItem(
     bilingual('⚽ Мої матчі', '⚽ My matches'),
     tr('il_224b3a8c5d'),
     Icons.sports_soccer,
     () => _openMyMatches(),
   ),
          _buildActionItem(
            bilingual('🏆 Мої відео', '🏆 My videos'),
            tr('view_uploaded_videos'),
            Icons.videocam,
            () => _openMyVideos(),
          ),
          _buildActionItem(
            bilingual('⚔️ Мої челенджі', '⚔️ My challenges'),
            tr('view_challenges'),
            Icons.emoji_events,
            () => _openMyChallenges(),
          ),
          _buildActionItem(
            tr('statistics_title'),
            tr('detailed_statistics'),
            Icons.analytics,
            () => _openStats(userData),
          ),
          _buildActionItem(
            tr('subscriptions_title'),
            tr('manage_subscription'),
            Icons.workspace_premium,
            () => _openSubscriptions(),
          ),
          _buildActionItem(
            tr('settings_title'),
            tr('profile_settings'),
            Icons.settings,
            () => _showSettings(),
          ),
          _buildActionItem(
            tr('logout_title'),
            tr('logout_from_account'),
            Icons.logout,
            () => _signOut(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDestructive 
                ? Colors.red.withOpacity(0.2)
                : const Color(0xFF4caf50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFF4caf50),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.5),
          size: 16,
        ),
        tileColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
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

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return const Color(0xFF4CAF50);
    if (rating >= 3.5) return const Color(0xFF8BC34A);
    if (rating >= 2.5) return const Color(0xFFFFC107);
    if (rating >= 1.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  Future<void> _endorseBadge(String userId, app_badge.Badge badge) async {
    final currentUserId = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (currentUserId == null) return;

    if (currentUserId == userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bilingual('Не можна підтверджувати свої бейджі', 'You cannot endorse your own badges'))),
      );
      return;
    }

    final result = await sl<PlayerBadgeEndorsementRepository>().endorseBadge(
      ownerUserId: userId,
      badgeId: badge.id,
      badgeLocalizedName: badge.localizedName,
      endorserUserId: currentUserId,
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
        setState(() {});
      },
      failure: (f) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              f.when(
                cache: () => bilingual('Помилка підтвердження', 'Endorsement error'),
                network: (m) => m ?? bilingual('Помилка мережі', 'Network error'),
                unexpected: (m) =>
                    m ?? bilingual('Помилка підтвердження', 'Endorsement error'),
                auth: (_, m) => m ?? bilingual('Помилка авторизації', 'Auth error'),
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
        userData['uid'] ?? sl<AuthSessionRepository>().peekCurrentUser?.uid ?? '';
    final statsFuture = _matchStatsFuture ??
        sl<MatchParticipationStatsRepository>().loadFinishedMatchStats(uid);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileStatsPage(
          statsFuture: statsFuture,
          userData: userData,
        ),
      ),
    );
  }

  void _openSubscriptions() {
    context.router.push(const SubscriptionRoute());
  }

  void _openBadgesStore() {
    context.router.push(const BadgesStoreRoute()).then((_) {
      // Оновлюємо дані після повернення з магазину
      setState(() {});
    });
  }

  void _showSettings() {
    context.router.push(const ProfileSettingsRoute());
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
  tr('logout_confirm'),
  style: TextStyle(color: Colors.white),
),
        content: Text(
          bilingual('Ви впевнені, що хочете вийти?', 'Are you sure you want to log out?'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              await sl<AuthSessionRepository>().signOut();
              context.router.replace(const LoginRoute());
            },
            child: Text(tr('logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final AppTeam team;
  final Stream<Map<String, dynamic>?> teamStatsStream;
  final VoidCallback? onTap;

  const _TeamCard({
    required this.team,
    required this.teamStatsStream,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: teamStatsStream,
      builder: (context, snapshot) {
        final stats = TeamStats.fromFirestoreMap(
          team.id,
          snapshot.data,
          fallbackName: team.name,
        );
        return _TeamCardBody(
          team: team,
          stats: stats,
          onTap: onTap,
        );
      },
    );
  }
}

class _TeamCardBody extends StatelessWidget {
  final AppTeam team;
  final TeamStats stats;
  final VoidCallback? onTap;

  const _TeamCardBody({
    required this.team,
    required this.stats,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wins = stats.wins != 0 ? stats.wins : team.wins;
    final draws = stats.draws != 0 ? stats.draws : team.draws;
    final losses = stats.losses != 0 ? stats.losses : team.losses;
    final totalMatches = max<int>(wins + draws + losses, 0);
    final winRate =
        totalMatches > 0 ? ((wins / totalMatches) * 100).toStringAsFixed(0) : '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF4caf50),
                  backgroundImage:
                      team.logoUrl != null ? NetworkImage(team.logoUrl!) : null,
                  child: team.logoUrl == null
                      ? Text(
                          team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tr('il_3ac75e6772', args: ['${team.memberIds.length}']),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _teamStatChip('W', wins, Colors.greenAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _teamStatChip('D', draws, Colors.orangeAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _teamStatChip('L', losses, Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('il_6eba3c021d', namedArgs: {'winRate': winRate}),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStatsPage extends StatelessWidget {
  final Future<Map<String, dynamic>> statsFuture;
  final Map<String, dynamic> userData;

  const ProfileStatsPage({
    super.key,
    required this.statsFuture,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final totalMatches =
        (userData['matchesPlayed'] ?? userData['totalMatches'] ?? 0) as num;
    final goalsValue = (userData['goals'] ?? 0) as num;
    final assistsValue = (userData['assists'] ?? 0) as num;
    final cleanSheetsValue = (userData['cleanSheets'] ?? 0) as num;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        title: Text(tr('statistics_title')),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4caf50)),
            );
          }
          final stats = snapshot.data ??
              {
                'winRate': 0.0,
                'wins': 0,
                'draws': 0,
                'losses': 0,
                'recentResults': ['-', '-', '-', '-', '-'],
              };
          final winRate = (stats['winRate'] as num?)?.toDouble() ?? 0.0;
          final wins = (stats['wins'] ?? 0).toString();
          final draws = (stats['draws'] ?? 0).toString();
          final losses = (stats['losses'] ?? 0).toString();
          final goalsPerMatch =
              totalMatches > 0 ? (goalsValue / totalMatches).toStringAsFixed(2) : '0.0';
          final recent = List<String>.from(
              stats['recentResults'] ?? const ['-', '-', '-', '-', '-']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('il_8e76a94ac8'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    buildPerformanceStat(
                      tr('il_4be2547225'),
                      '${winRate.toStringAsFixed(0)}%',
                      tr(
                        'il_0579245845',
                        namedArgs: {
                          'wins': wins,
                          'draws': draws,
                          'losses': losses,
                        },
                      ),
                      Icons.pie_chart_outline,
                      const Color(0xFF4CAF50),
                    ),
                    buildPerformanceStat(
                      tr('il_116cd3982a'),
                      goalsValue.toString(),
                      tr(
                        'il_6aecd96fcb',
                        namedArgs: {'goalsPerMatch': goalsPerMatch},
                      ),
                      Icons.sports_soccer,
                      const Color(0xFFFF7043),
                    ),
                    buildPerformanceStat(
                      tr('il_ccccbbe9d0'),
                      assistsValue.toString(),
                      tr('il_9307ef280b'),
                      Icons.timeline,
                      const Color(0xFF42A5F5),
                    ),
                    buildPerformanceStat(
                      tr('il_98abff28a9'),
                      totalMatches.toString(),
                      tr('il_d5bef65348'),
                      Icons.calendar_month,
                      const Color(0xFF26C6DA),
                    ),
                    buildPerformanceStat(
                      tr('il_73dfe49f88'),
                      cleanSheetsValue.toString(),
                      tr('il_0f8d1cb759'),
                      Icons.shield,
                      const Color(0xFF8D6E63),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  tr('il_1d97631f72'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: recent
                      .take(5)
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: buildResultTile(r),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DonationConfig {
  final String imageAssetPath;
  final String donateUrl;

  const _DonationConfig({
    required this.imageAssetPath,
    required this.donateUrl,
  });
}

Widget buildPerformanceStat(
    String title, String value, String caption, IconData icon, Color color) {
  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 140),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildResultTile(String result) {
  var display = result;
  Color color;
  switch (result) {
    case 'W':
      color = const Color(0xFF4CAF50);
      break;
    case 'L':
      color = const Color(0xFFE53935);
      break;
    case 'D':
      color = const Color(0xFF9E9E9E);
      break;
    default:
      color = Colors.white24;
      display = '-';
  }
  return Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color, width: 1.2),
      color: color.withOpacity(0.18),
    ),
    child: Center(
      child: Text(
        display,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

