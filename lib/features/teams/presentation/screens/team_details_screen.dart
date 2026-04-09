import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/models/match.dart' as app_match;
import 'package:flap_app/models/team_match_request.dart';
import 'package:flap_app/models/team_stats.dart';
import 'package:flap_app/features/teams/data/team_service.dart';
import 'package:flap_app/features/friends/data/friends_service.dart';
import 'package:flap_app/models/friend_request.dart';
import 'package:flap_app/models/team_join_request.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/team_logo_button.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/features/matches/presentation/screens/create_match_screen.dart';
import 'package:flap_app/features/matches/presentation/screens/match_details_screen.dart';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
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
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _teamStatsStream;
  late final Stream<List<TeamMatchRequest>> _requestsStream;
  bool _isSendingJoinRequest = false;
  bool _isLeavingTeam = false;
  final Set<String> _processingJoinRequestIds = {};

  @override
  void initState() {
    super.initState();
    _teamStream = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .snapshots();
    _teamStatsStream = FirebaseFirestore.instance
        .collection('teamStats')
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
          final uid = AppAuthContext.userId;
          final isCaptain = uid == team.captainId;
          final isVice = team.viceCaptainIds.contains(uid);
          final canManage = isCaptain || isVice;
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _teamStatsStream,
            builder: (context, statsSnap) {
              final stats = (statsSnap.hasData && statsSnap.data!.exists)
                  ? TeamStats.fromDoc(statsSnap.data!)
                  : TeamStats.empty(team.id, name: team.name);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(team, canManage, stats),
                    const SizedBox(height: 20),
                    _buildMetricGrid(team, stats),
                    const SizedBox(height: 20),
                    _buildHighlights(team, stats),
                    const SizedBox(height: 20),
                    _buildScorersList(stats),
                    if (canManage) ...[
                      const SizedBox(height: 24),
                      _buildJoinRequests(team),
                    ],
                    if (canManage) ...[
                      const SizedBox(height: 24),
                      _buildCoachDesk(team),
                    ],
                    const SizedBox(height: 24),
                    _buildMembers(team, canManage),
                    const SizedBox(height: 24),
                    _buildRecentMatches(stats),
                    const SizedBox(height: 24),
                    _buildMatchRequests(canManage),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(AppTeam team, bool canManage, TeamStats stats) {
    final totalMatches = stats.matches;
    final DateFormat formatter = DateFormat('MMM yyyy');
    final uid = AppAuthContext.userId;
    final isMember = uid != null && team.memberIds.contains(uid);
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
              TeamLogoButton(
                teamId: team.id,
                teamName: team.name,
                logoUrl: team.logoUrl,
                size: 72,
                circular: true,
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
                value: stats.wins.toString(),
              ),
              _heroStatBlock(
                label: I18n.inline('Нічиї', 'Draws'),
                value: stats.draws.toString(),
              ),
              _heroStatBlock(
                label: I18n.inline('Поразки', 'Losses'),
                value: stats.losses.toString(),
              ),
              _heroStatBlock(
                label: I18n.inline('Матчів', 'Matches'),
                value: totalMatches.toString(),
              ),
            ],
          ),
          if (uid != null && !isMember) ...[
            const SizedBox(height: 18),
            _buildJoinRequestWidget(team, uid),
          ],

          if (uid != null && isMember) ...[
            const SizedBox(height: 18),
            _buildLeaveTeamButton(team, uid),
          ],
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

  Widget _buildJoinRequestWidget(AppTeam team, String userId) {
    return StreamBuilder<TeamJoinRequest?>(
      stream: _teamService.watchMyJoinRequest(team.id, userId),
      builder: (context, snapshot) {
        final request = snapshot.data;
        if (request != null) {
          if (request.status == TeamJoinRequestStatus.pending) {
            return _joinStatusBanner(
              icon: Icons.hourglass_top,
              color: Colors.orangeAccent,
              title: I18n.inline('Запит надіслано', 'Request sent'),
              subtitle: I18n.inline(
                  'Капітан перевіряє ваш профіль', 'Captain is reviewing your profile'),
            );
          } else if (request.status == TeamJoinRequestStatus.declined) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _joinStatusBanner(
                  icon: Icons.close,
                  color: Colors.redAccent,
                  title: I18n.inline('Запит відхилено', 'Request declined'),
                  subtitle: I18n.inline(
                      'Спробуйте пізніше або напишіть капітану',
                      'Try later or contact the captain'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isSendingJoinRequest
                      ? null
                      : () => _sendJoinRequest(team),
                  icon: const Icon(Icons.refresh),
                  label: Text(I18n.inline('Спробувати ще раз', 'Try again')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          }
        }
        return ElevatedButton.icon(
          onPressed:
              _isSendingJoinRequest ? null : () => _sendJoinRequest(team),
          icon: const Icon(Icons.group_add),
          label: Text(I18n.inline('Приєднатися до команди', 'Join this team')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4caf50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      },
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
                      backgroundColor: const Color(0xFF111827),
                      title: Text(
                        I18n.inline('Покинути команду?', 'Leave team?'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        isCaptain
                            ? I18n.inline(
                                'Ви капітан. Після виходу капітанство буде передано іншому учаснику.',
                                'You are captain. On leave, captain role will be transferred to another member.',
                              )
                            : I18n.inline(
                                'Ви справді хочете покинути цю команду?',
                                'Do you really want to leave this team?',
                              ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(I18n.t('cancel'),
                              style: const TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            I18n.inline('Покинути', 'Leave'),
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
                await _teamService.leaveTeam(teamId: team.id, userId: userId);
                if (!mounted) return;
                Navigator.pop(context); // назад зі сторінки команди
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      I18n.inline('Ви покинули команду', 'You left the team'),
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(I18n.inline('Помилка: $e', 'Error: $e')),
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
            ? I18n.inline('Вихід...', 'Leaving...')
            : I18n.inline('Покинути команду', 'Leave team'),
        style: const TextStyle(color: Colors.redAccent),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}

  Widget _joinStatusBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendJoinRequest(AppTeam team) async {
    if (_isSendingJoinRequest) return;
    setState(() => _isSendingJoinRequest = true);
    try {
      await _teamService.requestToJoinTeam(
        teamId: team.id,
        teamName: team.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
                'Запит на приєднання надіслано', 'Join request sent'),
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
      await _teamService.respondToJoinRequest(
        request: request,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? I18n.inline('Гравця додано до команди', 'Player accepted')
                : I18n.inline('Запит відхилено', 'Request declined'),
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

  Widget _buildMetricGrid(AppTeam team, TeamStats stats) {
    final totalMatches = stats.matches;
    final goalDiff = stats.goalDiff;
    final avgGoals =
        totalMatches == 0 ? '0.0' : (stats.goalsFor / totalMatches).toStringAsFixed(1);
    final metrics = [
      _MetricTileData(
        icon: Icons.auto_graph,
        value: avgGoals,
        title: I18n.inline('Голи / матч', 'Goals / match'),
        caption: I18n.inline('Ритм атаки', 'Attack tempo'),
      ),
      _MetricTileData(
        icon: Icons.shield,
        value: '${stats.goalsAgainst}',
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
        childAspectRatio: 1.2,
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

  Widget _buildHighlights(AppTeam team, TeamStats stats) {
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
              '+${stats.wins} / -${stats.losses} / =${stats.draws}',
          caption: I18n.inline('Свіжа статистика', 'Fresh stats'),
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
        title: I18n.inline('Бомбардирів ще немає', 'No scorers yet'),
        value: I18n.inline('Забий перший гол', 'Score the first goal'),
        caption: I18n.inline('Список оновлюється миттєво', 'Table updates right away'),
      );
    }
    final entries = stats.playerGoals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.inline('Бомбардири команди', 'Team top scorers'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...top.map((entry) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(entry.key)
                  .get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final name = (data?['displayName'] ??
                        data?['name'] ??
                        I18n.inline('Гравець', 'Player'))
                    .toString();
                final avatarUrl =
                    (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      PlayerAvatarButton(
                        userId: entry.key,
                        displayName: name,
                        avatarUrl: avatarUrl,
                        size: 42,
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
                            Text(
                              I18n.inline('Гравець команди', 'Squad member'),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${entry.value} ⚽',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )),
      ],
    );
  }

  Widget _buildJoinRequests(AppTeam team) {
    return StreamBuilder<List<TeamJoinRequest>>(
      stream: _teamService.watchJoinRequests(team.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final requests = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.inline('Запити до команди', 'Join requests'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...requests.map(_joinRequestTile),
          ],
        );
      },
    );
  }

  Widget _joinRequestTile(TeamJoinRequest request) {
    final busy = _processingJoinRequestIds.contains(request.id);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(request.userId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? const <String, dynamic>{};
        final avatarUrl = (userData['avatarUrl'] ?? userData['photoUrl'] ?? '').toString();
        final name = userData['displayName'] ??
            userData['name'] ??
            request.userName;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              PlayerAvatarButton(
                userId: request.userId,
                displayName: name.toString(),
                avatarUrl: avatarUrl,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM, HH:mm').format(request.createdAt),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed:
                        busy ? null : () => _handleJoinResponse(request, false),
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    tooltip: I18n.inline('Відхилити', 'Decline'),
                  ),
                  IconButton(
                    onPressed:
                        busy ? null : () => _handleJoinResponse(request, true),
                    icon: const Icon(Icons.check, color: Color(0xFF4caf50)),
                    tooltip: I18n.inline('Підтвердити', 'Accept'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  Widget _buildTopScorerCard(TeamStats stats) {
    if (stats.playerGoals.isEmpty) {
      return _highlightTile(
        icon: Icons.stars,
        title: I18n.inline('Очікує героя', 'Awaiting hero'),
        value: I18n.inline('Ще без забитих', 'No goals yet'),
        caption: I18n.inline('Перший гол запише історію', 'First scorer writes history'),
      );
    }
    final entries = stats.playerGoals.entries.toList()
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

  Widget _buildRecentMatches(TeamStats stats) {
    final recent = stats.recentMatches.take(4).toList();
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
    final matchId = (match['matchId'] ?? '').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: matchId.isEmpty ? null : () => _openMatchDetails(matchId),
      child: Container(
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
      ),
    );
  }

  Future<void> _openMatchDetails(String matchId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Матч не знайдено', 'Match not found')),
          ),
        );
        return;
      }
      final match = app_match.Match.fromFirestore(doc);
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
          content: Text(I18n.inline('Не вдалося відкрити матч: $e', 'Unable to open match: $e')),
        ),
      );
    }
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
              return InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/player-profile',
                    arguments: {
                      'playerId': memberId,
                      'playerName': name,
                    },
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      PlayerAvatarButton(
                        userId: memberId,
                        displayName: name,
                        avatarUrl: avatarUrl,
                        size: 36,
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
  await _teamService.leaveTeam(teamId: team.id, userId: memberId);
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
    final currentUserId = AppAuthContext.userId;
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
                    final isSelf = currentUserId != null && id == currentUserId;
                    final disabled =
                        (!checked && selected.length >= limit) || isSelf;
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
                      subtitle: isSelf
                          ? Text(
                              I18n.inline('Капітан команди', 'Team captain'),
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
    if (currentUserId != null) {
      selected.add(currentUserId);
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
    final results = await _teamService.searchPlayers(query, limit: 10);
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
              cursorColor: Colors.white,
              style: const TextStyle(color: Colors.white),
              onChanged: _handleSearchChanged,
              onSubmitted: (_) => _searchPlayers(),
              decoration: InputDecoration(
                hintText: I18n.inline('Пошук за ім’ям', 'Search by name'),
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
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

