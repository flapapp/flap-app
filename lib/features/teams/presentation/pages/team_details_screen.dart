import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../../../features/matches/domain/repositories/matches_repository.dart';
import '../../../../features/profile/domain/entities/user_profile.dart';
import '../../../../features/profile/domain/repositories/player_social_repository.dart';
import '../../../../features/profile/domain/repositories/profile_repository.dart';
import '../../../../features/profile/domain/repositories/profile_team_membership_repository.dart';
import '../../../../features/profile/domain/repositories/team_stats_repository.dart';
import '../../domain/repositories/teams_repository.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../widgets/team_crest.dart';

import '../../data/models/app_team.dart';
import '../../data/models/team_match_request.dart';
import '../../data/models/team_stats.dart';
import '../../../friends/data/models/friend_request.dart';
import '../../data/models/team_join_request.dart';
import 'package:flap_app/city_localization.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../matches/presentation/pages/create_match_screen.dart';
import '../../../matches/presentation/pages/match_details_screen.dart';

@RoutePage()
class TeamDetailsScreen extends StatefulWidget {
  final String teamId;

  const TeamDetailsScreen({super.key, required this.teamId});

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  TeamsRepository get _teamsRepo => sl<TeamsRepository>();

  late final Stream<AppTeam?> _teamWatch;
  late final Stream<Map<String, dynamic>?> _teamStatsWatch;
  late final Stream<List<TeamMatchRequest>> _incomingMatchInvites;
  late final Stream<List<TeamMatchRequest>> _outgoingMatchRequests;
  bool _isSendingJoinRequest = false;
  bool _isLeavingTeam = false;
  int _detailTab = 0; // 0 = Overview, 1 = Stats
  final Set<String> _processingJoinRequestIds = {};

