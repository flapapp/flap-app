import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_team.dart';
import '../services/team_service.dart';
import '../utils/i18n.dart';
import '../widgets/team_logo_button.dart';
import 'team_create_screen.dart';
import 'team_details_screen.dart';

class TeamHubScreen extends StatefulWidget {
  const TeamHubScreen({super.key});

  @override
  State<TeamHubScreen> createState() => _TeamHubScreenState();
}

class _TeamHubScreenState extends State<TeamHubScreen> {
  final TeamService _teamService = TeamService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _teamsStream;
  late final Stream<List<AppTeam>> _myTeamsStream;

  @override
  void initState() {
    super.initState();
    _teamsStream = FirebaseFirestore.instance
        .collection('teams')
        .orderBy('wins', descending: true)
        .snapshots();
    final uid = _auth.currentUser?.uid;
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
        title: Text(I18n.inline('Клуби', 'Clubs')),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _teamsStream,
        builder: (context, snapshot) {
          final teams = snapshot.data?.docs
                  .map(AppTeam.fromDoc)
                  .toList(growable: false) ??
              const [];
          final sorted = [...teams]
            ..sort((a, b) {
              final pointsA = _points(a);
              final pointsB = _points(b);
              if (pointsA != pointsB) return pointsB.compareTo(pointsA);
              final diff = _goalDiff(b).compareTo(_goalDiff(a));
              if (diff != 0) return diff;
              return b.wins.compareTo(a.wins);
            });
          final top = sorted.isNotEmpty ? sorted.first : null;

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(top),
                  const SizedBox(height: 24),
                  _buildMyTeams(),
                  const SizedBox(height: 24),
                  _buildLeaderboard(sorted),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _auth.currentUser == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final uid = _auth.currentUser!.uid;
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();
                final teamIds =
                    (userDoc.data()?['teamIds'] as List<dynamic>?) ?? [];
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TeamCreateScreen(existingTeams: teamIds.length),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(I18n.inline('Нова команда', 'Create team')),
              backgroundColor: const Color(0xFF4caf50),
            ),
    );
  }

  Widget _buildHero(AppTeam? team) {
    if (team == null) {
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
                  '${team.wins} ${I18n.inline('перемог', 'wins')}'),
              _chip(
                  Icons.sports_soccer,
                  '${team.wins + team.draws + team.losses} '
                      '${I18n.inline('матчів', 'matches')}'),
              _chip(Icons.star, '${_points(team)} pts'),
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

  Widget _buildLeaderboard(List<AppTeam> teams) {
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

  Widget _tableRow(AppTeam team, int index) {
    final rank = index + 1;
    final matches = team.wins + team.draws + team.losses;
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
                '${team.wins}-${team.draws}-${team.losses}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${_goalDiff(team) >= 0 ? '+' : ''}${_goalDiff(team)}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${_points(team)}',
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

  int _points(AppTeam team) => team.wins * 3 + team.draws;

  int _goalDiff(AppTeam team) => team.goalsFor - team.goalsAgainst;
}




