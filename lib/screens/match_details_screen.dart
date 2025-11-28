import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';
import '../services/match_service.dart';
import '../services/rating_service.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/i18n.dart';
import '../widgets/user_chip.dart';

class MatchDetailsScreen extends StatefulWidget {
  final Match match;
  
  const MatchDetailsScreen({Key? key, required this.match}) : super(key: key);

  @override
  _MatchDetailsScreenState createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  final MatchService _matchService = MatchService();
  final RatingService _ratingService = RatingService();
  bool _isJoining = false;

    // Кеш профілів для уникнення повторних запитів
  final Map<String, Map<String, dynamic>> _profileCache = {};

  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    if (_profileCache.containsKey(userId)) return _profileCache[userId]!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = snap.data() as Map<String, dynamic>? ?? const {};
      final profile = <String, dynamic>{
        'displayName': (data['displayName'] ?? data['authorName'] ?? I18n.t('player')).toString(),
        'avatarUrl': (data['avatarUrl'] ?? '').toString(),
      };
      _profileCache[userId] = profile;
      return profile;
    } catch (_) {
      final fallback = <String, dynamic>{'displayName': I18n.t('player'), 'avatarUrl': ''};
      _profileCache[userId] = fallback;
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Text(
          I18n.inline('⚽ Деталі матчу', '⚽ Match Details'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

            if (widget.match.isTeamMatch) ...[
              _buildTeamMatchSection(),
              SizedBox(height: 20),
            ],

            // Склади та рахунок для завершених матчів (MVP-стиль)
            if (widget.match.status == MatchStatus.finished)
              _buildFinishedTeamsAndScoreSection(),
            if (widget.match.status == MatchStatus.finished)
              SizedBox(height: 20),

            // Учасники з детальною інформацією
            _buildParticipantsSection(),
            SizedBox(height: 20),
            
            // Кнопки дій (тільки Приєднатися та Поділитися)
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D3748),
            Color(0xFF1A202C),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
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
          if (widget.match.description.isNotEmpty) ...[
            Text(
              widget.match.description,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
          ],
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.match.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusText(widget.match.status),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D3748),
            Color(0xFF1A202C),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.inline('📋 Інформація про матч', '📋 Match Information'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          
          // Статистика в рядках
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '🗓️',
                  '${widget.match.date.day}.${widget.match.date.month}.${widget.match.date.year}',
                  I18n.inline('Дата', 'Date'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '⏰',
                  widget.match.time,
                  I18n.inline('Час', 'Time'),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '👥',
                  '${widget.match.participants.length}/${widget.match.maxPlayers}',
                  I18n.inline('Гравці', 'Players'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '💰',
                  '${widget.match.cost} грн',
                  I18n.inline('Вартість', 'Cost'),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '⭐',
                  _getLevelText(widget.match.level),
                  I18n.inline('Рівень', 'Level'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                   '🏙️',
                  widget.match.city,
                  I18n.inline('Місто', 'City'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Локація
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.white70, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.match.location,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMatchSection() {
    final teamAName = (widget.match.teamA?.name.isNotEmpty ?? false)
        ? widget.match.teamA!.name
        : I18n.inline('Команда організатора', 'Host team');
    final teamBName = (widget.match.teamB?.name.isNotEmpty ?? false)
        ? widget.match.teamB!.name
        : (widget.match.teamBId != null
            ? I18n.inline('Команда суперника', 'Opponent team')
            : I18n.inline('Очікує суперника', 'Awaiting opponent'));

    final rosterA =
        widget.match.teamRosters['teamA'] ?? widget.match.teamA?.playerIds ?? const <String>[];
    final rosterB =
        widget.match.teamRosters['teamB'] ?? widget.match.teamB?.playerIds ?? const <String>[];

    final hasScore =
        widget.match.teamAScore != null && widget.match.teamBScore != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF283046),
            Color(0xFF1F2435),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_soccer, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                I18n.inline('Командний матч', 'Team match'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildTeamStatusChip(),
            ],
          ),
          if (hasScore) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildScorePill(teamAName, widget.match.teamAScore!, Colors.greenAccent),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildScorePill(teamBName, widget.match.teamBScore!, Colors.lightBlueAccent),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildTeamRow(
            label: teamAName,
            status: widget.match.teamAStatus ?? 'confirmed',
            playerIds: rosterA,
            averageRating: widget.match.teamA?.averageRating,
            accent: const Color(0xFF4caf50),
          ),
          const SizedBox(height: 16),
          _buildTeamRow(
            label: teamBName,
            status: widget.match.teamBStatus ??
                (widget.match.teamBId == null ? 'pending' : 'confirmed'),
            playerIds: rosterB,
            averageRating: widget.match.teamB?.averageRating,
            accent: const Color(0xFF42a5f5),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow({
    required String label,
    required String status,
    required List<String> playerIds,
    required Color accent,
    double? averageRating,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (averageRating != null && averageRating > 0) ...[
              Icon(Icons.star, color: accent, size: 16),
              const SizedBox(width: 4),
              Text(
                averageRating.toStringAsFixed(1),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
            ],
            _buildTeamStatusPill(status),
          ],
        ),
        const SizedBox(height: 10),
        if (playerIds.isEmpty)
          Text(
            I18n.inline('Склад ще не визначено', 'Roster not selected yet'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: playerIds.take(12).map((id) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: UserChip(
                    userId: id,
                    size: 32,
                    showName: false,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamStatusPill(String status) {
    final color = _teamStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _teamStatusText(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildScorePill(String name, int score, Color color) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        I18n.inline('Склади', 'Rosters'),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _teamStatusText(String? status) {
    switch (status) {
      case 'confirmed':
        return I18n.inline('Підтверджено', 'Confirmed');
      case 'declined':
        return I18n.inline('Відхилено', 'Declined');
      default:
        return I18n.inline('Очікує', 'Pending');
    }
  }

  Color _teamStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }

  Widget _buildStatCard(String icon, String value, String label) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            icon,
            style: TextStyle(fontSize: 20),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D3748),
            Color(0xFF1A202C),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                I18n.inline('👥 Учасники (${widget.match.participants.length})', '👥 Participants (${widget.match.participants.length})'),
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
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  I18n.inline('Поки що немає учасників', 'No participants yet'),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            Column(
              children: widget.match.participants.map((participantId) {
                return _buildParticipantCard(participantId);
              }).toList(),
            ),
        ],
      ),
    );
  }



  Widget _buildParticipantCard(String participantId) {
  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    future: FirebaseFirestore.instance
        .collection('users')
        .doc(participantId)
        .get(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || !snapshot.data!.exists) {
        return _buildParticipantCardPlaceholder(participantId);
      }

      final userData = snapshot.data!.data()!;
      final isOrganizer = participantId == widget.match.organizerId;
      final displayName =
          (userData['displayName'] ?? userData['authorName'] ?? I18n.t('player'))
              .toString()
              .trim();

      return GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/player-profile',
            arguments: {'playerId': participantId, 'playerName': displayName},
          );
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOrganizer ? Color(0xFF4caf50) : Colors.white.withOpacity(0.1),
              width: isOrganizer ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Аватарка
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/player-profile',
                    arguments: {'playerId': participantId, 'playerName': displayName},
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isOrganizer ? Color(0xFF4caf50) : Color(0xFF2196f3),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: userData['avatarUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.network(
                            userData['avatarUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                isOrganizer ? Icons.star : Icons.person,
                                color: Colors.white,
                                size: 24,
                              );
                            },
                          ),
                        )
                      : Icon(
                          isOrganizer ? Icons.star : Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
              SizedBox(width: 16),
              
              // Інформація про гравця
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName.isNotEmpty ? displayName : I18n.t('player'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isOrganizer) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF4caf50),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              I18n.t('organizer'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${userData['position'] ?? I18n.inline('Позиція не вказана', 'Position not specified')} • ${userData['city'] ?? I18n.inline('Місто не вказано', 'City not specified')}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Рейтинг
              Column(
                children: [
                  Text(
                    (userData['rating'] ?? 3.0).toStringAsFixed(2),
                    style: TextStyle(
                      color: Color(0xFF4caf50),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    I18n.inline('РЕЙТИНГ', 'RATING'),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildParticipantCardPlaceholder(String participantId) {
    final isOrganizer = participantId == widget.match.organizerId;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOrganizer ? Color(0xFF4caf50) : Colors.white.withOpacity(0.1),
          width: isOrganizer ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isOrganizer ? Color(0xFF4caf50) : Color(0xFF2196f3),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              isOrganizer ? Icons.star : Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${I18n.t('player')} ${participantId.length > 8 ? '${participantId.substring(0, 8)}...' : participantId}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isOrganizer) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF4caf50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          I18n.t('organizer'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${I18n.inline('Позиція не вказана', 'Position not specified')} • ${I18n.inline('Місто не вказано', 'City not specified')}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '3.0',
                style: TextStyle(
                  color: Color(0xFF4caf50),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'РЕЙТИНГ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildActionButtons() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final isParticipant = widget.match.participants.contains(currentUser.uid);
    final isFull = widget.match.currentPlayers >= widget.match.maxPlayers;
    final isOrganizer = widget.match.organizerId == currentUser.uid;

    if (widget.match.isTeamMatch && !isParticipant && !isOrganizer) {
      return _buildTeamOnlyMessage();
    }

    if (isOrganizer && widget.match.status != MatchStatus.finished) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildManageMatchButton(),
          const SizedBox(height: 12),
          _buildShareButton(expand: false),
        ],
      );
    }

    if (isFull && !isParticipant) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                I18n.inline('Матч заповнений. Нових учасників не приймають.',
                    'Match is full. No new participants accepted.'),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isParticipant && widget.match.status == MatchStatus.finished) {
      final userId = currentUser.uid;
      return FutureBuilder<double>(
        future: _getMyMatchAverageRating(widget.match.id, userId),
        builder: (context, snap) {
          final value = (snap.data ?? 0.0);
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF4CAF50), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value > 0
                        ? I18n.inline(
                            'Ваша оцінка за матч: ${value.toStringAsFixed(2)}',
                            'Your match rating: ${value.toStringAsFixed(2)}')
                        : I18n.inline('Ще немає оцінок', 'No ratings yet'),
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (isParticipant) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                I18n.inline('Ви вже приєднані до цього матчу!',
                    'You are already joined to this match!'),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4caf50).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isJoining ? null : _joinMatch,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: _isJoining
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              I18n.t('join'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildShareButton(),
      ],
    );
  }

  Widget _buildShareButton({bool expand = true}) {
    final button = Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _shareMatch,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  I18n.t('share'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (expand) {
      return Expanded(child: button);
    }
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildTeamOnlyMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              I18n.inline(
                  'Це командний матч. Попросіть капітана команди додати вас до складу або зачекайте запрошення.',
                  'This is a team-only match. Ask a team captain to add you to the roster or wait for an invite.'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageMatchButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/match_management',
            arguments: widget.match,
          );
        },
        icon: const Icon(Icons.tune),
        label: Text(I18n.inline('Керувати матчем', 'Manage match')),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4caf50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }


  void _joinMatch() async {
    setState(() => _isJoining = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final success = await _matchService.applyForMatch(widget.match.id, currentUser.uid);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.t('applied_wait')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.t('already_applied')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка: $e', 'Error: $e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  void _shareMatch() {
    final url = 'https://flap.app/match/${widget.match.id}';
    Share.share(I18n.inline('Приєднуйся до матчу "${widget.match.title}": ', 'Join the match "${widget.match.title}": ') + url);
  }

  String _getLevelText(MatchLevel level) {
    switch (level) {
      case MatchLevel.beginner:
        return I18n.t('beginner');
      case MatchLevel.intermediate:
        return I18n.inline('Середній', 'Intermediate');
      case MatchLevel.advanced:
        return I18n.inline('Високий', 'Advanced');
      case MatchLevel.professional:
        return I18n.t('professional');
      default:
        return I18n.t('unknown');
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
        return Colors.grey;
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
  Future<double> _getMyMatchAverageRating(String matchId, String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .collection('playerRatings')
          .where('playerId', isEqualTo: userId)
          .get();
      if (snap.docs.isEmpty) return 0.0;
      double sum = 0.0;
      for (final d in snap.docs) {
        final m = d.data();
        final r = (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0.0;
        sum += r;
      }
      return sum / snap.docs.length;
    } catch (_) {
      return 0.0;
    }
  }

  Widget _buildFinishedTeamsAndScoreSection() {
    final aName = (widget.match.teamA?.name?.isNotEmpty == true)
        ? widget.match.teamA!.name
        : 'Команда A';
    final bName = (widget.match.teamB?.name?.isNotEmpty == true)
        ? widget.match.teamB!.name
        : 'Команда B';
    // Якщо команди відсутні або порожні, показуємо всіх учасників, розбитих навпіл,
    // щоб уникнути розсинхрону з учасниками (MVP-фолбек лише для відображення)
    List<String> aPlayers = List<String>.from(widget.match.teamA?.playerIds ?? const <String>[]);
    List<String> bPlayers = List<String>.from(widget.match.teamB?.playerIds ?? const <String>[]);
    if (aPlayers.isEmpty && bPlayers.isEmpty) {
      final all = List<String>.from(widget.match.participants);
      all.sort();
      final mid = (all.length / 2).floor();
      aPlayers = all.sublist(0, mid);
      bPlayers = all.sublist(mid);
    }
    final aScore = widget.match.teamAScore ?? 0;
    final bScore = widget.match.teamBScore ?? 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Рахунок і заголовок
          Row(
            children: [
              Expanded(
                child: Text(
                  aName,
                  style: TextStyle(
                    color: Color(0xFF64B5F6),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  '$aScore : $bScore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    bName,
                    style: TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Дві колонки зі складами
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _teamList(aPlayers, color: Color(0xFF64B5F6))),
              SizedBox(width: 12),
              Expanded(child: _teamList(bPlayers, color: Color(0xFFE57373))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamList(List<String> ids, {required Color color}) {
  if (ids.isEmpty) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        'Склад відсутній',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: ids.map((id) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserProfile(id),
        builder: (context, snap) {
          final profile = snap.data ?? const {'displayName': 'Гравець', 'avatarUrl': ''};
          final displayName = (profile['displayName'] as String).trim();
          final avatarUrl = (profile['avatarUrl'] as String).trim();
          final initials = (displayName.isNotEmpty
                  ? displayName.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join()
                  : (id.isNotEmpty ? id.substring(0, id.length >= 2 ? 2 : 1) : '?'))
              .toUpperCase();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/player-profile',
                  arguments: {'playerId': id, 'playerName': displayName},
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF4caf50),
                    backgroundImage: (avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                    child: (avatarUrl.isEmpty)
                        ? Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName
                          : 'Гравець ${id.substring(0, id.length >= 6 ? 6 : id.length)}…',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }).toList(),
  );
}
}
