import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match.dart';
import '../services/match_service.dart';
import '../utils/i18n.dart';
import 'dart:math';

class MatchManagementScreen extends StatefulWidget {
  final Match match;
  final int initialTabIndex;

  const MatchManagementScreen({Key? key, required this.match, this.initialTabIndex = 1}) : super(key: key);
  
  @override
  _MatchManagementScreenState createState() => _MatchManagementScreenState();
}

class _MatchManagementScreenState extends State<MatchManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final MatchService _matchService = MatchService();
  
  // Змінні для управління
  List<String> _pendingApplications = [];
  List<String> _participants = [];
  bool _isLoading = false;
  final Set<String> _busyUserIds = {};
  // Змінні для завершення матчу
  int _teamAScore = 0;
  int _teamBScore = 0;

  // Редактор команд (Drag&Drop)
  bool _editMode = false;
  List<String> _editingTeamA = [];
List<String> _editingTeamB = [];
final Set<String> _locked = {};
bool _isSavingTeams = false;
Map<String, double> _ratingsCache = {};
int _teamCount = 2;
final List<Color> _teamColors = [
  const Color(0xFF1976D2),
  const Color(0xFF8E24AA),
  const Color(0xFF43A047),
  const Color(0xFFFF7043),
];
List<List<String>> _editingTeams = [[], []];

    // Кеш профілів користувачів (ім'я та аватар)
  final Map<String, Map<String, dynamic>> _userCache = {};

  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data() as Map<String, dynamic>? ?? const {};
      final profile = <String, dynamic>{
  'displayName': (data['displayName'] ?? I18n.t('player')).toString(),
  'avatarUrl': ((data['avatarUrl'] ?? data['photoUrl']) ?? '').toString(),
};
      _userCache[userId] = profile;
      return profile;
    } catch (_) {
  final fallback = <String, dynamic>{'displayName': I18n.t('player'), 'avatarUrl': ''};
      _userCache[userId] = fallback;
      return fallback;
    }
  }

  String _initialsFrom(String name, String fallback) {
    final s = name.trim();
    if (s.isEmpty) return fallback.substring(0, 2).toUpperCase();
    final parts = s.split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts[0] : '';
    final second = parts.length > 1 ? parts[1] : '';
    final letters = (first.isNotEmpty ? first[0] : '') + (second.isNotEmpty ? second[0] : '');
    return letters.isEmpty ? fallback.substring(0, 2).toUpperCase() : letters.toUpperCase();
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
      // Отримуємо актуальні дані матчу
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id)
          .get();
      
      if (matchDoc.exists) {
        final updatedMatch = Match.fromFirestore(matchDoc);
        setState(() {
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
    child: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id)
          .snapshots(),
      builder: (context, snap) {
        final has = snap.hasData && snap.data!.exists;
        final m = has ? Match.fromFirestore(snap.data!) : widget.match;
        final pendingCount = has ? m.pendingApplications.length : _pendingApplications.length;
        final participantsCount = has ? m.participants.length : _participants.length;

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
  
  // Вкладка заявок
Widget _buildApplicationsTab() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.match.id)
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) {
        return Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
      }
      if (!snap.data!.exists) {
        return Center(child: Text(I18n.inline('Матч не знайдено', 'Match not found'), style: const TextStyle(color: Colors.white70)));
      }
      final updated = Match.fromFirestore(snap.data!);
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

  // Вкладка команд (автооновлення)
Widget _buildTeamsTab() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.match.id)
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
      }
      if (!snap.data!.exists) {
        return const Center(child: Text('Матч не знайдено', style: TextStyle(color: Colors.white70)));
      }

      final m = Match.fromFirestore(snap.data!);
      final isOrganizer = FirebaseAuth.instance.currentUser?.uid == m.organizerId;

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 32),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                          setState(() {
                            _editMode = !_editMode;
                            if (_editMode) {
                              _editingTeamA = List<String>.from(m.teamA?.playerIds ?? []);
                              _editingTeamB = List<String>.from(m.teamB?.playerIds ?? []);
                              _locked.clear();
                              _ratingsCache.clear();
                            }
                          });
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
                ),

                if (m.participants.length >= 2) ...[
                  const SizedBox(height: 12),
                  Wrap(
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
                  ),
                ],

                const SizedBox(height: 20),

                if (!m.hasTeams && m.participants.length >= 2)
                  SizedBox(
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
                  ),

                const SizedBox(height: 20),

                if (m.hasTeams && !_editMode) ...[
                  Container(
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

                        Builder(
                          builder: (context) {
                            final hasAnyLocal = _editingTeams.any((t) => t.isNotEmpty);
                            final sourceTeams = hasAnyLocal
                                ? _editingTeams
                                : [
                                    m.teamA?.playerIds ?? const <String>[],
                                    m.teamB?.playerIds ?? const <String>[],
                                  ];
                            final visibleTeams = sourceTeams.where((team) => team.isNotEmpty).toList();

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: List.generate(visibleTeams.length, (index) {
                                final players = visibleTeams[index];
                                final total = _teamTotalRating(players, _ratingsCache, 0);
                                return SizedBox(
                                  width: MediaQuery.of(context).size.width / (visibleTeams.length >= 2 ? 2 : 1) - 24,
                                  child: _mvpTeamCard(
                                    title: I18n.inline('Команда ${index + 1}', 'Team ${index + 1}'),
                                    color: _teamColors[index % _teamColors.length],
                                    total: total,
                                    players: players,
                                    ratings: _ratingsCache,
                                  ),
                                );
                              }),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        Text(
                          I18n.inline('Управління матчем', 'Match Management'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (m.teamCount ?? 2) > 2
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(I18n.inline(
                                              'Завершуйте кожну гру нижче у секції турніру',
                                              'Finish each game below in the tournament section',
                                            )),
                                          ),
                                        );
                                      }
                                    : (m.isInProgress
                                        ? _showFinishMatchDialog
                                        : (m.isFinished || m.isCancelled ? null : _startMatch)),
                                icon: Icon(
                                  m.isInProgress
                                      ? Icons.flag
                                      : m.isFinished
                                          ? Icons.check_circle
                                          : m.isCancelled
                                              ? Icons.cancel
                                              : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  (m.teamCount ?? 2) > 2 && !m.isInProgress
                                      ? I18n.inline('Start match', 'Start match')
                                      : (m.isInProgress
                                          ? I18n.t('finish_match')
                                          : m.isFinished
                                              ? I18n.t('status_finished')
                                              : m.isCancelled
                                                  ? I18n.t('status_cancelled')
                                                  : I18n.t('start_match')),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: m.isInProgress
                                      ? const Color(0xFFFFA000)
                                      : m.isFinished || m.isCancelled
                                          ? Colors.grey
                                          : const Color(0xFF4caf50),
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

                        const SizedBox(height: 16),

                        if ((m.teamCount ?? 2) > 2) ...[
                          Divider(color: Colors.white10),
                          Text(
                            I18n.inline('Міні-турнір (кожен з кожним)', 'Round-robin mini tournament'),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('matches')
                                .doc(m.id)
                                .collection('fixtures')
                                .snapshots(),
                            builder: (context, fxSnap) {
                              if (!fxSnap.hasData) {
                                return const SizedBox.shrink();
                              }
                              final fixtures = fxSnap.data!.docs
                                  .map((d) => (d.data() as Map<String, dynamic>))
                                  .toList();
                              if (fixtures.isEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  MatchService().ensureFixtures(m.id);
                                });
                                return Text(
                                  I18n.inline('Фікстури ще не згенеровано', 'Fixtures not generated yet'),
                                  style: const TextStyle(color: Colors.white70),
                                );
                              }
                              return Column(
                                children: fixtures.asMap().entries.map((e) {
                                  final i = e.key;
                                  final f = e.value;
                                  final a = (f['teamAName'] ?? 'Team A').toString();
                                  final b = (f['teamBName'] ?? 'Team B').toString();
                                  final done = (f['status'] ?? 'pending') == 'finished';
                                  return ListTile(
                                    dense: true,
                                    title: Text('$a  vs  $b', style: const TextStyle(color: Colors.white)),
                                    subtitle: Text(
                                      done
                                          ? I18n.inline('Завершено: ${f['scoreA']}:${f['scoreB']}', 'Finished: ${f['scoreA']}:${f['scoreB']}')
                                          : I18n.inline('Очікує результат', 'Awaiting result'),
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    trailing: done
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.white70),
                                            onPressed: () => MatchService().promptFinishGame(context, m.id, i, a, b),
                                          ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],

                        if (m.isFinished)
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/match_rating', arguments: m),
                                  icon: const Icon(Icons.star_rate_rounded),
                                  label: Text(I18n.inline('Оцінити гравців', 'Rate players')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4caf50),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],

                if (_editMode)
                  FutureBuilder<Map<String, double>>(
                    future: _ratingsCache.isEmpty
                        ? _fetchRatings([..._editingTeamA, ..._editingTeamB]).then((loaded) {
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
                                      final success = await _matchService.updateTeamsFlexible(widget.match.id, editingSets);
                                      setState(() => _isSavingTeams = false);
                                      if (success) {
                                        setState(() => _editMode = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Склади збережено'), backgroundColor: Color(0xFF4caf50)),
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
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _enterEditMode(Match m, {bool manual = false}) {
  _editMode = true;
  _locked.clear();
  _ratingsCache.clear();

  if (manual || !m.hasTeams) {
    // Порожні склади для ручного формування
    _editingTeamA = [];
    _editingTeamB = [];
  } else {
    // Редагування вже сформованих складів
    _editingTeamA = List<String>.from(m.teamA?.playerIds ?? []);
    _editingTeamB = List<String>.from(m.teamB?.playerIds ?? []);
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
void _applyDistribution(List<String> playerIds, Map<String, double> ratings, int teamCount) {
  final distributed = _autoDistributePlayers(playerIds, ratings, teamCount);
  _editingTeams = distributed;
  _editingTeamA = distributed.isNotEmpty ? distributed.first : [];
  _editingTeamB = distributed.length > 1 ? distributed[1] : [];
}

Future<void> _shuffleTeams(Match match) async {
  setState(() => _isLoading = true);
  try {
    // БЕРЕМО ВСІХ УЧАСНИКІВ (щоб ніхто не “зникав”)
    final List<String> ids = match.participants.map((e) => e.toString()).toList();
    if (ids.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Потрібно мінімум 2 гравці')),
      );
      return;
    }

    // Рейтинги + розподіл на _teamCount команд
    final ratings = _ratingsCache.isNotEmpty ? _ratingsCache : await _fetchRatings(ids);
    final balanced = _autoDistributePlayers(ids, ratings, _teamCount);

    // Локально покажемо попередній результат, щоб UI відгукнувся
    setState(() {
      _ratingsCache = ratings;
      _editingTeams = balanced;
      _editingTeamA = balanced.isNotEmpty ? balanced.first : [];
      _editingTeamB = balanced.length > 1 ? balanced[1] : [];
    });

    // Зберігаємо на сервері (ставить teamCount та teams)
    await _matchService.updateTeamsFlexible(match.id, balanced);

    // Гарантуємо наявність фікстур для 3+ команд
    await MatchService().ensureFixtures(match.id);

    // Скидаємо локальні склади — відображаємо серверні дані без миготінь
    setState(() {
      _ratingsCache = {};
      _editingTeams = [];
      _editingTeamA = [];
      _editingTeamB = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Команди перемішано!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Помилка перемішування: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
  

  // Вкладка налаштувань (автооновлення)
Widget _buildSettingsTab() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.match.id)
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
      }
      if (!snap.data!.exists) {
        return const Center(child: Text('Матч не знайдено', style: TextStyle(color: Colors.white70)));
      }

      final m = Match.fromFirestore(snap.data!);

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

            // Почати матч
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

            // Завершити матч
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

            // Інформація
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
            Text(I18n.inline('Статус: ${m.statusText}', 'Status: ${m.statusText}'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (m.isInProgress && m.startedAt != null)
                    Text('Почався: ${_formatDateTime(m.startedAt!)}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (m.isFinished && m.finishedAt != null)
                    Text(I18n.inline('Завершився: ${_formatDateTime(m.finishedAt!)}', 'Finished: ${_formatDateTime(m.finishedAt!)}'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, snap) {
            final Map<String, dynamic> data =
                (snap.hasData && snap.data!.exists)
                    ? (snap.data!.data() as Map<String, dynamic>)
                    : const {};
            final String displayName = (data['displayName'] ?? I18n.t('player')) as String;
final String avatarUrl = ((data['avatarUrl'] ?? data['photoUrl']) ?? '').toString();
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
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF4caf50),
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty ? Text(
                            userId.substring(0, 2).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
Widget _hintBox(IconData icon, Color color, String text) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 14))),
      ],
    ),
  );
}
  
Future<Map<String, double>> _fetchRatings(List<String> ids) async {
  final Map<String, double> result = {};
  const int chunkSize = 10;
  for (var i = 0; i < ids.length; i += chunkSize) {
    final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final r = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
      result[doc.id] = r;
    }
    for (final id in chunk) {
      result.putIfAbsent(id, () => 0.0);
    }
  }
  return result;
}

 double _localAvgFor(List<String> players, double remoteAvg) {
  if (_ratingsCache.isEmpty || players.isEmpty) return remoteAvg;
  double sum = 0.0;
  int n = 0;
  for (final id in players) {
    final r = _ratingsCache[id];
    if (r != null) {
      sum += r;
      n++;
    }
  }
  return n > 0 ? sum / n : remoteAvg;
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
      final success = await _matchService.acceptApplication(widget.match.id, userId);
      
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
      final success = await _matchService.rejectApplication(widget.match.id, userId);
      
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
    Widget _buildTeamCard(String teamName, Team team) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teamName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  I18n.inline('Рейтинг: ${team.averageRating.toStringAsFixed(2)}', 'Rating: ${team.averageRating.toStringAsFixed(2)}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            I18n.inline('Гравці (${team.playerIds.length}):', 'Players (${team.playerIds.length}):'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: team.playerIds.map((playerId) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  playerId.substring(0, 2).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
                final initials = _initialsFrom(name, id);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF4caf50),
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))
                          : null,
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
                            '${r.toStringAsFixed(2)} pts',
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
      final success = await _matchService.autoBalanceTeams(widget.match.id);
      
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
    final success = await _matchService.startMatch(widget.match.id);
    
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
  final aName = widget.match.teamA?.name ?? 'Команда A';
  final bName = widget.match.teamB?.name ?? 'Команда B';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2a2a2a),
      title: Text(I18n.t('finish_match'), style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(I18n.inline('Введіть рахунок матчу:', 'Enter match score:'), style: const TextStyle(color: Colors.white70)),
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
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            decoration: InputDecoration(
              labelText: I18n.inline('Голи', 'Goals'),
              labelStyle: TextStyle(color: Colors.white70),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(),
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
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            decoration: InputDecoration(
              labelText: I18n.inline('Голи', 'Goals'),
              labelStyle: TextStyle(color: Colors.white70),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () { Navigator.pop(context); _finishMatch(); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFf44336)),
          child: Text(I18n.t('finish_match')),
        ),
      ],
    ),
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
      
      final success = await _matchService.finishMatch(
        widget.match.id, 
        result, 
        _teamAScore, 
        _teamBScore
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
        await Navigator.pushNamed(context, '/match_rating', arguments: widget.match);
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

  Future<void> _cancelMatch() async {
  setState(() => _isLoading = true);
  try {
    final success = await _matchService.cancelMatch(widget.match.id);
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
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}