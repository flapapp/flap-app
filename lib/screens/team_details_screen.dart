import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/app_team.dart';
import '../models/team_match_request.dart';
import '../services/team_service.dart';
import '../services/friends_service.dart';
import '../models/friend_request.dart';
import '../utils/i18n.dart';
import 'create_match_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final String teamId;

  const TeamDetailsScreen({super.key, required this.teamId});

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final _teamService = TeamService();
  final _friendsService = FriendsService();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _teamStream;
  late final Stream<List<TeamMatchRequest>> _requestsStream;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _teamStream = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .snapshots();
    _requestsStream = _teamService.watchMatchRequests(widget.teamId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(I18n.inline('Команда', 'Team')),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _teamStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final team = AppTeam.fromDoc(snapshot.data!);
          final uid = _auth.currentUser?.uid;
          final isCaptain = uid == team.captainId;
          final isVice = team.viceCaptainIds.contains(uid);
          final canManage = isCaptain || isVice;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(team, canManage),
                const SizedBox(height: 20),
                _buildMetricGrid(team),
                const SizedBox(height: 20),
                _buildHighlights(team),
                if (canManage) ...[
                  const SizedBox(height: 24),
                  _buildCoachDesk(team),
                ],
                const SizedBox(height: 24),
                _buildMembers(team, canManage),
                const SizedBox(height: 24),
                _buildRecentMatches(team),
                const SizedBox(height: 24),
                _buildMatchRequests(canManage),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(AppTeam team, bool canManage) {
    final totalMatches = team.wins + team.losses + team.draws;
    final DateFormat formatter = DateFormat('MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0b2f2f), Color(0xFF0d1333)],
        ),
        image: team.logoUrl != null
            ? DecorationImage(
                image: NetworkImage(team.logoUrl!),
                fit: BoxFit.cover,
                colorFilter:
                    ColorFilter.mode(Colors.black.withOpacity(0.55), BlendMode.darken),
              )
            : null,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage:
                    team.logoUrl != null ? NetworkImage(team.logoUrl!) : null,
                child: team.logoUrl == null
                    ? Text(
                        team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                        style: const TextStyle(
                          color: Color(0xFF0c1b2a),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      team.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (team.city != null)
                _infoChip(Icons.location_on,
                    I18n.inline(team.city!, team.city!)),
              _infoChip(
                Icons.public,
                team.isPublic
                    ? I18n.inline('Публічна команда', 'Public team')
                    : I18n.inline('Приватна команда', 'Private team'),
              ),
              _infoChip(Icons.calendar_month,
                  I18n.inline('Засновано ${formatter.format(team.createdAt)}', 'Founded ${formatter.format(team.createdAt)}')),
              if (canManage)
                _infoChip(Icons.security,
                    I18n.inline('Панель капітана', 'Captain controls')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _heroStatBlock(
                label: I18n.inline('Перемоги', 'Wins'),
                value: team.wins.toString(),
              ),
              _heroStatBlock(
                label: I18n.inline('Нічиї', 'Draws'),
                value: team.draws.toString(),
              ),
              _heroStatBlock(
                label: I18n.inline('Поразки', 'Losses'),
                value: team.losses.toString(),
              ),
              _heroStatBlock(
                label: I18n.inline('Матчів', 'Matches'),
                value: totalMatches.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStatBlock({required String label, required String value}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCoachDesk(AppTeam team) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF124d2f), Color(0xFF0b1e2e)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.inline('Панель менеджера', 'Coach desk'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openInviteSheet(team),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.12),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(I18n.inline('Додати гравців', 'Invite players')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.sports_soccer),
                  label: Text(I18n.inline('Матч команди', 'Team match')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(AppTeam team) {
    final totalMatches = team.wins + team.draws + team.losses;
    final goalDiff = team.goalsFor - team.goalsAgainst;
    final avgGoals =
        totalMatches == 0 ? '0.0' : (team.goalsFor / totalMatches).toStringAsFixed(1);
    final metrics = [
      _MetricTileData(
        icon: Icons.auto_graph,
        value: avgGoals,
        title: I18n.inline('Голи / матч', 'Goals / match'),
        caption: I18n.inline('Ритм атаки', 'Attack tempo'),
      ),
      _MetricTileData(
        icon: Icons.shield,
        value: '${team.goalsAgainst}',
        title: I18n.inline('Пропущено', 'Conceded'),
        caption: I18n.inline('Блок оборони', 'Defensive wall'),
      ),
      _MetricTileData(
        icon: Icons.change_circle,
        value: '${goalDiff >= 0 ? '+' : ''}$goalDiff',
        title: I18n.inline('Баланс голів', 'Goal balance'),
        caption: I18n.inline('Тиск на суперника', 'Pressure index'),
      ),
      _MetricTileData(
        icon: Icons.groups_3,
        value: '${team.memberIds.length}',
        title: I18n.inline('Склад', 'Roster'),
        caption: I18n.inline('Готових гравців', 'Active players'),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (context, index) => _metricTile(metrics[index]),
    );
  }

  Widget _metricTile(_MetricTileData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: Colors.white54),
          const SizedBox(height: 12),
          Text(
            data.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            data.caption,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights(AppTeam team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.inline('Хайлайти клубу', 'Club highlights'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _highlightTile(
          icon: Icons.timeline,
          title: I18n.inline('Форма', 'Form'),
          value: _formString(team),
          caption: I18n.inline('Останні матчі', 'Last fixtures'),
        ),
        const SizedBox(height: 12),
        _highlightTile(
          icon: Icons.local_fire_department,
          title: I18n.inline('Клубна енергія', 'Club momentum'),
          value:
              '+${team.wins} / -${team.losses} / =${team.draws}',
          caption: I18n.inline('Свіжа статистика', 'Fresh stats'),
        ),
        const SizedBox(height: 12),
        _buildTopScorerCard(team),
      ],
    );
  }

  Widget _highlightTile({
    required IconData icon,
    required String title,
    required String value,
    required String caption,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopScorerCard(AppTeam team) {
    if (team.playerGoals.isEmpty) {
      return _highlightTile(
        icon: Icons.stars,
        title: I18n.inline('Очікує героя', 'Awaiting hero'),
        value: I18n.inline('Ще без забитих', 'No goals yet'),
        caption: I18n.inline('Перший гол запише історію', 'First scorer writes history'),
      );
    }
    final entries = team.playerGoals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = entries.first;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(best.key).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['displayName'] ??
            data?['name'] ??
            I18n.inline('Гравець', 'Player');
        return _highlightTile(
          icon: Icons.star,
          title: I18n.inline('Топ скорер', 'Top scorer'),
          value: name,
          caption: I18n.inline(
              '${best.value} голів у сезоні', '${best.value} goals this season'),
        );
      },
    );
  }

  Widget _buildRecentMatches(AppTeam team) {
    final recent = team.recentMatches.take(4).toList();
    if (recent.isEmpty) {
      return _emptyState(
        title: I18n.inline('Ще немає історій', 'No stories yet'),
        subtitle: I18n.inline(
            'Зіграй перший матч, щоб з’явилася статистика',
            'Play the first match to unlock insights'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.inline('Останні матчі', 'Recent fixtures'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...recent.map(_recentMatchTile),
      ],
    );
  }

  Widget _recentMatchTile(Map<String, dynamic> match) {
    final opponent = (match['opponentName'] ?? I18n.inline('Суперник', 'Opponent')).toString();
    final score = (match['score'] ?? '-:-').toString();
    final result = (match['result'] ?? 'draw').toString();
    final playedRaw = match['playedAt'];
    DateTime? playedAt;
    if (playedRaw is Timestamp) {
      playedAt = playedRaw.toDate();
    }
    final label = playedAt != null
        ? DateFormat('d MMM').format(playedAt)
        : I18n.inline('Нещодавно', 'recently');
    final badgeColor = _resultColor(result);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              result.toUpperCase(),
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            score,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembers(AppTeam team, bool canManage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.inline('Склад', 'Roster'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...team.memberIds.map(
          (memberId) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .get(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final name = data?['displayName'] ??
                  data?['name'] ??
                  I18n.inline('Гравець', 'Player');
              final role = memberId == team.captainId
                  ? I18n.inline('Капітан', 'Captain')
                  : team.viceCaptainIds.contains(memberId)
                      ? I18n.inline('Віце', 'Vice')
                      : I18n.inline('Гравець', 'Player');
              final avatarUrl = (data?['avatarUrl'] ?? data?['avatar']) as String?;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage:
                          avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(name[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _roleBadge(role),
                        ],
                      ),
                    ),
                    if (canManage && memberId != team.captainId)
                      PopupMenuButton<String>(
                        color: const Color(0xFF1a1f2c),
                        onSelected: (action) =>
                            _handleMemberAction(action, team, memberId),
                        itemBuilder: (_) => [
                          if (!team.viceCaptainIds.contains(memberId))
                            PopupMenuItem(
                              value: 'promote',
                              child: Text(
                                I18n.inline('Зробити віце', 'Promote to vice'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          else
                            PopupMenuItem(
                              value: 'demote',
                              child: Text(
                                I18n.inline('Зняти віце', 'Remove vice role'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              I18n.inline('Видалити', 'Remove'),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _roleBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  void _handleMemberAction(String action, AppTeam team, String memberId) async {
    final teamRef =
        FirebaseFirestore.instance.collection('teams').doc(team.id);
    if (action == 'promote') {
      await teamRef.update({
        'viceCaptainIds': FieldValue.arrayUnion([memberId]),
      });
    } else if (action == 'demote') {
      await teamRef.update({
        'viceCaptainIds': FieldValue.arrayRemove([memberId]),
      });
    } else if (action == 'remove') {
      await teamRef.update({
        'memberIds': FieldValue.arrayRemove([memberId]),
        'viceCaptainIds': FieldValue.arrayRemove([memberId]),
      });
    }
  }

  Widget _buildMatchRequests(bool canManage) {
    if (!canManage) return const SizedBox.shrink();
    return StreamBuilder<List<TeamMatchRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        if (requests.isEmpty) {
          return _emptyState(
            title: I18n.inline('Немає нових викликів', 'No pending requests'),
            subtitle: I18n.inline(
                'Як тільки інші клуби кинуть виклик — побачиш їх тут',
                'Incoming challenges will appear here'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.inline('Запити на матчі', 'Match requests'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...requests.map(
              (req) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF11212f), Color(0xFF0d1728)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            I18n.inline('VS', 'VS'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            req.opponentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          I18n.inline('Запропоновано складів: ${req.proposedRoster.length}',
                              'Proposed roster: ${req.proposedRoster.length}'),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Text(
                          DateFormat('d MMM, HH:mm')
                              .format(req.createdAt),
                          style: const TextStyle(color: Colors.white30, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _respondToMatchRequest(req, accepted: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(I18n.t('cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _respondToMatchRequest(req, accepted: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4caf50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(I18n.inline('Погодитись', 'Accept')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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

  Color _resultColor(String result) {
    switch (result) {
      case 'win':
        return const Color(0xFF4caf50);
      case 'loss':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }

  String _formString(AppTeam team) {
    if (team.recentMatches.isEmpty) {
      return I18n.inline('Ще без матчів', 'No matches yet');
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
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();
      final team = AppTeam.fromDoc(teamDoc);
      roster = await _pickRoster(team.memberIds, request.matchId);
      if (roster.isEmpty) return;
    }
    await _teamService.respondToMatchRequest(
      request: request,
      accept: accepted,
      confirmedRoster: roster,
    );
  }

  Future<List<String>> _pickRoster(
      List<String> members, String matchId) async {
    final matchDoc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .get();
    final data = matchDoc.data() ?? {};
    final maxPlayers = (data['maxPlayers'] ?? 10) as int;
    final limit = (maxPlayers / 2).ceil();
    final current = members.take(limit).toSet();
    final selected = Set<String>.from(current);
    final namesCache = <String, String>{};
    final futures = members.map((id) async {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
        final data = doc.data();
        namesCache[id] =
            (data?['displayName'] ?? data?['name'] ?? 'Player').toString();
      } catch (_) {
        namesCache[id] = 'Player';
      }
    });
    await Future.wait(futures);
    if (!mounted) return selected.toList();
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(I18n.inline('Обрати склад', 'Select roster')),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: members.map((id) {
                    final checked = selected.contains(id);
                    final disabled = !checked && selected.length >= limit;
                    final name =
                        namesCache[id] ?? I18n.inline('Гравець', 'Player');
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
                  child: Text(I18n.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx),
                  child: Text(I18n.t('confirm')),
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
    return selected.toList();
  }

  Future<void> _openInviteSheet(AppTeam team) async {
    final friends = await _friendsService.getUserFriends(team.captainId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0f0f23),
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
  final _teamService = TeamService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _selectedIds = {};
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchPlayers() async {
    setState(() => _isSearching = true);
    final results =
        await _teamService.searchPlayers(_searchCtrl.text.trim(), limit: 10);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _sendInvites() async {
    if (_selectedIds.isEmpty) return;
    await _teamService.invitePlayers(
      teamId: widget.team.id,
      teamName: widget.team.name,
      userIds: _selectedIds.toList(),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              I18n.inline('Запросити гравців', 'Invite players'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: I18n.inline('Пошук за ім’ям', 'Search by name'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchPlayers,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const LinearProgressIndicator()
            else
              SizedBox(
                height: 150,
                child: ListView(
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
                child: Text(I18n.inline('Надіслати запрошення', 'Send invites')),
              ),
            ),
          ],
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

