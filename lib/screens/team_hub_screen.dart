import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_team.dart';
import '../models/team_stats.dart';
import '../services/team_service.dart';
import '../utils/i18n.dart';
import '../widgets/mode_speed_dial.dart';
import '../widgets/player_avatar_button.dart';
import '../widgets/team_logo_button.dart';
import 'team_create_screen.dart';
import 'team_details_screen.dart';
import '../core/app_auth_context.dart';

class TeamHubScreen extends StatefulWidget {
  const TeamHubScreen({super.key});

  @override
  State<TeamHubScreen> createState() => _TeamHubScreenState();
}

class _TeamHubScreenState extends State<TeamHubScreen> {
  final TeamService _teamService = TeamService();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _teamsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _teamStatsStream;
  late final Stream<List<AppTeam>> _myTeamsStream;

  @override
  void initState() {
    super.initState();
    _teamsStream = FirebaseFirestore.instance
        .collection('teams')
        .orderBy('wins', descending: true)
        .snapshots();
    _teamStatsStream =
        FirebaseFirestore.instance.collection('teamStats').snapshots();
    final uid = AppAuthContext.userId;
    _myTeamsStream = uid != null
        ? _teamService.watchUserTeams(uid)
        : Stream<List<AppTeam>>.value(const []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04070f),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: InkWell(
          onTap: () => Navigator.pushNamed(context, '/mode'),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/logo/flap_logo.jpg',
                    fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Text(
                I18n.inline('Клуби', 'Clubs'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _teamsStream,
        builder: (context, teamSnapshot) {
          final teams = teamSnapshot.data?.docs
                  .map(AppTeam.fromDoc)
                  .toList(growable: false) ??
              const [];
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _teamStatsStream,
            builder: (context, statsSnapshot) {
              final statsMap = <String, TeamStats>{};
              if (statsSnapshot.hasData) {
                for (final doc in statsSnapshot.data!.docs) {
                  statsMap[doc.id] = TeamStats.fromDoc(doc);
                }
              }
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
      floatingActionButton: ModeSpeedDial(
        shortcuts: [
          ModeDialAction(
            icon: Icons.sports_soccer,
            tooltip: I18n.t('matches'),
            onTap: () => Navigator.pushNamed(context, '/matches'),
          ),
          ModeDialAction(
            icon: Icons.play_circle_outline,
            tooltip: I18n.t('videos'),
            onTap: () => Navigator.pushNamed(context, '/video-main'),
          ),
        ],
        onCreate: _onCreateTeamPressed,
        createTooltip: I18n.inline('Нова команда', 'Create team'),
      ),
    );
  }

  Future<void> _onCreateTeamPressed() async {
    final user = AppAuthContext.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Увійдіть, щоб створити команду.', 'Sign in to create a team.'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .get();
    final teamIds = (userDoc.data()?['teamIds'] as List<dynamic>?) ?? [];
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamCreateScreen(existingTeams: teamIds.length),
      ),
    );
  }

  Widget _buildHero(_TeamWithStats? leader) {
    if (leader == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF0c1b2a), Color(0xFF0f2d23)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.inline('Створи першу команду', 'Create your first club'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              I18n.inline(
                  'Збирай склад, плануй матчі та заходь у турнірну таблицю',
                  'Build your roster, plan matches and climb the table'),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final team = leader.team;
    final stats = leader.stats;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0a1e2b), Color(0xFF122f1f)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        image: team.logoUrl != null
            ? DecorationImage(
                image: NetworkImage(team.logoUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.55),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.inline('Лідер туру', 'Club of the week'),
            style: const TextStyle(
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TeamLogoButton(
                teamId: team.id,
                teamName: team.name,
                logoUrl: team.logoUrl,
                size: 54,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  team.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              _chip(Icons.emoji_events,
                  '${stats.wins} ${I18n.inline('перемог', 'wins')}'),
              _chip(
                  Icons.sports_soccer,
                  '${stats.matches} '
                      '${I18n.inline('матчів', 'matches')}'),
              _chip(Icons.star, '${stats.points} pts'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            team.description,
            style: const TextStyle(color: Colors.white70),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamDetailsScreen(teamId: team.id),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(I18n.inline('Переглянути клуб', 'View club')),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildMyTeams() {
    return StreamBuilder<List<AppTeam>>(
      stream: _myTeamsStream,
      builder: (context, snapshot) {
        final myTeams = snapshot.data ?? const [];
        if (myTeams.isEmpty) {
          return _emptyState(
            title: I18n.inline('Немає клубів', 'No clubs yet'),
            subtitle: I18n.inline(
                'Створи команду або приєднайся, щоб відслідковувати прогрес',
                'Create or join to start tracking your club'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.inline('Мої команди', 'My clubs'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: myTeams.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final team = myTeams[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamDetailsScreen(teamId: team.id),
                        ),
                      );
                    },
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TeamLogoButton(
                                teamId: team.id,
                                teamName: team.name,
                                logoUrl: team.logoUrl,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  team.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '${team.wins}-${team.draws}-${team.losses}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            I18n.inline(
                                'Гравців: ${team.memberIds.length}',
                                'Players: ${team.memberIds.length}'),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaderboard(List<_TeamWithStats> teams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.inline('Турнірна таблиця', 'League table'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (teams.isEmpty)
          _emptyState(
            title: I18n.inline('Команд ще немає', 'No clubs yet'),
            subtitle: I18n.inline(
                'Створіть перший клуб і виведіть його в топ',
                'Create the first club and reach the top'),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                _tableHeader(),
                const Divider(height: 1, color: Color(0x22FFFFFF)),
                ...List.generate(
                  teams.length,
                  (index) => _tableRow(teams[index], index),
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
        title: I18n.inline('Бомбардирів ще немає', 'No scorers yet'),
        subtitle: I18n.inline(
            'Після перших голів ми покажемо рейтинг', 'Leaders will appear once teams score'),
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
            Text(
              I18n.inline('Бомбардири ліги', 'Golden boot'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: top.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final scorer = entry.value;
                  final user = data[scorer.playerId] ?? const {};
                  final name = (user['displayName'] ??
                          user['name'] ??
                          I18n.inline('Гравець', 'Player'))
                      .toString();
                  final avatarUrl =
                      (user['avatarUrl'] ?? user['avatar'] ?? '').toString();
                  final subtitle = scorer.teamNames.isEmpty
                      ? I18n.inline('Без клубу', 'No club')
                      : scorer.teamNames.join(', ');
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: PlayerAvatarButton(
                      userId: scorer.playerId,
                      displayName: name,
                      avatarUrl: avatarUrl,
                      size: 38,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${scorer.goals} ⚽',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tableHeader() {
    final style = const TextStyle(
      color: Colors.white54,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: Text(I18n.inline('Команда', 'Team'), style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(
              I18n.inline('Матчі', 'Matches'),
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text('W-D-L', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text('GD', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(
              I18n.inline('Очки', 'Pts'),
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(_TeamWithStats data, int index) {
    final team = data.team;
    final stats = data.stats;
    final rank = index + 1;
    final matches = stats.matches;
    final color = rank == 1
        ? const Color(0xFF4caf50)
        : rank <= 3
            ? Colors.white
            : Colors.white70;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailsScreen(teamId: team.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Row(
                children: [
                  TeamLogoButton(
                    teamId: team.id,
                    teamName: team.name,
                    logoUrl: team.logoUrl,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (team.city != null && team.city!.isNotEmpty)
                          Text(
                            team.city!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '$matches',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                    '${stats.wins}-${stats.draws}-${stats.losses}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                    '${stats.goalDiff >= 0 ? '+' : ''}${stats.goalDiff}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                    '${stats.points}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsers(
      List<String> ids) async {
    if (ids.isEmpty) return {};
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return {
      for (final doc in snap.docs) doc.id: doc.data(),
    };
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