  @override
  void initState() {
    super.initState();
    _teamWatch = sl<TeamsRepository>().watchTeam(widget.teamId);
    _teamStatsWatch = sl<TeamStatsRepository>().watchTeamStats(widget.teamId);
    _incomingMatchInvites =
        _teamsRepo.watchIncomingTeamMatchInvites(widget.teamId);
    _outgoingMatchRequests =
        _teamsRepo.watchOutgoingTeamMatchRequests(widget.teamId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppTeam?>(
      stream: _teamWatch,
      builder: (context, snapshot) {
        final team = snapshot.data;
        final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
        final isCaptain = team != null && uid == team.captainId;
        final isVice = team != null && team.viceCaptainIds.contains(uid);
        final canManage = isCaptain || isVice;
        final isMember =
            team != null && uid != null && team.memberIds.contains(uid);
        return Scaffold(
          backgroundColor: const Color(0xFF070A08),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: FlapColors.text,
            iconTheme: const IconThemeData(color: FlapColors.text),
            actions: [
              if (team != null && uid != null && !isMember)
                _buildAppBarJoinAction(team, uid),
              const SizedBox(width: 8),
            ],
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
          body: _buildBody(snapshot, team, uid, canManage, isMember),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<AppTeam?> snapshot,
    AppTeam? team,
    String? uid,
    bool canManage,
    bool isMember,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting && team == null) {
      return _buildDetailsSkeleton();
    }
    if (team == null) {
      return Center(
        child: Text(
          tr('il_34d918824a'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _teamStatsWatch,
      builder: (context, statsSnap) {
        final stats = TeamStats.fromFirestoreMap(
          team.id,
          statsSnap.data,
          fallbackName: team.name,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSection(team, canManage, stats),
              const SizedBox(height: 16),
              _buildDetailTabs(),
              const SizedBox(height: 16),
              if (_detailTab == 0) ...[
                if (canManage) ...[
                  _buildCoachDesk(team),
                  const SizedBox(height: 24),
                ],
                _buildMembers(team, canManage),
                const SizedBox(height: 24),
                _buildRecentMatches(stats),
                const SizedBox(height: 24),
                _buildMatchRequestsSection(canManage),
              ] else ...[
                _buildHighlights(team, stats),
                const SizedBox(height: 20),
                _buildScorersList(stats),
                const SizedBox(height: 20),
                _buildMetricGrid(team, stats),
              ],
              if (uid != null && isMember) ...[
                const SizedBox(height: 24),
                _buildLeaveTeamButton(team, uid),
              ],
            ],
          ),
        );
      },
    );
  }

  // Shimmer placeholder shown while the team loads (no spinner).
  Widget _buildDetailsSkeleton() {
    Widget bar(double h, {double? w, double r = 8}) =>
        FlapSkeletonBox(width: w, height: h, radius: r);
    return FlapShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: BoxDecoration(
                color: FlapColors.card2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: FlapColors.border),
              ),
              child: Column(
                children: [
                  bar(64, w: 64, r: 18),
                  const SizedBox(height: 14),
                  bar(24, w: 170, r: 7),
                  const SizedBox(height: 10),
                  bar(12, w: 210, r: 6),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: bar(56, r: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: bar(56, r: 14)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: bar(56, r: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: bar(56, r: 14)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            bar(46, r: 14),
            const SizedBox(height: 18),
            bar(16, w: 120, r: 6),
            const SizedBox(height: 12),
            for (var i = 0; i < 4; i++) ...[
              bar(60, r: 14),
              const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }

  /// Join / Requested pill in the app bar for non-members (mirrors the match
  /// detail page).
  Widget _buildAppBarJoinAction(AppTeam team, String uid) {
    return StreamBuilder<TeamJoinRequest?>(
      stream: _teamsRepo.watchMyJoinRequest(team.id, uid),
      builder: (context, reqSnap) {
        final pending = reqSnap.data?.status == TeamJoinRequestStatus.pending;
        if (pending) {
          return _appBarJoinPill(
            icon: Icons.mark_email_read_outlined,
            label: tr('match_feed_join_requested'),
            onPressed: null,
          );
        }
        return _appBarJoinPill(
          icon: Icons.person_add_outlined,
          label: tr('join'),
          onPressed:
              _isSendingJoinRequest ? null : () => _sendJoinRequest(team),
        );
      },
    );
  }

  Widget _appBarJoinPill({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: FlapColors.text,
            disabledForegroundColor: FlapColors.muted,
            side: const BorderSide(color: FlapColors.borderStrong),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(AppTeam team, bool canManage, TeamStats stats) {
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    final isCaptain = uid != null && uid == team.captainId;
    final isMember = uid != null && team.memberIds.contains(uid);
    final winRate =
        stats.matches > 0 ? (stats.wins / stats.matches * 100).round() : 0;

    final subParts = <String>[];
    if (team.city != null && team.city!.trim().isNotEmpty) {
      subParts.add(localizeCity(team.city!));
    }
    subParts.add(tr('il_79f5cba540', args: ['${team.createdAt.year}']));
    if (isCaptain) {
      subParts.add(tr('team_you_are_captain'));
    } else if (isMember) {
      subParts.add(tr('il_64aee8c6cb'));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x244CAF50), Color(0x03FFFFFF)],
          stops: [0.0, 0.55],
        ),
        color: FlapColors.card2,
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        children: [
          Center(
            child: TeamCrest(
              teamId: team.id,
              teamName: team.name,
              size: 64,
              borderRadius: 18,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            team.name.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FlapText.cond(fontSize: 30, height: 0.98),
          ),
          const SizedBox(height: 8),
          Text(
            subParts.join('  ·  '),
            textAlign: TextAlign.center,
            style: FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _heroMetric('${stats.matches}', tr('team_played'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _heroMetric(
                      '$winRate%', tr('profile_win_rate_label'))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child:
                      _heroMetric('${stats.goalsFor}', tr('team_goals_for'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _heroMetric('${stats.points}', tr('team_points'),
                      valueColor: FlapColors.greenBright)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String value, String label,
      {Color valueColor = FlapColors.text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: FlapText.cond(fontSize: 22, height: 1, color: valueColor)),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: FlapText.sora(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: FlapColors.muted,
                letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTeamButton(AppTeam team, String userId) {
  final isCaptain = userId == team.captainId;

  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _isLeavingTeam
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF0E1310),
                      title: Text(
                        tr('il_d35d16a4b1'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        isCaptain
                            ? tr('il_ea52704482')
                            : tr('il_66b80f0860'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(tr('cancel'),
                              style: const TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            tr('il_fc6e4a408d'),
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (!confirmed) return;

              try {
                setState(() => _isLeavingTeam = true);
                await _teamsRepo.leaveTeam(teamId: team.id, userId: userId);
                if (!mounted) return;
                Navigator.pop(context); // Back from team page
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr('il_4a91b2fdf8'),
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              } finally {
                if (mounted) setState(() => _isLeavingTeam = false);
              }
            },
      icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
      label: Text(
        _isLeavingTeam
            ? tr('il_9b6b4fb63c')
            : tr('il_ca808af337'),
        style: const TextStyle(color: Colors.redAccent),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}

  Future<void> _sendJoinRequest(AppTeam team) async {
    if (_isSendingJoinRequest) return;
    setState(() => _isSendingJoinRequest = true);
    try {
      await _teamsRepo.requestToJoinTeam(
        teamId: team.id,
        teamName: team.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_2b01b19485'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingJoinRequest = false);
      }
    }
  }

  Future<void> _handleJoinResponse(
      TeamJoinRequest request, bool accept) async {
    setState(() => _processingJoinRequestIds.add(request.id));
    try {
      await _teamsRepo.respondToJoinRequest(
        request: request,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? tr('il_9de07bcfc1')
                : tr('il_1df48b2da0'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingJoinRequestIds.remove(request.id));
      }
    }
  }

  Widget _buildCoachDesk(AppTeam team) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x1F4CAF50), Color(0x05FFFFFF)],
          stops: [0.0, 0.6],
        ),
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x474CAF50)),
      ),
      child: StreamBuilder<List<TeamJoinRequest>>(
        stream: _teamsRepo.watchJoinRequests(team.id),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const <TeamJoinRequest>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports,
                      size: 18, color: FlapColors.greenBright),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      tr('il_af22c9dd60'),
                      style: FlapText.sora(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (requests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: FlapColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tr('team_requests_count',
                            namedArgs: {'count': '${requests.length}'}),
                        style: FlapText.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FlapColors.gold),
                      ),
                    ),
                ],
              ),
              if (requests.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...requests.map(_deskRequestRow),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openInviteSheet(team),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlapColors.text,
                        side: const BorderSide(color: FlapColors.borderStrong),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: Text(tr('il_6442e97ac6'),
                          style: FlapText.sora(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreateMatchScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlapColors.green,
                        foregroundColor: FlapColors.onGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.sports_soccer, size: 18),
                      label: Text(tr('il_4f76cec7a7'),
                          style: FlapText.sora(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// A single join-request row rendered inline inside the captain's desk
  /// (no card surface — the desk is the card).
  Widget _deskRequestRow(TeamJoinRequest request) {
    final busy = _processingJoinRequestIds.contains(request.id);
    return FutureBuilder<UserProfile?>(
      future: sl<ProfileRepository>().fetchUserProfile(request.userId),
      builder: (context, snapshot) {
        final userData = snapshot.data?.document ?? const <String, dynamic>{};
        final avatarUrl =
            (userData['avatarUrl'] ?? userData['photoUrl'] ?? '').toString();
        final name =
            (userData['displayName'] ?? userData['name'] ?? request.userName)
                .toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              PlayerAvatarButton(
                userId: request.userId,
                displayName: name,
                avatarUrl: avatarUrl,
                size: 38,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM, HH:mm').format(request.createdAt),
                      style: FlapText.sora(
                          fontSize: 11.5, color: FlapColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _reqMiniButton(
                Icons.check,
                FlapColors.greenBright,
                busy ? null : () => _handleJoinResponse(request, true),
              ),
              const SizedBox(width: 7),
              _reqMiniButton(
                Icons.close,
                FlapColors.muted,
                busy ? null : () => _handleJoinResponse(request, false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _detailTabButton(0, tr('team_tab_overview'))),
          Expanded(child: _detailTabButton(1, tr('team_tab_stats'))),
        ],
      ),
    );
  }

  Widget _detailTabButton(int index, String label) {
    final on = _detailTab == index;
    return GestureDetector(
      onTap: () => setState(() => _detailTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? const Color(0x1AFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: FlapText.sora(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: on ? FlapColors.text : FlapColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricGrid(AppTeam team, TeamStats stats) {
    final totalMatches = stats.matches;
    final goalDiff = stats.goalDiff;
    final avgGoals =
        totalMatches == 0 ? '0.0' : (stats.goalsFor / totalMatches).toStringAsFixed(1);
    final metrics = [
      _MetricTileData(
        icon: Icons.auto_graph,
        value: avgGoals,
        title: tr('il_52f28f3500'),
        caption: tr('il_5ea4ceef18'),
      ),
      _MetricTileData(
        icon: Icons.shield,
        value: '${stats.goalsAgainst}',
        title: tr('il_07d6b41160'),
        caption: tr('il_7075a6ba14'),
      ),
      _MetricTileData(
        icon: Icons.change_circle,
        value: '${goalDiff >= 0 ? '+' : ''}$goalDiff',
        title: tr('il_13674f440a'),
        caption: tr('il_6c7302cb3c'),
      ),
      _MetricTileData(
        icon: Icons.groups_3,
        value: '${team.memberIds.length}',
        title: tr('il_cd4795809e'),
        caption: tr('il_a36357dfad'),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) => _metricTile(metrics[index]),
    );
  }

  Widget _metricTile(_MetricTileData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 16, color: FlapColors.greenBright),
              const SizedBox(width: 6),
              Flexible(
                child: Text(data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlapText.cond(fontSize: 22, height: 1)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            data.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: FlapColors.muted,
                letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights(AppTeam team, TeamStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('il_fe89709ec3'),
          style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _highlightTile(
          icon: Icons.timeline,
          title: tr('il_2e0e960ab3'),
          value: _formString(team),
          caption: tr('il_8bc38c9839'),
        ),
        const SizedBox(height: 12),
        _highlightTile(
          icon: Icons.local_fire_department,
          title: tr('il_4d8aa119da'),
          value:
              '+${stats.wins} / -${stats.losses} / =${stats.draws}',
          caption: tr('il_dbd2e87efe'),
        ),
        const SizedBox(height: 12),
        _buildTopScorerCard(stats),
      ],
    );
  }

  Widget _buildScorersList(TeamStats stats) {
    if (stats.playerGoals.isEmpty) {
      return _highlightTile(
        icon: Icons.sports_soccer,
        title: tr('il_3063c85237'),
        value: tr('il_9ea34e5802'),
        caption: tr('il_1173ec5f77'),
      );
    }
    final entries = stats.playerGoals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('il_c24687b978'),
          style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...top.map((entry) => FutureBuilder<UserProfile?>(
              future: sl<ProfileRepository>().fetchUserProfile(entry.key),
              builder: (context, snapshot) {
                final data = snapshot.data?.document;
                final name = (data?['displayName'] ??
                        data?['name'] ??
                        tr('il_64aee8c6cb'))
                    .toString();
                final avatarUrl =
                    (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0x0BFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FlapColors.border),
                  ),
                  child: Row(
                    children: [
                      PlayerAvatarButton(
                        userId: entry.key,
                        displayName: name,
                        avatarUrl: avatarUrl,
                        size: 38,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlapText.sora(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr('il_67d783e9bb'),
                              style: FlapText.sora(
                                  fontSize: 11.5, color: FlapColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports_soccer,
                              size: 15, color: FlapColors.gold),
                          const SizedBox(width: 5),
                          Text('${entry.value}',
                              style: FlapText.cond(
                                  fontSize: 18, color: FlapColors.gold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            )),
      ],
    );
  }



  Widget _reqMiniButton(IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }

  Widget _highlightTile({
    required IconData icon,
    required String title,
    required String value,
    required String caption,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x0BFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: FlapColors.border),
            ),
            child: Icon(icon, color: FlapColors.greenBright, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: FlapText.sora(
                      fontSize: 12.5, color: FlapColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: FlapText.sora(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: FlapText.sora(
                        fontSize: 11, color: FlapColors.muted2),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopScorerCard(TeamStats stats) {
    if (stats.playerGoals.isEmpty) {
      return _highlightTile(
        icon: Icons.stars,
        title: tr('il_f8c14603ce'),
        value: tr('il_82333be252'),
        caption: tr('il_a9fae84e89'),
      );
    }
    final entries = stats.playerGoals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = entries.first;
    return FutureBuilder<UserProfile?>(
      future: sl<ProfileRepository>().fetchUserProfile(best.key),
      builder: (context, snapshot) {
        final data = snapshot.data?.document;
        final name = data?['displayName'] ??
            data?['name'] ??
            tr('il_64aee8c6cb');
        return _highlightTile(
          icon: Icons.star,
          title: tr('il_17d2ec06ae'),
          value: name,
          caption: tr('il_63740ed7ec', args: ['${best.value}']),
        );
      },
    );
  }

  Widget _buildRecentMatches(TeamStats stats) {
    final recent = stats.recentMatches.take(4).toList();
    if (recent.isEmpty) {
      return _emptyState(
        title: tr('il_77313c35ad'),
        subtitle: tr('il_1bcaff1c62'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('il_dd39c9da8f'),
          style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...recent.map(_recentMatchTile),
      ],
    );
  }

  Widget _recentMatchTile(Map<String, dynamic> match) {
    final opponent = (match['opponentName'] ?? tr('il_c0886e50d4')).toString();
    final score = (match['score'] ?? '-:-').toString();
    final result = (match['result'] ?? 'draw').toString();
    final playedRaw = match['playedAt'];
    DateTime? playedAt;
    if (playedRaw is DateTime) playedAt = playedRaw;
    if (playedAt == null && playedRaw is String) playedAt = DateTime.tryParse(playedRaw);
    if (playedAt == null) {
      try {
        final dynamic raw = playedRaw;
        final date = raw?.toDate();
        if (date is DateTime) playedAt = date;
      } catch (_) {}
    }
    final label = playedAt != null
        ? DateFormat('d MMM').format(playedAt)
        : tr('il_59f7a3dd09');
    final c = _resultColor(result);
    final r = result.toLowerCase();
    final resLetter = r.startsWith('w') ? 'W' : (r.startsWith('l') ? 'L' : 'D');
    final scoreText = score.replaceAll(':', '–');
    final matchId = (match['matchId'] ?? '').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: matchId.isEmpty ? null : () => _openMatchDetails(matchId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x0BFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlapColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                scoreText,
                style: FlapText.cond(fontSize: 18, color: c),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'vs $opponent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        FlapText.sora(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: FlapText.sora(fontSize: 11, color: FlapColors.muted),
                  ),
                ],
              ),
            ),
            FlapResultChip(result: resLetter),
          ],
        ),
      ),
    );
  }

  Future<void> _openMatchDetails(String matchId) async {
    try {
      final match = await sl<MatchesRepository>().fetchMatchById(matchId);
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_688010d886')),
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchDetailsScreen(match: match),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_fae55d5171', namedArgs: {'e': e.toString()})),
        ),
      );
    }
  }

  Widget _buildMembers(AppTeam team, bool canManage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('il_cd4795809e'),
                style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              tr('il_5d379b3bb6', args: ['${team.memberIds.length}']),
              style: FlapText.sora(fontSize: 12, color: FlapColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...team.memberIds.map((id) => _memberRow(team, id, canManage)),
      ],
    );
  }

  Widget _memberRow(AppTeam team, String memberId, bool canManage) {
    final isCaptain = memberId == team.captainId;
    final isVice = team.viceCaptainIds.contains(memberId);
    final role = isCaptain
        ? tr('il_2e786c488b')
        : isVice
            ? tr('il_9a9036ab0f')
            : tr('il_64aee8c6cb');
    return FutureBuilder<UserProfile?>(
      future: sl<ProfileRepository>().fetchUserProfile(memberId),
      builder: (context, snapshot) {
        final data = snapshot.data?.document;
        final name =
            (data?['displayName'] ?? data?['name'] ?? tr('il_64aee8c6cb'))
                .toString();
        final avatarUrl = (data?['avatarUrl'] ?? data?['avatar']) as String?;
        final position =
            (data?['position'] ?? data?['preferredPosition'] ?? '')
                .toString()
                .trim();
        final ratingRaw =
            data?['overall_rating'] ?? data?['rating'] ?? data?['averageRating'];
        final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.router.push(
              PlayerProfileRoute(playerId: memberId, playerName: name)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0x0BFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlapColors.border),
            ),
            child: Row(
              children: [
                PlayerAvatarButton(
                  userId: memberId,
                  displayName: name,
                  avatarUrl: avatarUrl,
                  size: 38,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      if (position.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          position,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FlapText.sora(
                              fontSize: 11.5, color: FlapColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _roleBadge(role),
                if (rating > 0) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: FlapColors.gold),
                      const SizedBox(width: 3),
                      Text(rating.toStringAsFixed(2),
                          style: FlapText.sora(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
                if (canManage && !isCaptain)
                  PopupMenuButton<String>(
                    color: const Color(0xFF141B14),
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: FlapColors.muted),
                    onSelected: (action) =>
                        _handleMemberAction(action, team, memberId),
                    itemBuilder: (_) => [
                      if (!isVice)
                        PopupMenuItem(
                          value: 'promote',
                          child: Text(tr('il_d470396292'),
                              style: const TextStyle(color: Colors.white)),
                        )
                      else
                        PopupMenuItem(
                          value: 'demote',
                          child: Text(tr('il_6d9eea42f3'),
                              style: const TextStyle(color: Colors.white)),
                        ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(tr('il_c3812fc4ac'),
                            style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roleBadge(String label) {
    final isCaptain = label == tr('il_2e786c488b');
    final isVice = label == tr('il_9a9036ab0f');
    final c = isCaptain
        ? FlapColors.gold
        : isVice
            ? FlapColors.blue
            : FlapColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label.toUpperCase(),
        style: FlapText.sora(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  void _handleMemberAction(String action, AppTeam team, String memberId) async {
    if (action == 'promote') {
      await sl<TeamsRepository>().setViceCaptainMembership(
        teamId: team.id,
        memberId: memberId,
        addAsVice: true,
      );
    } else if (action == 'demote') {
      await sl<TeamsRepository>().setViceCaptainMembership(
        teamId: team.id,
        memberId: memberId,
        addAsVice: false,
      );
    } else if (action == 'remove') {
      await _teamsRepo.leaveTeam(teamId: team.id, userId: memberId);
    }
  }

  Widget _buildMatchRequestsSection(bool canManage) {
    if (!canManage) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMatchRequestPanel(
          stream: _incomingMatchInvites,
          title: tr('team_match_incoming_title'),
          emptyTitle: tr('il_883a9f47c7'),
          emptySubtitle: tr('team_match_incoming_empty'),
          showResponseActions: true,
        ),
        const SizedBox(height: 24),
        _buildMatchRequestPanel(
          stream: _outgoingMatchRequests,
          title: tr('team_match_outgoing_title'),
          emptyTitle: tr('team_match_outgoing_empty_title'),
          emptySubtitle: tr('team_match_outgoing_empty_subtitle'),
          showResponseActions: false,
        ),
      ],
    );
  }

  Widget _buildMatchRequestPanel({
    required Stream<List<TeamMatchRequest>> stream,
    required String title,
    required String emptyTitle,
    required String emptySubtitle,
    required bool showResponseActions,
  }) {
    return StreamBuilder<List<TeamMatchRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        if (requests.isEmpty) {
          return _emptyState(
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...requests.map(
              (req) => Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: FlapColors.blue.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tr('il_8db1a2e199'),
                            style: FlapText.sora(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: FlapColors.blue),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            req.opponentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FlapText.sora(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _requestStatusColor(req.status)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _requestStatusLabel(req.status),
                            style: FlapText.sora(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _requestStatusColor(req.status)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('il_ea317e322b',
                              args: ['${req.proposedRoster.length}']),
                          style: FlapText.sora(
                              fontSize: 12, color: FlapColors.muted),
                        ),
                        Text(
                          DateFormat('d MMM, HH:mm').format(req.createdAt),
                          style: FlapText.sora(
                              fontSize: 11, color: FlapColors.muted2),
                        ),
                      ],
                    ),
                    if (showResponseActions &&
                        req.status == TeamMatchRequestStatus.pending) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _respondToMatchRequest(req, accepted: false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FlapColors.text,
                                side: const BorderSide(
                                    color: FlapColors.borderStrong),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(tr('cancel'),
                                  style: FlapText.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _respondToMatchRequest(req, accepted: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FlapColors.green,
                                foregroundColor: FlapColors.onGreen,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(tr('il_89713b9c9c'),
                                  style: FlapText.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        req.status == TeamMatchRequestStatus.accepted
                            ? tr('match_invite_status_accepted')
                            : req.status == TeamMatchRequestStatus.declined
                                ? tr('match_invite_status_declined')
                                : tr('team_match_outgoing_pending'),
                        style:
                            FlapText.sora(fontSize: 13, color: FlapColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _requestStatusLabel(TeamMatchRequestStatus status) {
    switch (status) {
      case TeamMatchRequestStatus.accepted:
        return tr('match_invite_status_accepted');
      case TeamMatchRequestStatus.declined:
        return tr('match_invite_status_declined');
      case TeamMatchRequestStatus.pending:
        return tr('match_invite_status_pending');
    }
  }

  Color _requestStatusColor(TeamMatchRequestStatus status) {
    switch (status) {
      case TeamMatchRequestStatus.accepted:
        return const Color(0xFF4caf50);
      case TeamMatchRequestStatus.declined:
        return const Color(0xFFE06464);
      case TeamMatchRequestStatus.pending:
        return const Color(0xFFE7C25A);
    }
  }

  Widget _emptyState({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _resultColor(String result) {
    switch (result) {
      case 'win':
        return const Color(0xFF4caf50);
      case 'loss':
        return const Color(0xFFE06464);
      default:
        return const Color(0xFFE7C25A);
    }
  }

  String _formString(AppTeam team) {
    if (team.recentMatches.isEmpty) {
      return tr('il_417b217a64');
    }
    final buffer = team.recentMatches.take(5).map((match) {
      final result = (match['result'] ?? 'draw').toString();
      switch (result) {
        case 'win':
          return 'W';
        case 'loss':
          return 'L';
        default:
          return 'D';
      }
    }).join(' ');
    return buffer;
  }

  Future<void> _respondToMatchRequest(TeamMatchRequest request,
      {required bool accepted}) async {
    List<String> roster = request.proposedRoster;
    if (accepted) {
      final team =
          await sl<ProfileTeamMembershipRepository>().getTeam(widget.teamId);
      if (team == null) return;
      roster = await _pickRoster(team.memberIds, request.matchId);
      if (roster.isEmpty) return;
    }
    await _teamsRepo.respondToMatchRequest(
      request: request,
      accept: accepted,
      confirmedRoster: roster,
    );
  }

  Future<List<String>> _pickRoster(
      List<String> members, String matchId) async {
    final matchModel =
        await sl<MatchesRepository>().fetchMatchById(matchId);
    final maxPlayers = matchModel?.maxPlayers ?? 10;
    final limit = (maxPlayers / 2).ceil();
    final current = members.take(limit).toSet();
    final currentUserId = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (currentUserId != null) {
      current.add(currentUserId);
      if (current.length > limit) {
        var overflow = current.length - limit;
        final removable = current
            .where((id) => id != currentUserId)
            .toList();
        for (final id in removable) {
          if (overflow <= 0) break;
          current.remove(id);
          overflow--;
        }
      }
    }
    final selected = Set<String>.from(current);
    final namesCache = <String, String>{};
    final userMaps =
        await sl<ProfileRepository>().getUserDocumentsByIds(members);
    for (final id in members) {
      final data = userMaps[id];
      namesCache[id] =
          (data?['displayName'] ?? data?['name'] ?? 'Player').toString();
    }
    if (!mounted) return selected.toList();
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(tr('il_d5dd1f9c74')),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: members.map((id) {
                    final checked = selected.contains(id);
                    final isSelf = currentUserId != null && id == currentUserId;
                    final disabled =
                        (!checked && selected.length >= limit) || isSelf;
                    final name =
                        namesCache[id] ?? tr('il_64aee8c6cb');
                    return CheckboxListTile(
                      value: checked,
                      onChanged: disabled
                          ? null
                          : (value) {
                              setStateDialog(() {
                                if (value == true) {
                                  selected.add(id);
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                      title: Text(name),
                      subtitle: isSelf
                          ? Text(
                              tr('il_96c1688234'),
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    selected.clear();
                    Navigator.pop(ctx);
                  },
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx),
                  child: Text(tr('confirm')),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) {
      return selected.toList();
    }
    if (currentUserId != null) {
      selected.add(currentUserId);
    }
    return selected.toList();
  }

  Future<void> _openInviteSheet(AppTeam team) async {
    final friends =
        await sl<PlayerSocialRepository>().listFriendsOfUser(team.captainId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1310),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _InviteSheet(
          team: team,
          friends: friends,
        );
      },
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final AppTeam team;
  final List<Friend> friends;

  const _InviteSheet({required this.team, required this.friends});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  TeamsRepository get _teamsRepo => sl<TeamsRepository>();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _selectedIds = {};
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchPlayers() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await _teamsRepo.searchPlayers(query, limit: 10);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), _searchPlayers);
  }

  Future<void> _sendInvites() async {
    if (_selectedIds.isEmpty) return;
    await _teamsRepo.invitePlayers(
      teamId: widget.team.id,
      teamName: widget.team.name,
      userIds: _selectedIds.toList(),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxResultsHeight = (screenH * 0.34).clamp(120.0, 260.0);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('il_6442e97ac6'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.search,
                scrollPadding: EdgeInsets.only(
                  bottom: keyboardInset + 120,
                  top: 24,
                ),
                onChanged: _handleSearchChanged,
                onSubmitted: (_) => _searchPlayers(),
                decoration: InputDecoration(
                  hintText: tr('il_4ae2b33364'),
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: _searchPlayers,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isSearching)
                const LinearProgressIndicator()
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxResultsHeight),
                  child: ListView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      ...widget.friends.map((friend) => CheckboxListTile(
                            value: _selectedIds.contains(friend.userId),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds.add(friend.userId);
                                } else {
                                  _selectedIds.remove(friend.userId);
                                }
                              });
                            },
                            title: Text(
                              friend.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )),
                      ..._searchResults.map(
                        (user) => CheckboxListTile(
                          value: _selectedIds.contains(user['id']),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(user['id'] as String);
                              } else {
                                _selectedIds.remove(user['id'] as String);
                              }
                            });
                          },
                          title: Text(
                            user['displayName'] as String,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedIds.isEmpty ? null : _sendInvites,
                  child: Text(tr('il_c57456e442')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTileData {
  final IconData icon;
  final String value;
  final String title;
  final String caption;

  const _MetricTileData({
    required this.icon,
    required this.value,
    required this.title,
    required this.caption,
  });
}

