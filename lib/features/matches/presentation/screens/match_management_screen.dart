import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/auth/domain/entities/user_profile_snapshot.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/features/matches/domain/repositories/matches_repository.dart';
import 'package:flap_app/features/teams/domain/repositories/teams_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/team_logo_button.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'dart:math';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
class MatchManagementScreen extends StatefulWidget {
  final Match match;
  final int initialTabIndex;

  const MatchManagementScreen({Key? key, required this.match, this.initialTabIndex = 1}) : super(key: key);

  @override
  _MatchManagementScreenState createState() => _MatchManagementScreenState();
}

class _MatchManagementScreenState extends State<MatchManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  MatchesRepository get _matchesRepo => context.read<MatchesRepository>();

  List<String> _pendingApplications = [];
  List<String> _participants = [];
  bool _isLoading = false;
  final Set<String> _busyUserIds = {};
  int _teamAScore = 0;
  int _teamBScore = 0;

  bool _editMode = false;
  List<String> _editingTeamA = [];
  List<String> _editingTeamB = [];
  final Set<String> _locked = {};
  bool _isSavingTeams = false;
  bool _showResultForm = false;
  bool _savingResults = false;
  final Map<int, TextEditingController> _winsControllers = {};
  final Map<int, TextEditingController> _goalsControllers = {};
  Map<String, double> _ratingsCache = {};
  Match? _latestMatch;
  int _teamCount = 2;
  final List<Color> _teamColors = [
    const Color(0xFF1976D2),
    const Color(0xFF8E24AA),
    const Color(0xFF43A047),
    const Color(0xFFFF7043),
  ];
  List<List<String>> _editingTeams = [[], []];

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, _ClubInfo> _clubCache = {};

  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    try {
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'display_name, first_name, last_name, email, avatar_url, rating, wins, draws, losses',
          )
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        final fallback = <String, dynamic>{
          'displayName': I18n.t('player'),
          'avatarUrl': '',
          'photoUrl': '',
          'rating': 0.0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
        };
        _userCache[userId] = fallback;
        return fallback;
      }
      final data = Map<String, dynamic>.from(row);
      final snap = UserProfileSnapshot.fromSupabaseRow(data);
      final display = snap.resolveDisplayName().isNotEmpty
          ? snap.resolveDisplayName()
          : I18n.t('player');
      final profile = <String, dynamic>{
        'displayName': display,
        'avatarUrl': (data['avatar_url'] ?? '').toString(),
        'photoUrl': data['avatar_url'],
        'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
        'wins': data['wins'] ?? 0,
        'draws': data['draws'] ?? 0,
        'losses': data['losses'] ?? 0,
      };
      _userCache[userId] = profile;
      return profile;
    } catch (_) {
      final fallback = <String, dynamic>{
        'displayName': I18n.t('player'),
        'avatarUrl': '',
        'photoUrl': '',
        'rating': 0.0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
      };
      _userCache[userId] = fallback;
      return fallback;
    }
  }

  Future<_ClubInfo> _getClubInfo(
    String? teamId,
    Team? fallback, {
    required String fallbackLabel,
  }) async {
    final fbName = fallback?.name;
    final effectiveLabel =
        (fbName != null && fbName.isNotEmpty) ? fbName : fallbackLabel;

    if (teamId == null || teamId.isEmpty) {
      return _ClubInfo.fromTeam(fallback, fallbackLabel: effectiveLabel);
    }

    final cached = _clubCache[teamId];
    if (cached != null) return cached;

    try {
      final team = await context.read<TeamsRepository>().getTeam(teamId);
      if (team == null) {
        final info = _ClubInfo.fromTeam(fallback, fallbackLabel: effectiveLabel);
        _clubCache[teamId] = info;
        return info;
      }
      final info = _ClubInfo(
        name: team.name.isNotEmpty ? team.name : effectiveLabel,
        logoUrl: team.logoUrl ?? '',
        rating: fallback?.averageRating ?? 0.0,
      );
      _clubCache[teamId] = info;
      return info;
    } catch (_) {
      final info = _ClubInfo.fromTeam(fallback, fallbackLabel: effectiveLabel);
      _clubCache[teamId] = info;
      return info;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _loadMatchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
        for (final c in _winsControllers.values) {
      c.dispose();
    }
    for (final c in _goalsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t('confirm'))),
        ],
      ),
    );
  }

  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);

    try {
      final updatedMatch = await _matchesRepo.fetchMatch(widget.match.id);
      if (updatedMatch != null) {
        setState(() {
          _latestMatch = updatedMatch;
          _pendingApplications = updatedMatch.pendingApplications;
          _participants = updatedMatch.participants;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка завантаження: $e', 'Error loading: $e')), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              I18n.inline('Управління матчем', 'Match Management'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_pendingApplications.isNotEmpty) ...[
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  I18n.inline('+${_pendingApplications.length} заявок', '+${_pendingApplications.length} applications'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: StreamBuilder<Match?>(
            stream: _matchesRepo.watchMatch(widget.match.id),
            builder: (context, snap) {
              final m = snap.data ?? widget.match;
              final pendingCount = m.pendingApplications.length;
              final participantsCount = m.participants.length;

              return TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(I18n.inline('Заявки', 'Applications')),
                          const SizedBox(width: 6),
                          if (pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(I18n.inline('Команди', 'Teams')),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$participantsCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Tab(text: I18n.t('settings')),
                ],
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationsTab(),
          _buildTeamsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildApplicationsTab() {
    return StreamBuilder<Match?>(
      stream: _matchesRepo.watchMatch(widget.match.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
        }
        final updated = snap.data ?? widget.match;
        final pending = updated.pendingApplications;
        if (pending.isEmpty) {
          return Center(child: Text(I18n.inline('Немає заявок', 'No applications'), style: const TextStyle(color: Colors.white70)));
        }
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: pending.length,
          itemBuilder: (context, index) => _buildApplicationCard(pending[index]),
        );
      },
    );
  }

  // -------- TEAMS TAB --------

  Widget _buildTeamsTab() {
    return StreamBuilder<Match?>(
      stream: _matchesRepo.watchMatch(widget.match.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
        }
        final match = snap.data ?? widget.match;
        final isOrganizer = AppAuthContext.userId == match.organizerId;
        return _buildTeamsContent(match, isOrganizer);
      },
    );
  }

Widget _buildTeamsContent(Match m, bool isOrganizer) {
  if (_showResultForm && !m.isInProgress) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showResultForm = false);
    });
  }

  if (_winsControllers.length != m.allTeams.length) {
    _winsControllers.clear();
    _goalsControllers.clear();
    for (var i = 0; i < m.allTeams.length; i++) {
      _winsControllers[i] = TextEditingController();
      _goalsControllers[i] = TextEditingController();
    }
  }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 32),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTeamsHeader(m, isOrganizer),
              if (m.isTeamMatch) ...[
                const SizedBox(height: 12),
                _buildTeamConfirmationCard(m, isOrganizer),
              ],
              if (!m.isTeamMatch && m.participants.length >= 2) ...[
                const SizedBox(height: 12),
                _buildTeamCountSelector(m),
              ],
              const SizedBox(height: 20),
              if (!m.hasTeams && m.participants.length >= 2) _buildAutoFormButton(),
              if (m.hasTeams && !_editMode) ...[
                _buildBalanceAndManagement(m),
              ],
              if (_editMode) _buildEditingSection(m),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamsHeader(Match m, bool isOrganizer) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                I18n.inline('Команди', 'Teams'),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  I18n.inline('${m.participants.length} учасників', '${m.participants.length} participants'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (m.hasTeams && isOrganizer)
          TextButton.icon(
                      onPressed: () {
            if (_editMode) {
              setState(() => _editMode = false);
            } else {
              _enterEditMode(m);
            }
          },
            icon: Icon(_editMode ? Icons.close : Icons.edit, color: Colors.white70),
            label: Text(
              _editMode
                  ? I18n.inline('Завершити редагування', 'Finish editing')
                  : I18n.inline('Редагувати склади', 'Edit teams'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamCountSelector(Match m) {
  return Wrap(
    spacing: 8,
    runSpacing: 4,
    children: List.generate(3, (index) {
      final value = index + 2;
      final enabled = m.participants.length >= value;
      return ChoiceChip(
        label: Text(I18n.inline('$value команди', '$value teams')),
        selected: _teamCount == value,
        onSelected: enabled ? (selected) => setState(() => _teamCount = value) : null,
      );
    }),
  );
}

Widget _buildAutoFormButton() {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _autoBalanceTeams,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4caf50),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shuffle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(
            I18n.inline('Сформувати команди', 'Form teams'),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

Widget _buildBalanceAndManagement(Match m) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.scale, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              I18n.inline('Баланс команд', 'Team Balance'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (!m.isTeamMatch)
              TextButton.icon(
                onPressed: () async {
                  final ok = await _confirm(
                    I18n.inline('Перемішати команди?', 'Shuffle teams?'),
                    I18n.inline('Переформувати склади на основі рейтингу', 'Reform teams based on ratings'),
                  );
                  if (ok == true) await _shuffleTeams(m);
                },
                icon: const Icon(Icons.shuffle, color: Colors.white),
                label: Text(I18n.inline('Перемішати', 'Shuffle'), style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        m.isTeamMatch ? _buildClubVsCard(m) : _buildTeamsWrap(m),
        const SizedBox(height: 20),
        Text(
          I18n.inline('Управління матчем', 'Match Management'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _buildManagementButtons(m),
if (_showResultForm && (m.teamCount ?? 2) > 2)
  _buildResultsTable(m),
      ],
    ),
  );
}

Widget _buildTeamsWrap(Match m) {
  final visibleTeams = m.allTeams.where((team) => team.playerIds.isNotEmpty).toList();

  final cards = List.generate(visibleTeams.length, (index) {
    final team = visibleTeams[index];
    final players = team.playerIds;
    final total = _teamTotalRating(players, _ratingsCache, team.averageRating);
    return _mvpTeamCard(
      title: team.name.isNotEmpty
          ? team.name
          : '${I18n.inline('Команда', 'Team')} ${index + 1}',
      color: _teamColors[index % _teamColors.length],
      total: total,
      players: players,
      ratings: _ratingsCache,
    );
  });

  if (cards.length == 2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
      ],
    );
  }

  return Wrap(
    spacing: 16,
    runSpacing: 16,
    children: List.generate(cards.length, (index) {
      return SizedBox(
        width: MediaQuery.of(context).size.width /
                (visibleTeams.length >= 2 ? 2 : 1) -
            24,
        child: cards[index],
      );
    }),
  );
}

Widget _buildClubVsCard(Match m) {
  return FutureBuilder<_ClubCardData>(
    future: _prepareClubCardData(m),
    builder: (context, snapshot) {
      final infos = snapshot.data?.infos ??
          [
            _ClubInfo.fromTeam(m.teamA, fallbackLabel: I18n.inline('Команда А', 'Team A')),
            _ClubInfo.fromTeam(m.teamB, fallbackLabel: I18n.inline('Команда Б', 'Team B')),
          ];
      final ratings = snapshot.data?.ratings ?? _ratingsCache;

      Widget buildSide(_ClubInfo info, List<String> roster, double total, String? teamId) {
        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TeamLogoButton(
                teamId: teamId,
                teamName: info.name,
                logoUrl: info.logoUrl,
                size: 60,
              ),
              const SizedBox(height: 8),
              Text(
                info.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${I18n.inline('Рейтинг', 'Rating')}: ${total.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${roster.length} ${I18n.t('players').toLowerCase()}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        );
      }

      final rosterA = m.teamRosters['teamA'] ?? m.teamA?.playerIds ?? const <String>[];
      final rosterB = m.teamRosters['teamB'] ?? m.teamB?.playerIds ?? const <String>[];
      final totalA = _teamTotalRating(rosterA, ratings, infos[0].rating ?? 0);
      final totalB = _teamTotalRating(rosterB, ratings, infos[1].rating ?? 0);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            buildSide(infos[0], rosterA, totalA, m.teamAId),
            Column(
              children: [
                Text(
                  I18n.inline('vs', 'vs'),
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rosterA.length}-${rosterB.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            buildSide(infos[1], rosterB, totalB, m.teamBId),
          ],
        ),
      );
    },
  );
}

double _calculateWinRateFromProfile(Map<String, dynamic>? profile) {
  if (profile == null) return 0.0;
  final wins = (profile['wins'] ?? 0) as num;
  final draws = (profile['draws'] ?? 0) as num;
  final losses = (profile['losses'] ?? 0) as num;
  final total = wins + draws + losses;
  if (total <= 0) return 0.0;
  return (wins / total) * 100;
}

Future<_ClubCardData> _prepareClubCardData(Match m) async {
  final infos = await Future.wait([
    _getClubInfo(
      m.teamAId,
      m.teamA,
      fallbackLabel: I18n.inline('Команда А', 'Team A'),
    ),
    _getClubInfo(
      m.teamBId,
      m.teamB,
      fallbackLabel: I18n.inline('Команда Б', 'Team B'),
    ),
  ]);

  final rosterA = m.teamRosters['teamA'] ?? m.teamA?.playerIds ?? const <String>[];
  final rosterB = m.teamRosters['teamB'] ?? m.teamB?.playerIds ?? const <String>[];
  final neededIds = {
    ...rosterA,
    ...rosterB,
  }..removeWhere((id) => id.isEmpty);

  final missing = neededIds.where((id) => !_ratingsCache.containsKey(id)).toList();
  Map<String, double> mergedRatings = Map<String, double>.from(_ratingsCache);
  if (missing.isNotEmpty) {
    final fetched = await _fetchRatings(missing);
    mergedRatings.addAll(fetched);
    _ratingsCache = mergedRatings;
  }

  return _ClubCardData(infos: infos, ratings: mergedRatings);
}

Widget _buildManagementButtons(Match m) {
  final totalTeams = m.teamCount ?? m.allTeams.length;
  final awaitingTeamConfirmations =
      m.isTeamMatch && !m.hasConfirmedPlayersForBothTeams;
  final isOrganizer = AppAuthContext.userId == m.organizerId;

  VoidCallback? primaryAction;
  IconData primaryIcon = Icons.play_arrow;
  String primaryLabel = I18n.t('start_match');
  Color primaryColor = const Color(0xFF4caf50);

  if (m.isInProgress) {
    primaryIcon = Icons.flag;
    primaryLabel = I18n.t('finish_match');
    primaryColor = const Color(0xFFFFA000);
    primaryAction = totalTeams > 2
        ? () {
            setState(() {
              _showResultForm = true;
            });
          }
        : _showFinishMatchDialog;
  } else if (m.isFinished) {
    primaryIcon = Icons.check_circle;
    primaryLabel = I18n.t('status_finished');
    primaryColor = Colors.grey;
    primaryAction = null;
  } else if (m.isCancelled) {
    primaryIcon = Icons.cancel;
    primaryLabel = I18n.t('status_cancelled');
    primaryColor = Colors.grey;
    primaryAction = null;
  } else {
    if (awaitingTeamConfirmations) {
      primaryIcon = Icons.hourglass_empty;
      primaryLabel =
          I18n.inline('Очікуємо команди', 'Awaiting line-ups');
      primaryColor = Colors.grey;
      primaryAction = null;
    } else {
    primaryAction = _startMatch;
  }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: primaryAction,
              icon: Icon(primaryIcon, color: Colors.white),
              label: Text(primaryLabel, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!m.isFinished && !m.isCancelled)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ok = await _confirm(
                    I18n.inline('Скасувати матч?', 'Cancel match?'),
                    I18n.inline('Скасувати подію і повідомити учасників', 'Cancel event and notify participants'),
                  );
                  if (ok == true) await _cancelMatch();
                },
                icon: const Icon(Icons.cancel, color: Colors.white),
                label: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
      if (!m.isFinished &&
          !m.isCancelled &&
          !m.isInProgress &&
          awaitingTeamConfirmations) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                I18n.inline(
                    'Старт буде доступний, коли обидві команди підтвердять склади.',
                    'Start will unlock once both teams confirm their rosters.'),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
      if (isOrganizer &&
          !m.isInProgress &&
          !m.isFinished &&
          !m.isCancelled) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _deleteMatch,
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          label: Text(
            I18n.inline('Видалити матч', 'Delete match'),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ],
  );
}

Widget _buildResultsTable(Match m) {
  final teams = m.allTeams;
  if (teams.isEmpty) return const SizedBox.shrink();

  if (_winsControllers.length != teams.length) {
    _winsControllers.clear();
    _goalsControllers.clear();
    for (var i = 0; i < teams.length; i++) {
      _winsControllers[i] = TextEditingController();
      _goalsControllers[i] = TextEditingController();
    }
  }

  final existingStats = <int, Map<String, dynamic>>{};
  for (final stat in m.multiTeamStats) {
    final idx = stat['teamIndex'];
    if (idx is int) {
      existingStats[idx] = stat;
    }
  }

  for (var i = 0; i < teams.length; i++) {
    final saved = existingStats[i];
    if (saved == null) continue;
    final winsVal = saved['wins'];
    final goalsVal = saved['goals'];
    final winsCtrl = _winsControllers[i]!;
    final goalsCtrl = _goalsControllers[i]!;
    if (winsVal != null && winsCtrl.text.isEmpty) {
      winsCtrl.text = winsVal.toString();
    }
    if (goalsVal != null && goalsCtrl.text.isEmpty) {
      goalsCtrl.text = goalsVal.toString();
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text(
        I18n.inline('Підсумкова таблиця', 'Final standings'),
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      ...teams.asMap().entries.map((entry) {
        final index = entry.key;
        final team = entry.value;
        final winsCtrl = _winsControllers[index]!;
        final goalsCtrl = _goalsControllers[index]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name.isEmpty ? I18n.inline('Команда ${index + 1}', 'Team ${index + 1}') : team.name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _resultField(I18n.inline('Перемоги', 'Wins'), winsCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _resultField(I18n.inline('Голи', 'Goals'), goalsCtrl)),
                ],
              ),
            ],
          ),
        );
      }),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: _savingResults ? null : () => _saveResults(m),
        child: _savingResults
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(I18n.inline('Зберегти підсумки', 'Save results')),
      ),
    ],
  );
}

