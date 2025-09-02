import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match.dart';
import '../services/match_service.dart';

class MatchDetailsScreen extends StatefulWidget {
  final Match match;
  
  const MatchDetailsScreen({Key? key, required this.match}) : super(key: key);

  @override
  _MatchDetailsScreenState createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  final MatchService _matchService = MatchService();
  bool _isJoining = false;
  bool _isLeaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Text(
          widget.match.title,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок та статус
            _buildHeaderSection(),
            SizedBox(height: 20),
            
            // Основна інформація
            _buildInfoSection(),
            SizedBox(height: 20),

            // Учасники
            _buildParticipantsSection(),
            SizedBox(height: 20),
            
            // Кнопки дій
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.match.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.match.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusText(widget.match.status),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Інформація про матч',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow('📅 Дата', '${widget.match.date.day}.${widget.match.date.month}.${widget.match.date.year}'),
          _buildInfoRow('⏰ Час', widget.match.time),
          _buildInfoRow('📍 Локація', widget.match.location),
          _buildInfoRow('🏙️ Місто', widget.match.city),
          _buildInfoRow('⭐ Рівень', _getLevelText(widget.match.level)),
          _buildInfoRow('💰 Вартість', '${widget.match.cost} грн'),
          _buildInfoRow('⚽ Гравці', '${widget.match.currentPlayers}/${widget.match.maxPlayers}'),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Учасники',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF4caf50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.match.participants.length}/${widget.match.maxPlayers}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (widget.match.participants.isEmpty)
            Text(
              'Поки що немає учасників',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            )
          else
            Column(
              children: [
                // Організатор (перший учасник)
                _buildParticipantCard(
                  widget.match.organizerName,
                  'Організатор',
                  true,
                ),
                SizedBox(height: 12),
                // Інші учасники
                ...widget.match.participants
                    .where((id) => id != widget.match.organizerId)
                    .map((id) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildParticipantCard(
                        'Гравець ${id.length > 8 ? '${id.substring(0, 8)}...' : id}',
                        'Учасник',
                        false,
                        ),
                        )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return SizedBox.shrink();

    final isOrganizer = widget.match.organizerId == currentUser.uid;
    final isParticipant = widget.match.participants.contains(currentUser.uid);
    final isFull = widget.match.currentPlayers >= widget.match.maxPlayers;

    // 1. ОРГАНІЗАТОР МАТЧУ
    if (isOrganizer) {
      return Column(
        children: [
          if (widget.match.status == MatchStatus.open || widget.match.status == MatchStatus.full)
            ElevatedButton(
              onPressed: _startMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4caf50),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Почати матч', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          if (widget.match.status == MatchStatus.inProgress) ...[
            ElevatedButton(
              onPressed: _finishMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Завершити матч', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _editMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4caf50),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Редагувати матч', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _cancelMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Скасувати матч', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    // 2. УЧАСНИК МАТЧУ (НЕ ОРГАНІЗАТОР)
    if (isParticipant) {
      return ElevatedButton(
        onPressed: _isLeaving ? null : _leaveMatch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLeaving
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
                'Покинути матч',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
      );
    }

    // 2.5. ЗАВЕРШЕНИЙ МАТЧ — Оцінювання
    if (widget.match.status == MatchStatus.finished && isParticipant) {
      return ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, '/match_rating', arguments: widget.match);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4caf50),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          '⭐ Оцінити гравців',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (isFull) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Text(
          'Матч заповнений',
          style: TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 4. ГЛЯДАЧ (МОЖЕ ПРИЄДНАТИСЯ)
    return ElevatedButton(
      onPressed: _isJoining ? null : _joinMatch,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF4caf50),
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isJoining
          ? CircularProgressIndicator(color: Colors.white)
          : Text(
              'Приєднатися до матчу',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }

  // TODO: Додати методи для дій
  void _editMatch() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Редагування матчу буде додано пізніше')),
    );
  }

  void _cancelMatch() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скасування матчу буде додано пізніше')),
    );
  }

  Future<void> _startMatch() async {
    try {
      await _matchService.startMatch(widget.match.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Матч розпочато')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка старту: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _finishMatch() async {
    try {
      // Показуємо діалог для введення рахунку
      final result = await _showFinishMatchDialog();
      if (result != null) {
        final success = await _matchService.finishMatch(
          widget.match.id,
          result['result'],
          result['teamAScore'],
          result['teamBScore'],
        );
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Матч завершено! Тепер гравці можуть оцінювати один одного.')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Помилка завершення матчу'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завершення: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Додати метод для діалогу завершення матчу
  Future<Map<String, dynamic>?> _showFinishMatchDialog() async {
    int teamAScore = 0;
    int teamBScore = 0;
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1a1a2e),
          title: Text(
            'Завершити матч',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Введіть фінальний рахунок:',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Команда А',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white),
                      onChanged: (value) => teamAScore = int.tryParse(value) ?? 0,
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
                      onChanged: (value) => teamBScore = int.tryParse(value) ?? 0,
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
                Navigator.pop(context, {
                  'result': _determineMatchResult(teamAScore, teamBScore),
                  'teamAScore': teamAScore,
                  'teamBScore': teamBScore,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFf44336),
              ),
              child: Text('Завершити'),
            ),
          ],
        );
      },
    );
  }

  // Допоміжний метод для визначення результату
  MatchResult _determineMatchResult(int teamAScore, int teamBScore) {
    if (teamAScore > teamBScore) {
      return MatchResult.teamAWins;
    } else if (teamBScore > teamAScore) {
      return MatchResult.teamBWins;
    } else {
      return MatchResult.draw;
    }
  }

  void _joinMatch() async {
    setState(() => _isJoining = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final success = await _matchService.joinMatch(widget.match.id, currentUser.uid);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ви успішно приєдналися до матчу!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не вдалося приєднатися до матчу'),
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
      setState(() => _isJoining = false);
    }
  }

  void _leaveMatch() async {
    setState(() => _isLeaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final success = await _matchService.leaveMatch(widget.match.id, currentUser.uid);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ви покинули матч')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не вдалося покинути матч'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLeaving = false);
    }
  }

  Widget _buildParticipantCard(String name, String role, bool isOrganizer) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF0f3460),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOrganizer ? Color(0xFF4caf50) : Colors.white10,
          width: isOrganizer ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOrganizer ? Color(0xFF4caf50) : Color(0xFF2196f3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isOrganizer ? Icons.star : Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getLevelText(MatchLevel level) {
    switch (level) {
      case MatchLevel.beginner:
        return 'Початковий';
      case MatchLevel.intermediate:
        return 'Середній';
      case MatchLevel.advanced:
        return 'Високий';
      case MatchLevel.professional:
        return 'Професійний';
      default:
        return 'Невідомо';
    }
  }

  Color _getStatusColor(MatchStatus status) {
    switch (status) {
      case MatchStatus.open:
        return Color(0xFF4caf50);
      case MatchStatus.full:
        return Colors.orange;
      case MatchStatus.inProgress:
        return Color(0xFF2196f3);
      case MatchStatus.finished:
        return Color(0xFF9c27b0);
      case MatchStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(MatchStatus status) {
    switch (status) {
      case MatchStatus.open:
        return 'Відкритий';
      case MatchStatus.full:
        return 'Заповнений';
      case MatchStatus.inProgress:
        return 'В процесі';
      case MatchStatus.finished:
        return 'Завершений';
      case MatchStatus.cancelled:
        return 'Скасований';
      default:
        return 'Невідомо';
    }
  }
}