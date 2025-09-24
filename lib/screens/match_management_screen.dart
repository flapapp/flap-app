import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import '../services/match_service.dart';

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
  'displayName': (data['displayName'] ?? 'Гравець').toString(),
  'avatarUrl': ((data['avatarUrl'] ?? data['photoUrl']) ?? '').toString(),
};
      _userCache[userId] = profile;
      return profile;
    } catch (_) {
  final fallback = <String, dynamic>{'displayName': 'Гравець', 'avatarUrl': ''};
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Підтвердити')),
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
        SnackBar(content: Text('Помилка завантаження: $e'), backgroundColor: Colors.red),
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
              'Управління матчем',
              style: GoogleFonts.poppins(
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
                  '+${_pendingApplications.length} заявок',
                  style: GoogleFonts.poppins(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Заявки'),
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
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Команди'),
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
            const Tab(text: 'Налаштування'),
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
        return Center(child: Text('Матч не знайдено', style: TextStyle(color: Colors.white70)));
      }
      final updated = Match.fromFirestore(snap.data!);
      final pending = updated.pendingApplications;
      if (pending.isEmpty) {
        return Center(child: Text('Немає заявок', style: TextStyle(color: Colors.white70)));
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

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок з бейджем кількості учасників
            Row(
              children: [
                Text(
                  'Команди',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${m.participants.length} учасників',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                                const Spacer(),
                if (m.hasTeams && isOrganizer) ...[
                  // Тумблер редагування
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
                    label: Text(_editMode ? 'Завершити редагування' : 'Редагувати склади',
                      style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Автоформування (якщо ще нема команд)
            if (!m.hasTeams && m.participants.length >= 4)
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
                    children: const [
                      Icon(Icons.shuffle, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Сформувати команди', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

                        const SizedBox(height: 20),

            if (m.hasTeams && !_editMode) ...[
              // Баланс команд у стилі MVP
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
                    // Заголовок + Перемішати
                    Row(
                      children: [
                        Icon(Icons.scale, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text('Баланс команд',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            )),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            // швидке перемішування поверх існуючих складів
                            final ratings = _ratingsCache.isEmpty
                                ? await _fetchRatings([...m.teamA!.playerIds, ...m.teamB!.playerIds])
                                : _ratingsCache;
                            setState(() {
                              _editingTeamA = List<String>.from(m.teamA!.playerIds);
                              _editingTeamB = List<String>.from(m.teamB!.playerIds);
                              _autoDistributeEditingPlayers(ratings);
                            });
                            final ok = await _confirm('Перемішати команди?', 'Переформувати склади на основі рейтингу');
                            if (ok == true) {
                              await _matchService.updateTeams(widget.match.id, _editingTeamA, _editingTeamB);
                            }
                          },
                          icon: const Icon(Icons.shuffle, color: Colors.white),
                          label: const Text('Перемішати', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Дві картки команд
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A
                        Expanded(
                            child: _mvpTeamCard(
                            title: (m.teamA?.name?.isNotEmpty == true ? m.teamA!.name : 'Команда A'),
                            color: const Color(0xFF1976D2),
                            avg: m.teamA!.averageRating,
                            players: m.teamA!.playerIds,
                            ratings: _ratingsCache,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // B
                        Expanded(
                            child: _mvpTeamCard(
                            title: (m.teamB?.name?.isNotEmpty == true ? m.teamB!.name : 'Команда B'),
                            color: const Color(0xFF8E24AA),
                            avg: m.teamB!.averageRating,
                            players: m.teamB!.playerIds,
                            ratings: _ratingsCache,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Управління матчем
                    Text('Управління матчем',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Показуємо кнопку залежно від статусу матчу
if (m.isInProgress)
  Expanded(
    child: ElevatedButton.icon(
      onPressed: _isLoading ? null : _showFinishMatchDialog,
      icon: const Icon(Icons.flag, color: Colors.white),
      label: const Text('Завершити матч', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFA000),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  )
else if (m.isFinished)
  Expanded(
    child: ElevatedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      label: const Text('Матч завершено', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  )
else if (m.isCancelled)
  Expanded(
    child: ElevatedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.cancel, color: Colors.white),
      label: const Text('Матч скасовано', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  )
else
  Expanded(
    child: ElevatedButton.icon(
      onPressed: _startMatch,
      icon: const Icon(Icons.play_arrow, color: Colors.white),
      label: const Text('Почати матч', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4caf50),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  ),
                        const SizedBox(width: 12),
                        if (!m.isFinished && !m.isCancelled)
  Expanded(
    child: ElevatedButton.icon(
      onPressed: () async {
        final ok = await _confirm('Скасувати матч?', 'Скасувати подію і повідомити учасників');
        if (ok != true) return;
        await _cancelMatch();
      },
      icon: const Icon(Icons.cancel, color: Colors.white),
      label: const Text('Скасувати', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE53935),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (!m.hasTeams && m.participants.length < 4) ...[
              _hintBox(Icons.info_outline, Colors.orange, 'Для формування команд потрібно мінімум 4 гравці'),
            ] else if (_editMode) ...[
              // Редактор з Drag&Drop
              FutureBuilder<Map<String, double>>(
                future: _ratingsCache.isEmpty
                    ? _fetchRatings([..._editingTeamA, ..._editingTeamB]).then((m) {
                        _ratingsCache = m; return m;
                      })
                    : Future.value(_ratingsCache),
                builder: (context, rSnap) {
                  final ratings = rSnap.data ?? _ratingsCache;
                  double avgA() {
                    if (_editingTeamA.isEmpty) return 0.0;
                    return _editingTeamA.map((id) => ratings[id] ?? 0.0).fold(0.0, (a, b) => a + b) / _editingTeamA.length;
                  }
                  double avgB() {
                    if (_editingTeamB.isEmpty) return 0.0;
                    return _editingTeamB.map((id) => ratings[id] ?? 0.0).fold(0.0, (a, b) => a + b) / _editingTeamB.length;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Індикатор балансу та дії
                      Row(
                        children: [
                          Icon(Icons.balance, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text('Баланс: A ${avgA().toStringAsFixed(1)} vs B ${avgB().toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.white70)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                final tmp = _editingTeamA;
                                _editingTeamA = _editingTeamB;
                                _editingTeamB = tmp;
                              });
                            },
                            icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                            label: const Text('Поміняти місцями', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Зони перетягування
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Team A
                          Expanded(
                            child: _dragZone(
                              title: 'Команда A',
                              players: _editingTeamA,
                              onRemove: (id) { if (_locked.contains(id)) return; setState(() => _editingTeamA.remove(id)); },
                              onAcceptFromOther: (id) {
                                if (_locked.contains(id)) return;
                                setState(() {
                                  _editingTeamB.remove(id);
                                  if (!_editingTeamA.contains(id)) _editingTeamA.add(id);
                                });
                              },
                              locked: _locked,
                              onToggleLock: (id) => setState(() {
                                _locked.contains(id) ? _locked.remove(id) : _locked.add(id);
                              }),
                              ratings: ratings,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Team B
                          Expanded(
                            child: _dragZone(
                              title: 'Команда B',
                              players: _editingTeamB,
                              onRemove: (id) { if (_locked.contains(id)) return; setState(() => _editingTeamB.remove(id)); },
                              onAcceptFromOther: (id) {
                                if (_locked.contains(id)) return;
                                setState(() {
                                  _editingTeamA.remove(id);
                                  if (!_editingTeamB.contains(id)) _editingTeamB.add(id);
                                });
                              },
                              locked: _locked,
                              onToggleLock: (id) => setState(() {
                                _locked.contains(id) ? _locked.remove(id) : _locked.add(id);
                              }),
                              ratings: ratings,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingTeams ? null : () async {
                            final ok = await _confirm('Зберегти склади?', 'Оновити команди A/B для цього матчу');
                            if (ok != true) return;
                            setState(() => _isSavingTeams = true);
                            final success = await _matchService.updateTeams(
                              widget.match.id, _editingTeamA, _editingTeamB,
                            );
                            setState(() => _isSavingTeams = false);
                            if (success) {
                              setState(() => _editMode = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Склади збережено'), backgroundColor: Color(0xFF4caf50)),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Не вдалося зберегти склади'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          icon: _isSavingTeams
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, color: Colors.white),
                          label: Text(_isSavingTeams ? 'Збереження…' : 'Зберегти склади',
                              style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4caf50), padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              _hintBox(Icons.people, Colors.blue, 'Натисніть "Сформувати команди" або "Редагувати склади"'),
            ],
          ],
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

void _autoDistributeEditingPlayers(Map<String, double> ratings) {
  final List<String> all = [..._editingTeamA, ..._editingTeamB];
  _editingTeamA.clear();
  _editingTeamB.clear();

  all.sort((a, b) => (ratings[b] ?? 0.0).compareTo(ratings[a] ?? 0.0));

  for (int i = 0; i < all.length; i++) {
    (i % 2 == 0 ? _editingTeamA : _editingTeamB).add(all[i]);
  }

  setState(() {});
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
              'Керування матчем',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
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
                    children: const [
                      Icon(Icons.play_arrow, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Почати матч', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
  onPressed: _isLoading ? null : _showFinishMatchDialog,
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFf44336),
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.stop, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Завершити матч', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
                  Text('Статус: ${m.statusText}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (m.isInProgress && m.startedAt != null)
                    Text('Почався: ${_formatDateTime(m.startedAt!)}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                  if (m.isFinished && m.finishedAt != null)
                    Text('Завершився: ${_formatDateTime(m.finishedAt!)}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                  if (m.hasTeams)
                    const Text('Команди сформовані', style: TextStyle(color: Colors.green, fontSize: 14)),
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
            final String displayName = (data['displayName'] ?? 'Гравець') as String;
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
                              rating.toStringAsFixed(1),
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
                  final sure = await _confirm('Прийняти гравця?', 'Додати користувача до учасників матчу');
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
                  _busyUserIds.contains(userId) ? 'Приймаю…' : 'Прийняти',
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
                  _busyUserIds.contains(userId) ? 'Відхиляю…' : 'Відхилити',
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
        Expanded(child: Text(text, style: GoogleFonts.poppins(color: color, fontSize: 14))),
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

  
  // Прийняття заявки
  Future<void> _acceptApplication(String userId) async {
    try {
      final success = await _matchService.acceptApplication(widget.match.id, userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Гравця прийнято!'),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        _loadMatchData(); // Оновлюємо дані
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не вдалося прийняти гравця'),
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
            content: Text('Заявку відхилено'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadMatchData(); // Оновлюємо дані
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не вдалося відхилити заявку'),
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
                style: GoogleFonts.poppins(
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
                  'Рейтинг: ${team.averageRating.toStringAsFixed(1)}',
                  style: GoogleFonts.poppins(
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
            'Гравці (${team.playerIds.length}):',
            style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
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
  required double avg,
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
        Text(title,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star, color: Color(0xFFFFD54F), size: 28),
            const SizedBox(width: 8),
            Text(avg.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(width: 6),
            Text('середній рейтинг',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
                ...players.map((id) {
          final r = ratings[id] ?? 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getUserProfile(id),
              builder: (context, snap) {
                final name = (snap.data?['displayName'] ?? 'Гравець') as String;
final avatarUrl = ((snap.data?['avatarUrl'] ?? snap.data?['photoUrl']) ?? '') as String;
                final initials = _initialsFrom(name, id);

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white12,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              initials,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      r.toStringAsFixed(1),
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                );
              },
            ),
          );
        }),
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
                Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
                return LongPressDraggable<String>(
                  data: id,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Chip(
                      label: Text('${id.substring(0, 2).toUpperCase()} (${r.toStringAsFixed(1)})'),
                      backgroundColor: Colors.blueGrey.shade700,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                  child: Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${id.substring(0, 2).toUpperCase()} (${r.toStringAsFixed(1)})'),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => onToggleLock(id),
                          child: Icon(isLocked ? Icons.lock : Icons.lock_open, size: 16, color: Colors.white70),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => onRemove(id),
                          child: Icon(Icons.close, size: 16, color: isLocked ? Colors.white24 : Colors.white70),
                        ),
                      ],
                    ),
                    backgroundColor: isLocked ? Colors.white12 : Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white),
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
            content: Text('Команди успішно сформовані!'),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        
        // Перезавантажуємо дані
        await _loadMatchData();
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
          content: Text('Матч розпочато!'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2a2a2a),
        title: Text(
          'Завершити матч',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Введіть рахунок матчу:',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Команда A',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white),
                    onChanged: (value) => _teamAScore = int.tryParse(value) ?? 0,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  ':',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Команда B',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white),
                    onChanged: (value) => _teamBScore = int.tryParse(value) ?? 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Скасувати', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
  onPressed: _isLoading ? null : () {
    Navigator.pop(context);
    _finishMatch();
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFf44336),
  ),
  child: Text('Завершити'),
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
            content: Text('Матч завершено! Тепер гравці можуть оцінювати один одного.'),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        
        // Перезавантажуємо дані
        await _loadMatchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка завершення матчу'),
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
        SnackBar(content: Text('Матч скасовано'), backgroundColor: Colors.redAccent),
      );
      await _loadMatchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося скасувати матч'), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}