Future<void> _saveResults(Match m) async {
  FocusScope.of(context).unfocus();

  final stats = <Map<String, int>>[];
  bool hasAnyInput = false;
  for (var i = 0; i < m.allTeams.length; i++) {
    final winsText = _winsControllers[i]?.text.trim() ?? '';
    final goalsText = _goalsControllers[i]?.text.trim() ?? '';
    final wins = int.tryParse(winsText) ?? 0;
    final goals = int.tryParse(goalsText) ?? 0;
    if (winsText.isNotEmpty || goalsText.isNotEmpty) {
      hasAnyInput = true;
    }
    stats.add({'teamIndex': i, 'wins': wins, 'goals': goals});
  }

  if (!hasAnyInput) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(I18n.inline('Заповніть підсумки для команд', 'Please fill in results for the teams')),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() => _savingResults = true);
  try {
    final saved = await _matchesRepo.saveMultiTeamResults(m.id, stats);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Не вдалося зберегти підсумки', 'Failed to save results'))),
      );
      return;
    }

    final finished = await _matchesRepo.finishMatch(
      m.id,
      MatchResult.draw,
      m.teamAScore ?? 0,
      m.teamBScore ?? 0,
    );

    if (!finished) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Не вдалося завершити матч', 'Could not finish the match'))),
      );
      return;
    }

    setState(() => _showResultForm = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Підсумки збережено', 'Results saved'))),
    );
    await Navigator.pushNamed(
  context,
  '/match_rating',
  arguments: m.copyWith(
    status: MatchStatus.finished,
    result: MatchResult.draw,
    teamAScore: m.teamAScore ?? 0,
    teamBScore: m.teamBScore ?? 0,
    multiTeamStats: stats,
    teams: m.allTeams,
  ),
);
  } finally {
    if (mounted) {
      setState(() => _savingResults = false);
    }
  }
}

    Widget _resultField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildTeamConfirmationCard(Match m, bool isOrganizer) {
    final teamAName = m.teamA?.name ?? I18n.inline('Команда А', 'Team A');
    final teamBName = m.teamB?.name ?? I18n.inline('Команда Б', 'Team B');
    final rosterA = m.teamRosters['teamA'] ?? m.teamA?.playerIds ?? const <String>[];
    final rosterB = m.teamRosters['teamB'] ?? m.teamB?.playerIds ?? const <String>[];
    final rosterStatusesA = m.teamRosterStatus['teamA'] ?? const <String, String>{};
    final rosterStatusesB = m.teamRosterStatus['teamB'] ?? const <String, String>{};
    final statusA = m.teamAStatus ?? 'pending';
    final statusB = m.teamBStatus ?? 'pending';
    final bothConfirmed = statusA == 'confirmed' && statusB == 'confirmed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                I18n.inline('Підтвердження команд', 'Team confirmations'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bothConfirmed ? const Color(0xFF4caf50) : const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  bothConfirmed
                      ? I18n.inline('Готово', 'Ready')
                      : I18n.inline('Очікуємо', 'Pending'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _teamStatusTile(
            teamId: m.teamAId,
            name: teamAName,
            status: statusA,
            roster: rosterA,
            rosterStatuses: rosterStatusesA,
            accent: const Color(0xFF4caf50),
          ),
          const SizedBox(height: 12),
          _teamStatusTile(
            teamId: m.teamBId,
            name: teamBName,
            status: statusB,
            roster: rosterB,
            rosterStatuses: rosterStatusesB,
            accent: const Color(0xFF42a5f5),
          ),
          if (m.teamsReadyNotified && isOrganizer) ...[
            const SizedBox(height: 12),
            _infoPill(
              icon: Icons.check_circle,
              text: I18n.inline(
                  'Організатору надіслано сповіщення про готовність команд.',
                  'You received a push about teams being ready.'),
              color: const Color(0xFF81C784),
            ),
          ] else if (!bothConfirmed && isOrganizer) ...[
            const SizedBox(height: 12),
            _infoPill(
              icon: Icons.info_outline,
              text: I18n.inline(
                  'Очікуємо підтвердження від капітанів. Вони отримають пуш, щойно додадуть склади.',
                  'Waiting for captains to confirm. They get a push as soon as they submit.'),
              color: const Color(0xFFFFC107),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamStatusTile({
    required String? teamId,
    required String name,
    required String status,
    required List<String> roster,
    required Map<String, String> rosterStatuses,
    required Color accent,
  }) {
    final totalTracked =
        rosterStatuses.isNotEmpty ? rosterStatuses.length : roster.length;
    final confirmed =
        rosterStatuses.values.where((v) => v == 'confirmed').length;
    final declined =
        rosterStatuses.values.where((v) => v == 'declined').length;
    final pending = totalTracked - confirmed - declined;
    final hasResponses = rosterStatuses.isNotEmpty;
    final statusColor = _teamStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TeamLogoButton(
                teamId: teamId,
                teamName: name,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _teamStatusText(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasResponses && totalTracked > 0) ...[
            LinearProgressIndicator(
              value: totalTracked == 0 ? 0 : confirmed / totalTracked,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 6),
            Text(
              I18n.inline(
                  'Підтверджено $confirmed з $totalTracked',
                  'Confirmed $confirmed of $totalTracked'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _statusCounter(
                  icon: Icons.check_circle,
                  color: const Color(0xFF4caf50),
                  value: confirmed,
                ),
                const SizedBox(width: 8),
                _statusCounter(
                  icon: Icons.timelapse,
                  color: const Color(0xFFFFC107),
                  value: max(pending, 0),
                ),
                const SizedBox(width: 8),
                _statusCounter(
                  icon: Icons.cancel,
                  color: const Color(0xFFE53935),
                  value: max(declined, 0),
                ),
              ],
            ),
          ] else ...[
            Text(
              I18n.inline(
                  'Очікуємо відповіді капітана. Гравці команди ще не підтвердили участь.',
                  'Waiting for captain response. Players have not confirmed yet.'),
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            if (roster.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                I18n.inline(
                    'Вказано ${roster.length} гравців у складі.',
                    '${roster.length} players assigned in roster.'),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusCounter({
    required IconData icon,
    required Color color,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _teamStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return I18n.inline('Підтверджено', 'Confirmed');
      case 'declined':
        return I18n.inline('Відхилено', 'Declined');
      default:
        return I18n.inline('Очікує', 'Pending');
    }
  }

  Color _teamStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFFFFC107);
    }
  }

Widget _buildEditingSection(Match m) {
  return FutureBuilder<Map<String, double>>(
        future: _ratingsCache.isEmpty
        ? _fetchRatings(_editingTeams.expand((team) => team).toList()).then((loaded) {
            _ratingsCache = loaded;
            return loaded;
          })
        : Future.value(_ratingsCache),
    builder: (context, rSnap) {
      final ratings = rSnap.data ?? _ratingsCache;
      final editingSets = _editingTeams.isNotEmpty ? _editingTeams : [_editingTeamA, _editingTeamB];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.balance, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                I18n.inline('Кількість команд: ${editingSets.length}', 'Teams: ${editingSets.length}'),
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    final first = editingSets.first;
                    editingSets.removeAt(0);
                    editingSets.add(first);
                  });
                },
                icon: const Icon(Icons.loop, color: Colors.white70),
                label: Text(I18n.inline('Ротація', 'Rotate'), style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(editingSets.length, (index) {
              final teamPlayers = editingSets[index];
              return SizedBox(
                width: MediaQuery.of(context).size.width / (editingSets.length >= 2 ? 2 : 1) - 24,
                child: _dragZone(
                  title: I18n.inline('Команда ${index + 1}', 'Team ${index + 1}'),
                  players: teamPlayers,
                  onRemove: (id) {
                    if (_locked.contains(id)) return;
                    setState(() => teamPlayers.remove(id));
                  },
                  onAcceptFromOther: (id) {
                    if (_locked.contains(id)) return;
                    setState(() {
                      for (final list in editingSets) {
                        if (list != teamPlayers) list.remove(id);
                      }
                      teamPlayers.add(id);
                    });
                  },
                  locked: _locked,
                  onToggleLock: (id) => setState(() {
                    _locked.contains(id) ? _locked.remove(id) : _locked.add(id);
                  }),
                  ratings: ratings,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSavingTeams
                  ? null
                  : () async {
                      final ok = await _confirm(
                        I18n.inline('Зберегти склади?', 'Save teams?'),
                        I18n.inline('Оновити всі команди для цього матчу', 'Update all teams for this match'),
                      );
                      if (ok != true) return;
                      setState(() => _isSavingTeams = true);
                      final success = await _matchesRepo.updateTeamsFlexible(widget.match.id, editingSets);
                      setState(() => _isSavingTeams = false);
                      if (success) {
                        setState(() => _editMode = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(I18n.inline('Склади збережено', 'Rosters saved')), backgroundColor: const Color(0xFF4caf50)),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(I18n.inline('Не вдалося зберегти склади', 'Failed to save teams')), backgroundColor: Colors.red),
                        );
                      }
                    },
              icon: _isSavingTeams
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSavingTeams ? I18n.inline('Збереження…', 'Saving…') : I18n.inline('Зберегти склади', 'Save teams'),
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4caf50),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    },
  );
}
  
void _enterEditMode(Match m, {bool manual = false}) {
  _editMode = true;
  _locked.clear();
  _ratingsCache.clear();

  final sourceTeams = m.allTeams;
if (!manual && sourceTeams.isNotEmpty) {
  _editingTeams = sourceTeams
      .map((team) => List<String>.from(team.playerIds))
      .toList();
  _editingTeamA = _editingTeams.isNotEmpty ? _editingTeams.first : [];
  _editingTeamB = _editingTeams.length > 1 ? _editingTeams[1] : [];
} else {
  _editingTeamA = [];
  _editingTeamB = [];
  _editingTeams = [[], []];
}
  setState(() {});
}

List<List<String>> _autoDistributePlayers(
  List<String> playerIds,
  Map<String, double> ratings,
  int teamCount,
) {
  final rnd = Random();
  final cleaned = playerIds.where((id) => id.isNotEmpty).toList();
  if (teamCount < 2 || cleaned.length < teamCount) {
    return List.generate(teamCount, (_) => <String>[]);
  }

  List<List<String>> best = List.generate(teamCount, (_) => <String>[]);
  double bestGap = double.infinity;

  for (var attempt = 0; attempt < 200; attempt++) {
    final shuffled = [...cleaned]..shuffle(rnd);
    final candidate = List.generate(teamCount, (_) => <String>[]);
    final totals = List<double>.filled(teamCount, 0);

    for (final playerId in shuffled) {
      final rating = ratings[playerId] ?? 0.0;

      var target = 0;
      var minTotal = totals[0];
      for (var i = 1; i < teamCount; i++) {
        final total = totals[i];
        if (total < minTotal || (total == minTotal && candidate[i].length < candidate[target].length)) {
          target = i;
          minTotal = total;
        }
      }

      candidate[target].add(playerId);
      totals[target] += rating;
    }

    final maxTotal = totals.reduce(max);
    final minTotal = totals.reduce(min);
    final gap = maxTotal - minTotal;

    if (gap < bestGap - 0.01 || (gap <= bestGap + 0.01 && rnd.nextBool())) {
      bestGap = gap;
      best = candidate.map((team) => List<String>.from(team)).toList();
      if (bestGap == 0) break;
    }
  }

  return best;
}

Future<void> _shuffleTeams(Match match) async {
  setState(() => _isLoading = true);
  try {
    final ids = match.participants.map((e) => e.toString()).toList();
    if (ids.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Потрібно мінімум 2 гравці', 'Need at least 2 players'))),
      );
      return;
    }

    final ratings = await _fetchRatings(ids);
    final balanced = _autoDistributePlayers(ids, ratings, _teamCount);

    final ok = await _matchesRepo.updateTeamsFlexible(match.id, balanced);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Не вдалося зберегти склади', 'Failed to save rosters'))),
      );
      return;
    }

    await _matchesRepo.ensureFixtures(match.id);

setState(() {
  _ratingsCache = {};
  _editingTeams = [];
  _editingTeamA = [];
  _editingTeamB = [];
});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Команди перемішано!', 'Teams shuffled!'))),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Помилка перемішування: $e', 'Shuffle error: $e'))),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

Widget _buildSettingsTab() {
  return StreamBuilder<Match?>(
    stream: _matchesRepo.watchMatch(widget.match.id),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
      }

      final m = snap.data ?? widget.match;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.inline('Керування матчем', 'Match Management'),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            if (m.hasTeams && !m.isInProgress && !m.isFinished && !m.isCancelled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startMatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text(I18n.t('start_match'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (m.isInProgress)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : ((m.teamCount ?? 2) > 2
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(I18n.inline(
                                    'Для 3+ команд завершуйте ігри у секції турніру нижче',
                                    'For 3+ teams finish games in the tournament section below',
                                  )),
                                ),
                              );
                            }
                          : _showFinishMatchDialog),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf44336),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stop, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text(I18n.t('finish_match'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.inline('Статус: ${m.statusText}', 'Status: ${m.statusText}'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (m.isInProgress && m.startedAt != null)
                    Text('Почався: ${_formatDateTime(m.startedAt!)}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (m.isFinished && m.finishedAt != null)
                    Text(I18n.inline('Завершився: ${_formatDateTime(m.finishedAt!)}', 'Finished: ${_formatDateTime(m.finishedAt!)}'),
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (m.hasTeams)
                    Text(I18n.inline('Команди сформовані', 'Teams formed'), style: const TextStyle(color: Colors.green, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
// Картка заявки
Widget _buildApplicationCard(String userId) {
  return Container(
    margin: EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок заявки з даними користувача (імʼя/аватар/рейтинг)
        FutureBuilder<Map<String, dynamic>>(
          future: _getUserProfile(userId),
          builder: (context, snap) {
            final data = snap.data ??
                <String, dynamic>{
                  'displayName': I18n.t('player'),
                  'avatarUrl': '',
                  'rating': 0.0,
                };
            final String displayName =
                (data['displayName'] ?? I18n.t('player')).toString();
            final String avatarUrl =
                ((data['avatarUrl'] ?? data['photoUrl']) ?? '').toString();
            final double rating = (data['rating'] is num)
                ? (data['rating'] as num).toDouble()
                : 0.0;

            return InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/player-profile',
                  arguments: {
                    'playerId': userId,
                    'playerName': displayName,
                  },
                );
              },
              child: Row(
                children: [
                  PlayerAvatarButton(
                    userId: userId,
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFFD54F),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(2),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${userId.substring(0, 6)}…',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _busyUserIds.contains(userId) ? null : () async {
                  final sure = await _confirm(I18n.inline('Прийняти гравця?', 'Accept player?'), I18n.inline('Додати користувача до учасників матчу', 'Add user to match participants'));
                  if (sure != true) return;
                  setState(() => _busyUserIds.add(userId));
                  await _acceptApplication(userId);
                  setState(() => _busyUserIds.remove(userId));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4caf50),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _busyUserIds.contains(userId) ? I18n.inline('Приймаю…', 'Accepting…') : I18n.t('accept'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _busyUserIds.contains(userId) ? null : () async {
                  final sure = await _confirm('Відхилити заявку?', 'Перемістити користувача до відхилених');
                  if (sure != true) return;
                  setState(() => _busyUserIds.add(userId));
                  await _rejectApplication(userId);
                  setState(() => _busyUserIds.remove(userId));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _busyUserIds.contains(userId) ? I18n.inline('Відхиляю…', 'Rejecting…') : I18n.t('reject'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<Map<String, double>> _fetchRatings(List<String> ids) async {
  final Map<String, double> result = {};
  if (ids.isEmpty) return result;
  const int chunkSize = 100;
  for (var i = 0; i < ids.length; i += chunkSize) {
    final end = i + chunkSize > ids.length ? ids.length : i + chunkSize;
    final chunk = ids.sublist(i, end);
    try {
      final rows = await Supabase.instance.client
          .from('user_profiles')
          .select('id,rating')
          .inFilter('id', chunk);
      for (final raw in (rows as List)) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id']?.toString();
        if (id == null) continue;
        final r =
            (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0.0;
        result[id] = r;
      }
    } catch (_) {}
    for (final id in chunk) {
      result.putIfAbsent(id, () => 0.0);
    }
  }
  return result;
}

double _teamTotalRating(List<String> players, Map<String, double> ratings, double remoteAvg) {
  if (players.isEmpty) return 0.0;
  if (ratings.isEmpty) {
    return remoteAvg * players.length;
  }
  double sum = 0.0;
  var hasData = false;
  for (final id in players) {
    final value = ratings[id];
    if (value != null) {
      sum += value;
      hasData = true;
    }
  }
  return hasData ? sum : remoteAvg * players.length;
}
  // Прийняття заявки
  Future<void> _acceptApplication(String userId) async {
    try {
      final success = await _matchesRepo.acceptApplication(widget.match.id, userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Гравця прийнято!', 'Player accepted!')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        _loadMatchData(); // Оновлюємо дані
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Не вдалося прийняти гравця', 'Failed to accept player')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Відхилення заявки
  Future<void> _rejectApplication(String userId) async {
    try {
      final success = await _matchesRepo.rejectApplication(widget.match.id, userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Заявку відхилено', 'Application rejected')),
            backgroundColor: Colors.orange,
          ),
        );
        _loadMatchData(); // Оновлюємо дані
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Не вдалося відхилити заявку', 'Failed to reject application')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _mvpTeamCard({
  required String title,
  required Color color,
  required double total,
  required List<String> players,
  required Map<String, double> ratings,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.6), width: 2),
      color: Colors.white.withOpacity(0.02),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Row(
  children: [
    const Icon(Icons.bolt, color: Color(0xFFFFD54F), size: 20),
    const SizedBox(width: 6),
    Text(
      total.toStringAsFixed(1),
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
    ),
    const SizedBox(width: 6),
    Expanded(
      child: Text(
        I18n.inline('загальний рейтинг', 'total rating'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    ),
  ],
),
        const SizedBox(height: 12),
        ...players.map((id) {
          final r = ratings[id] ?? 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getUserProfile(id),
              builder: (context, snap) {
                final name = (snap.data?['displayName'] ?? 'Гравець') as String;
                final avatarUrl = ((snap.data?['avatarUrl'] ?? snap.data?['photoUrl']) ?? '') as String;
                final realRating = ((snap.data?['rating'] ?? r) as num).toDouble();
                final winRate = _calculateWinRateFromProfile(snap.data);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlayerAvatarButton(
                      userId: id,
                      displayName: name,
                      avatarUrl: avatarUrl,
                      size: 32,
                      borderColor: Colors.white.withOpacity(0.15),
                      borderWidth: 1,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${realRating.toStringAsFixed(2)} ${I18n.inline('rating', 'rating')}'
                            ' • ${winRate.toStringAsFixed(0)}% ${I18n.inline('вінрейт', 'win rate')}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }).toList(),
      ],
    ),
  );
}
  Widget _dragZone({
  required String title,
  required List<String> players,
  required void Function(String id) onRemove,
  required void Function(String id) onAcceptFromOther,
  required Set<String> locked,
  required void Function(String id) onToggleLock,
  required Map<String, double> ratings,
}) {
  return DragTarget<String>(
    onWillAccept: (id) => id != null && !(locked.contains(id)),
    onAccept: onAcceptFromOther,
    builder: (context, candidate, rejected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: candidate.isNotEmpty ? Colors.blueAccent : Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text('${players.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: players.map((id) {
                final isLocked = locked.contains(id);
                final r = ratings[id] ?? 0.0;
                return Draggable<String>(
  data: id,
  feedback: Material(
    color: Colors.transparent,
    child: Chip(
      label: Text(
        '${id.substring(0, 2).toUpperCase()} (${r.toStringAsFixed(2)})',
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.white,
    ),
  ),
  childWhenDragging: Opacity(
    opacity: 0.6,
    child: Chip(
      label: Text(
        '${id.substring(0, 2).toUpperCase()} (${r.toStringAsFixed(2)})',
        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
      ),
      backgroundColor: isLocked ? Colors.grey.shade200 : Colors.white,
    ),
  ),
  child: Chip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${id.substring(0, 2).toUpperCase()} (${r.toStringAsFixed(2)})',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => onToggleLock(id),
          child: Icon(isLocked ? Icons.lock : Icons.lock_open, size: 16, color: Colors.black54),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => onRemove(id),
          child: Icon(Icons.close, size: 16, color: isLocked ? Colors.black26 : Colors.black45),
        ),
      ],
    ),
    backgroundColor: isLocked ? Colors.grey.shade200 : Colors.white,
  ),
);
              }).toList(),
            ),
          ],
        ),
      );
    },
  );
}
  
  Future<void> _autoBalanceTeams() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _matchesRepo.autoBalanceTeams(widget.match.id);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Команди успішно сформовані!', 'Teams successfully formed!')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        
        // Перезавантажуємо дані
await _loadMatchData();
// Скидаємо локальні тимчасові склади
setState(() {
  _editingTeams = [];
  _editingTeamA = [];
  _editingTeamB = [];
});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка формування команд'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
    Future<void> _startMatch() async {
  setState(() => _isLoading = true);
  
  try {
    final success = await _matchesRepo.startMatch(widget.match.id);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.t('match_started')),
          backgroundColor: Color(0xFF4caf50),
        ),
      );
      
      // Перезавантажуємо дані
      await _loadMatchData();

      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка початку матчу. Перевірте, чи сформовані команди.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Помилка: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
  
  void _showFinishMatchDialog() {
  final activeMatch = _latestMatch ?? widget.match;
  final aName = activeMatch.teamA?.name ?? I18n.inline('Команда A', 'Team A');
  final bName = activeMatch.teamB?.name ?? I18n.inline('Команда B', 'Team B');

  showDialog(
    context: context,
    builder: (dialogContext) {
      final insets = MediaQuery.of(dialogContext).viewInsets;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + insets.bottom),
        child: Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: AlertDialog(
              insetPadding: EdgeInsets.zero,
              backgroundColor: const Color(0xFF2a2a2a),
              title: Text(I18n.t('finish_match'), style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      I18n.inline('Введіть рахунок матчу:', 'Enter match score:'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                aName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: I18n.inline('Голи', 'Goals'),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                onChanged: (v) => _teamAScore = int.tryParse(v) ?? 0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Padding(
                          padding: EdgeInsets.only(top: 28),
                          child: Text(':', style: TextStyle(color: Colors.white, fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                bName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: I18n.inline('Голи', 'Goals'),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                onChanged: (v) => _teamBScore = int.tryParse(v) ?? 0,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _finishMatch();
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFf44336)),
                  child: Text(I18n.t('finish_match')),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
  
  Future<void> _finishMatch() async {
    setState(() => _isLoading = true);
    
    try {
      // Визначаємо результат матчу
      MatchResult result;
      if (_teamAScore > _teamBScore) {
        result = MatchResult.teamAWins;
      } else if (_teamBScore > _teamAScore) {
        result = MatchResult.teamBWins;
      } else {
        result = MatchResult.draw;
      }

      final goalMap = await _collectGoalStats();
      if (goalMap == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final success = await _matchesRepo.finishMatch(
        widget.match.id, 
        result, 
        _teamAScore, 
        _teamBScore,
        goalsByPlayer: goalMap,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Матч завершено! Тепер гравці можуть оцінювати один одного.', 'Match finished! Now players can rate each other.')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        
        // Перезавантажуємо дані
        await _loadMatchData();
        await Navigator.pushNamed(
          context,
          '/match_rating',
          arguments: _latestMatch ?? widget.match,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Помилка завершення матчу', 'Error finishing match')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, int>?> _collectGoalStats() async {
  final activeMatch = _latestMatch ?? widget.match;
  final ids = _participants.isNotEmpty ? _participants : activeMatch.participants;
  if (ids.isEmpty) return {};
  final names = await _loadParticipantNames(ids);
  final controllers = <String, TextEditingController>{
    for (final id in ids) id: TextEditingController(text: '0')
  };
  final teamAIds = activeMatch.teamA?.playerIds ?? const <String>[];
  final teamBIds = activeMatch.teamB?.playerIds ?? const <String>[];
  final teamAName = activeMatch.teamA?.name ?? I18n.inline('Команда A', 'Team A');
  final teamBName = activeMatch.teamB?.name ?? I18n.inline('Команда B', 'Team B');

  Widget buildTeamSection(
    StateSetter setStateDialog,
    String teamName,
    List<String> teamIds,
    Color accent,
  ) {
    final teamGoals = teamIds.fold<int>(
      0,
      (sum, id) => sum + (int.tryParse(controllers[id]?.text ?? '0') ?? 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  teamName,
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${I18n.inline('Голи', 'Goals')}: $teamGoals',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...teamIds.map((id) {
            final name = names[id] ?? I18n.t('player');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: TextField(
                      controller: controllers[id],
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: I18n.inline('Голи', 'Goals'),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  final result = await showDialog<Map<String, int>?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) {
        final insets = MediaQuery.of(context).viewInsets;
        final teamAGoals = teamAIds.fold<int>(
          0,
          (sum, id) => sum + (int.tryParse(controllers[id]?.text ?? '0') ?? 0),
        );
        final teamBGoals = teamBIds.fold<int>(
          0,
          (sum, id) => sum + (int.tryParse(controllers[id]?.text ?? '0') ?? 0),
        );
        final totalGoals = teamAGoals + teamBGoals;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + insets.bottom),
          child: AlertDialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: const Color(0xFF1a1a2e),
            title: Text(
              I18n.inline('Хто забив?', 'Who scored?'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.inline(
                        'Розподіліть рівно $_teamAScore голів для $teamAName і $_teamBScore голів для $teamBName.',
                        'Assign exactly $_teamAScore goals to $teamAName and $_teamBScore goals to $teamBName.',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    buildTeamSection(setStateDialog, teamAName, teamAIds, _teamColors[0]),
                    buildTeamSection(setStateDialog, teamBName, teamBIds, _teamColors[1]),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${I18n.inline('Голи команди', 'Team goals')}: '
                            '$teamAName $teamAGoals - $teamBGoals $teamBName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${I18n.inline('Усього голів', 'Total goals')}: $totalGoals',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(I18n.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, <String, int>{}),
                child: Text(I18n.inline('Пропустити', 'Skip')),
              ),
              ElevatedButton(
                onPressed: () {
                  if (teamAGoals != _teamAScore || teamBGoals != _teamBScore) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          I18n.inline(
                            'Сума голів по гравцях має збігатися з рахунком команд',
                            'Player goal totals must match the team score',
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                  final map = <String, int>{};
                  controllers.forEach((id, ctrl) {
                    final value = int.tryParse(ctrl.text) ?? 0;
                    if (value > 0) {
                      map[id] = value;
                    }
                  });
                  Navigator.pop(ctx, map);
                },
                child: Text(I18n.t('confirm')),
              ),
            ],
          ),
        );
      },
    ),
  );

  for (final ctrl in controllers.values) {
    ctrl.dispose();
  }
  return result;
}

  Future<Map<String, String>> _loadParticipantNames(List<String> ids) async {
    final names = <String, String>{};
    if (ids.isEmpty) return names;
    const chunkSize = 50;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize > ids.length ? ids.length : i + chunkSize;
      final chunk = ids.sublist(i, end);
      try {
        final rows = await Supabase.instance.client
            .from('user_profiles')
            .select('id, display_name, first_name, last_name, email')
            .inFilter('id', chunk);
        for (final raw in (rows as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final snap = UserProfileSnapshot.fromSupabaseRow(row);
          names[id] = snap.resolveDisplayName().isNotEmpty
              ? snap.resolveDisplayName()
              : I18n.t('player');
        }
      } catch (_) {}
      for (final id in chunk) {
        names.putIfAbsent(id, () => I18n.t('player'));
      }
    }
    return names;
  }

  Future<void> _cancelMatch() async {
  setState(() => _isLoading = true);
  try {
    final success = await _matchesRepo.cancelMatch(widget.match.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('status_cancelled')), backgroundColor: Colors.redAccent),
      );
      await _loadMatchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Не вдалося скасувати матч', 'Failed to cancel match')), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e')), backgroundColor: Colors.red),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _deleteMatch() async {
    final ok = await _confirm(
      I18n.inline('Видалити матч?', 'Delete match?'),
      I18n.inline('Після підтвердження матч буде остаточно видалений.', 'This action cannot be undone.'),
    );
    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      final success = await _matchesRepo.deleteMatch(widget.match.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Матч видалено', 'Match deleted')),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Не вдалося видалити матч', 'Failed to delete match')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка: $e', 'Error: $e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _ClubInfo {
  final String name;
  final String? logoUrl;
  final double? rating;

  const _ClubInfo({
    required this.name,
    this.logoUrl,
    this.rating,
  });

  factory _ClubInfo.fromTeam(Team? team, {required String fallbackLabel}) {
    final n = team?.name;
    return _ClubInfo(
      name: (n != null && n.isNotEmpty) ? n : fallbackLabel,
      logoUrl: null,
      rating: team?.averageRating,
    );
  }
}

class _ClubCardData {
  final List<_ClubInfo> infos;
  final Map<String, double> ratings;

  const _ClubCardData({
    required this.infos,
    required this.ratings,
  });
}