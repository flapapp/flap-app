import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../../../features/profile/domain/repositories/profile_repository.dart';
import '../../../../features/profile/domain/repositories/profile_team_membership_repository.dart';
import '../../domain/repositories/teams_repository.dart';
import '../../../../router/app_router.dart';

import '../../data/models/app_team.dart';
import '../../data/models/team_stats.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/team_crest.dart';
@RoutePage()
class TeamHubScreen extends StatefulWidget {
  const TeamHubScreen({super.key});

  @override
  State<TeamHubScreen> createState() => _TeamHubScreenState();
}

class _TeamHubScreenState extends State<TeamHubScreen> {
  late final Stream<List<AppTeam>> _teamsLeaderboardStream;
  late final Stream<Map<String, TeamStats>> _teamStatsIndexStream;
  late Stream<List<AppTeam>> _myTeamsStream;
  int _myTeamsStreamEpoch = 0;

  @override
  void initState() {
    super.initState();
    final teamsRepo = sl<TeamsRepository>();
    _teamsLeaderboardStream = teamsRepo.watchTeamsOrderedByWins();
    _teamStatsIndexStream = teamsRepo.watchAllTeamStatsById();
    _bindMyTeamsStream();
  }

  void _bindMyTeamsStream() {
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    _myTeamsStream = uid != null
        ? sl<ProfileTeamMembershipRepository>().watchUserTeams(uid)
        : Stream<List<AppTeam>>.value(const []);
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the active locale so this screen re-localizes instantly when
    // the language is switched. `tr()` does not register a dependency on the
    // locale, and this screen lives in the always-alive tab-shell IndexedStack.
    context.locale;
    return Scaffold(
      backgroundColor: FlapColors.bg,
      floatingActionButton: FlapCreateFab(
        tooltip: tr('il_284ff194f8'),
        onTap: _onCreateTeamPressed,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        centerTitle: false,
        title: Text(
          tr('il_98348a9036'),
          style: FlapText.sora(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF13241B), FlapColors.bg],
            ),
          ),
        ),
        // actions: [
        //   FlapIconButton(
        //     icon: Icons.add_rounded,
        //     iconSize: 22,
        //     tooltip: tr('il_284ff194f8'),
        //     onTap: _onCreateTeamPressed,
        //   ),
        //   const SizedBox(width: 16),
        // ],
      ),
      body: StreamBuilder<List<AppTeam>>(
        stream: _teamsLeaderboardStream,
        builder: (context, teamSnapshot) {
          if (teamSnapshot.connectionState == ConnectionState.waiting &&
              teamSnapshot.data == null) {
            return _buildHubSkeleton();
          }
          final teams = teamSnapshot.data ?? const [];
          return StreamBuilder<Map<String, TeamStats>>(
            stream: _teamStatsIndexStream,
            builder: (context, statsSnapshot) {
              final statsMap = statsSnapshot.data ?? const {};
              final teamNameMap = {
                for (final team in teams) team.id: team.name,
              };
              final enriched = teams
                  .map((team) => _TeamWithStats(
                        team: team,
                        stats: statsMap[team.id] ??
                            TeamStats.empty(team.id, name: team.name),
                      ))
                  .toList();
              enriched.sort(_compareTeams);
              final leader = enriched.isNotEmpty ? enriched.first : null;

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHero(leader),
                      const SizedBox(height: 24),
                      _buildMyTeams(),
                      const SizedBox(height: 24),
                      _buildLeaderboard(enriched),
                      const SizedBox(height: 24),
                      _buildGoldenBootSection(statsMap, teamNameMap),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onCreateTeamPressed() async {
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_89803af156'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final profile = await sl<ProfileRepository>().fetchUserProfile(uid);
    final teamIds =
        List<dynamic>.from(profile?.document['teamIds'] ?? const []);
    if (!mounted) return;
    final created = await context.router.push<bool>(
      TeamCreateRoute(existingTeams: teamIds.length),
    );
    if (!mounted) return;
    if (created == true) {
      setState(() {
        _bindMyTeamsStream();
        _myTeamsStreamEpoch++;
      });
    }
  }

  // Shimmer placeholder shown while the hub streams load (no spinner).
  Widget _buildHubSkeleton() {
    Widget bar(double h, {double? w, double r = 8}) =>
        FlapSkeletonBox(width: w, height: h, radius: r);
    return FlapShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // leader hero
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FlapColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: FlapColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    bar(54, w: 54, r: 16),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(20, w: 150, r: 6),
                          const SizedBox(height: 8),
                          bar(12, w: 90, r: 6),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: bar(54, r: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: bar(54, r: 14)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: bar(54, r: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: bar(54, r: 14)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // my clubs
            bar(16, w: 110, r: 6),
            const SizedBox(height: 12),
            SizedBox(
              height: 128,
              child: Row(children: [
                bar(128, w: 168, r: 18),
                const SizedBox(width: 12),
                bar(128, w: 140, r: 18),
              ]),
            ),
            const SizedBox(height: 24),
            // league table
            bar(16, w: 130, r: 6),
            const SizedBox(height: 12),
            bar(280, r: 16),
            const SizedBox(height: 24),
            // golden boot
            bar(16, w: 120, r: 6),
            const SizedBox(height: 12),
            for (var i = 0; i < 4; i++) ...[
              bar(52, r: 12),
              const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(_TeamWithStats? leader) {
    if (leader == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('il_9af4722ab4'),
                style: FlapText.sora(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(tr('il_9c1000ed18'),
                style: FlapText.sora(fontSize: 13, color: FlapColors.muted)),
          ],
        ),
      );
    }

    final team = leader.team;
    final stats = leader.stats;
    final winRate =
        stats.matches > 0 ? (stats.wins / stats.matches * 100).round() : 0;
    return GestureDetector(
      onTap: () => context.router.push(TeamDetailsRoute(teamId: team.id)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x295C97E0), Color(0x05FFFFFF)],
            stops: [0.0, 0.45],
          ),
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TeamCrest(
                  teamId: team.id,
                  teamName: team.name,
                  size: 54,
                  borderRadius: 16,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        team.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.cond(fontSize: 24, height: 0.95),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr('team_league_leader'),
                        style: FlapText.sora(
                            fontSize: 12.5, color: FlapColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('1',
                        style: FlapText.cond(
                            fontSize: 34,
                            height: 0.9,
                            color: FlapColors.greenBright)),
                    Text(
                      tr('team_in_league').toUpperCase(),
                      style: FlapText.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: FlapColors.muted,
                          letterSpacing: 1.4),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: FlapStatPill(
                        value: '${stats.matches}', label: tr('team_played'))),
                const SizedBox(width: 10),
                Expanded(
                    child: FlapStatPill(
                        value: '$winRate%',
                        label: tr('profile_win_rate_label'))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: FlapStatPill(
                        value: '${stats.goalsFor}',
                        label: tr('team_goals_for'))),
                const SizedBox(width: 10),
                Expanded(
                    child: FlapStatPill(
                        value: '${stats.points}',
                        label: tr('team_points'),
                        valueColor: FlapColors.greenBright)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTeams() {
    return StreamBuilder<List<AppTeam>>(
      key: ValueKey<int>(_myTeamsStreamEpoch),
      stream: _myTeamsStream,
      builder: (context, snapshot) {
        final myTeams = snapshot.data ?? const [];
        if (myTeams.isEmpty) {
          return _emptyState(
            title: tr('il_3ac1496270'),
            subtitle: tr('il_37735f756e'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('il_f665423b2a'),
                style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: myTeams.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index == myTeams.length) {
                    return _newClubCard();
                  }
                  return _myTeamCard(myTeams[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _myTeamCard(AppTeam team) {
    return GestureDetector(
      onTap: () => context.router.push(TeamDetailsRoute(teamId: team.id)),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamCrest(
                teamId: team.id,
                teamName: team.name,
                size: 40,
                borderRadius: 14),
            const Spacer(),
            Text(team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    FlapText.sora(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${team.wins}-${team.draws}-${team.losses} · ${tr('il_5d379b3bb6', args: ['${team.memberIds.length}'])}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlapText.sora(fontSize: 11.5, color: FlapColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newClubCard() {
    return GestureDetector(
      onTap: _onCreateTeamPressed,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x05FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x244CAF50),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x594CAF50)),
              ),
              child: const Icon(Icons.add,
                  color: FlapColors.greenBright, size: 22),
            ),
            const SizedBox(height: 10),
            Text(tr('team_new_club'),
                style:
                    FlapText.sora(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(List<_TeamWithStats> teams) {
    final myUid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('il_3a12ab9ef7'),
            style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (teams.isEmpty)
          _emptyState(
            title: tr('il_3ac1496270'),
            subtitle: tr('il_5ee6befe39'),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: FlapColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FlapColors.border),
            ),
            child: Column(
              children: [
                _leagueHeaderRow(),
                for (int i = 0; i < teams.length; i++)
                  _leagueRow(
                    teams[i],
                    i,
                    i < teams.length - 1,
                    myUid != null && teams[i].team.memberIds.contains(myUid),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGoldenBootSection(
      Map<String, TeamStats> statsMap, Map<String, String> teamNames) {
    final aggregates = <String, _ScorerAggregate>{};
    statsMap.forEach((teamId, stats) {
      stats.playerGoals.forEach((playerId, goals) {
        if (goals <= 0) return;
        final entry = aggregates.putIfAbsent(
          playerId,
          () => _ScorerAggregate(playerId: playerId),
        );
        final sourceName = stats.teamName.isNotEmpty
            ? stats.teamName
            : (teamNames[teamId] ?? '');
        entry.addGoals(goals, sourceName);
      });
    });

    final sorted = aggregates.values.toList()
      ..sort((a, b) => b.goals.compareTo(a.goals));
    final top = sorted.take(5).toList();

    if (top.isEmpty) {
      return _emptyState(
        title: tr('il_3063c85237'),
        subtitle: tr('il_26a03b01b5'),
      );
    }

    final ids = top.map((e) => e.playerId).toList();
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _fetchUsers(ids),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, Map<String, dynamic>>{};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, size: 17, color: FlapColors.gold),
                const SizedBox(width: 8),
                Text(tr('il_452625d752'),
                    style:
                        FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < top.length; i++)
              _bootRow(top[i], i, top.length, data),
          ],
        );
      },
    );
  }

  Widget _bootRow(_ScorerAggregate scorer, int index, int total,
      Map<String, Map<String, dynamic>> data) {
    final rank = index + 1;
    final user = data[scorer.playerId] ?? const {};
    final name =
        (user['displayName'] ?? user['name'] ?? tr('il_64aee8c6cb')).toString();
    final avatarUrl = (user['avatarUrl'] ?? user['avatar'] ?? '').toString();
    final subtitle = scorer.teamNames.isEmpty
        ? tr('il_42b11ff123')
        : scorer.teamNames.join(', ');
    return GestureDetector(
      onTap: () => context.router.push(
          PlayerProfileRoute(playerId: scorer.playerId, playerName: name)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: index < total - 1
              ? const Border(bottom: BorderSide(color: FlapColors.border))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: FlapText.cond(
                      fontSize: 16,
                      color: rank == 1 ? FlapColors.gold : FlapColors.muted)),
            ),
            const SizedBox(width: 6),
            PlayerAvatarButton(
              userId: scorer.playerId,
              displayName: name,
              avatarUrl: avatarUrl,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          FlapText.sora(fontSize: 11.5, color: FlapColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_soccer, size: 15, color: FlapColors.gold),
                const SizedBox(width: 5),
                Text('${scorer.goals}',
                    style: FlapText.cond(fontSize: 18, color: FlapColors.gold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _leagueHeaderRow() {
    final st = FlapText.sora(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: FlapColors.muted,
        letterSpacing: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0x08FFFFFF),
        border: Border(bottom: BorderSide(color: FlapColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 20, child: Text('#', style: st)),
          const SizedBox(width: 6),
          Expanded(child: Text(tr('il_5985039f10'), style: st)),
          _leagueCell('P', st),
          _leagueCell('W', st),
          _leagueCell('D', st),
          SizedBox(
              width: 28,
              child: Text(tr('team_standings_gd'),
                  style: st, textAlign: TextAlign.center)),
          SizedBox(
              width: 34,
              child: Text(tr('il_52ee1923e9'),
                  style: st, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _leagueCell(String label, TextStyle style) => SizedBox(
      width: 22,
      child: Text(label, style: style, textAlign: TextAlign.center));

  Widget _leagueRow(
      _TeamWithStats data, int index, bool divider, bool isMe) {
    final team = data.team;
    final stats = data.stats;
    final rank = index + 1;
    final posColor = rank == 1
        ? FlapColors.gold
        : isMe
            ? FlapColors.greenBright
            : FlapColors.muted;
    final gd = stats.goalDiff;
    final cell = FlapText.sora(fontSize: 12.5, color: FlapColors.muted);
    return InkWell(
      onTap: () => context.router.push(TeamDetailsRoute(teamId: team.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: isMe ? const Color(0x144CAF50) : null,
          border: divider
              ? const Border(bottom: BorderSide(color: FlapColors.border))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
                width: 20,
                child: Text('$rank',
                    textAlign: TextAlign.center,
                    style: FlapText.cond(fontSize: 15, color: posColor))),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  TeamCrest(
                      teamId: team.id,
                      teamName: team.name,
                      size: 22,
                      borderRadius: 7),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(team.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            SizedBox(
                width: 22,
                child: Text('${stats.matches}',
                    textAlign: TextAlign.center, style: cell)),
            SizedBox(
                width: 22,
                child: Text('${stats.wins}',
                    textAlign: TextAlign.center, style: cell)),
            SizedBox(
                width: 22,
                child: Text('${stats.draws}',
                    textAlign: TextAlign.center, style: cell)),
            SizedBox(
                width: 28,
                child: Text(gd > 0 ? '+$gd' : '$gd',
                    textAlign: TextAlign.center, style: cell)),
            SizedBox(
                width: 34,
                child: Text('${stats.points}',
                    textAlign: TextAlign.right,
                    style: FlapText.cond(fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsers(
      List<String> ids) async {
    if (ids.isEmpty) return {};
    return sl<ProfileRepository>().getUserDocumentsByIds(ids);
  }

  int _compareTeams(_TeamWithStats a, _TeamWithStats b) {
    final pointsDiff = b.stats.points.compareTo(a.stats.points);
    if (pointsDiff != 0) return pointsDiff;
    final diff = b.stats.goalDiff.compareTo(a.stats.goalDiff);
    if (diff != 0) return diff;
    return b.stats.wins.compareTo(a.stats.wins);
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

}

class _TeamWithStats {
  final AppTeam team;
  final TeamStats stats;

  const _TeamWithStats({required this.team, required this.stats});
}

class _ScorerAggregate {
  final String playerId;
  int goals;
  final Set<String> teamNames;

  _ScorerAggregate({
    required this.playerId,
    this.goals = 0,
    Set<String>? teamNames,
  }) : teamNames = teamNames ?? <String>{};

  void addGoals(int value, String teamName) {
    goals += value;
    if (teamName.isNotEmpty) {
      teamNames.add(teamName);
    }
  }
}




