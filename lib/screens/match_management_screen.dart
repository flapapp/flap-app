import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import '../services/match_service.dart';

class MatchManagementScreen extends StatefulWidget {
  final Match match;
  
  const MatchManagementScreen({Key? key, required this.match}) : super(key: key);
  
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
  final Set<String> _busyUserIds = {}; // <- додаємо
  // Змінні для завершення матчу
  int _teamAScore = 0;
  int _teamBScore = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    // Вкладка команд
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
              ],
            ),
            const SizedBox(height: 20),

            // Кнопка формування команд
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

            // Відображення команд / підказки
            if (m.hasTeams) ...[
              _buildTeamCard('Команда A', m.teamA!),
              const SizedBox(height: 16),
              _buildTeamCard('Команда B', m.teamB!),
            ] else if (m.participants.length < 4) ...[
              _hintBox(Icons.info_outline, Colors.orange, 'Для формування команд потрібно мінімум 4 гравці'),
            ] else ...[
              _hintBox(Icons.people, Colors.blue, 'Натисніть "Сформувати команди" для автоматичного розподілу'),
            ],
          ],
        ),
      );
    },
  );
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
            if (m.hasTeams && !m.isInProgress && !m.isFinished)
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
                  onPressed: _showFinishMatchDialog,
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
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF4caf50),
              child: Text(
                userId.substring(0, 2).toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Гравець ID: $userId',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Очікує відповіді',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
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

      // Перенаправляємо на екран оцінювання
      Navigator.pushReplacementNamed(
        context,
        '/match_rating',
        arguments: widget.match,
      );
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
            onPressed: () {
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
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}