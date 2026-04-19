import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/ratings_repository.dart';
import '../../../../router/app_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../matches/data/models/match.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flap_app/core/auth/app_auth.dart';

enum RatingMode { simple, advanced }

@RoutePage()
class MatchRatingScreen extends StatefulWidget {
  final Match match;
  
  const MatchRatingScreen({
    Key? key,
    required this.match,
  }) : super(key: key);

  @override
  _MatchRatingScreenState createState() => _MatchRatingScreenState();
}

class _MatchRatingScreenState extends State<MatchRatingScreen> {
  RatingsRepository get _ratingRepo => sl<RatingsRepository>();
  
  // Оцінки для кожного гравця
  Map<String, Map<String, double>> _playerRatings = {};
  
  // Критерії оцінювання
  final List<String> _criteria = [
    'technical',    // Техніка
    'physical',     // Фізика
    'tactical',     // Тактика
    'teamwork',     // Командна гра
  ];
  
  List<String> get _criteriaLabels => [
    tr('il_76391b2aee'),
    tr('il_83191d2bd8'),
    tr('il_385d0084c8'),
    tr('il_55d3394671'),
  ];

  RatingMode _mode = RatingMode.advanced;
  final Map<String, double> _simpleRating = {}; // playerId -> 0..5
  
  
  bool _isSubmitting = false;
  // Кеш профілів користувачів (displayName, photoUrl)
final Map<String, Map<String, String>> _userCache = {};

Future<Map<String, String>> _getUserProfile(String userId) async {
  if (_userCache.containsKey(userId)) {
    return _userCache[userId]!;
  }
  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (!snap.exists) {
      _userCache[userId] = const {};
      return const {};
    }
    final data = (snap.data() as Map<String, dynamic>? ?? const {});
final String displayName = (data['displayName'] as String?)?.trim() ?? '';
final String avatarUrl = ((data['avatarUrl'] ?? data['photoUrl']) as String?)?.trim() ?? '';
final profile = <String, String>{
  'displayName': displayName,
  'avatarUrl': avatarUrl,
};
_userCache[userId] = profile;
return profile;
  } catch (_) {
    _userCache[userId] = const {};
    return const {};
  }
}
  
    @override
void initState() {
  super.initState();
  
  // Завантажуємо гравців незалежно від статусу
  // Перевірка статусу буде при збереженні оцінок
  _initializeRatings();
}
  
    Future<void> _initializeRatings() async {
    print('🔴 RATING DEBUG: _initializeRatings() CALLED');
    print('🔴 RATING DEBUG: match.id = ${widget.match.id}');
    print('🔴 RATING DEBUG: match.status = ${widget.match.status}');
    print('🔴 RATING DEBUG: match.title = ${widget.match.title}');
    
    // Ініціалізуємо оцінки для всіх гравців
    // Використовуємо participants як fallback, якщо teamA/teamB не існують
    _playerRatings.clear();
    final currentUserId = AppAuth.currentUserId;
final participantsSet = widget.match.participants.toSet();
final allTeams = widget.match.allTeams;

List<String> basePlayers = [];

if (currentUserId != null && allTeams.isNotEmpty) {
  MatchTeamEntity? myTeam;
  try {
    myTeam = allTeams.firstWhere((team) => team.playerIds.contains(currentUserId));
  } catch (_) {
    myTeam = null;
  }

  if (myTeam != null) {
    basePlayers = myTeam.playerIds.where((id) => id != currentUserId).toList();
  }
}

if (basePlayers.isEmpty) {
  basePlayers = widget.match.participants
      .where((id) => id != currentUserId)
      .toList();
}

final playersToRate = basePlayers
    .where((id) => participantsSet.contains(id))
    .toSet()
    .toList();
final sanitizedPlayers = playersToRate.where((id) =>
  id != 'current_user_i' && id != 'current_user' && !id.startsWith('current_')
).toList();

// виключаємо тих, кого ви вже оцінювали
final existingSnap = await FirebaseFirestore.instance
    .collection('matches')
    .doc(widget.match.id)
    .collection('playerRatings')
    .where('ratedBy', isEqualTo: currentUserId)
    .get();
final alreadyRatedIds = existingSnap.docs
    .map((d) => (d.data()['playerId'] as String?) ?? '')
    .toSet();
    print('RATING DEBUG matchId=${widget.match.id}');
    print('RATING DEBUG participants=${widget.match.participants.length}');
    print('RATING DEBUG basePlayers=${basePlayers.length}');
    print('RATING DEBUG playersToRate=${playersToRate.length}');
    print('RATING DEBUG sanitizedPlayers=${sanitizedPlayers.length}');
    print('RATING DEBUG alreadyRatedIds=${alreadyRatedIds.length}');

        for (final playerId in sanitizedPlayers) {
      print('RATING DEBUG checking playerId=$playerId');
      if (currentUserId != null && playerId == currentUserId) {
        print('RATING DEBUG SKIP: playerId == currentUserId');
        continue;
      }
      if (alreadyRatedIds.contains(playerId)) {
        print('RATING DEBUG SKIP: already rated');
        continue;
      }
      _simpleRating[playerId] = 2.5;
      print('RATING DEBUG ADDING playerId=$playerId to _playerRatings');
      _playerRatings[playerId] = {};
      for (final criterion in _criteria) {
        _playerRatings[playerId]![criterion] = 2.5; // Середня оцінка за замовчуванням
      }
    }
    print('RATING DEBUG FINAL _playerRatings.length=${_playerRatings.length}');
    print('RATING DEBUG FINAL _playerRatings.keys=${_playerRatings.keys.toList()}');
    setState(() {});
   
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23).withOpacity(0.95),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('il_315b687966'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  tr('il_a160524e96'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
                    TextButton(
            onPressed: (_isSubmitting || _playerRatings.isEmpty) ? null : _submitAllRatings,
            child: Text(
              _isSubmitting ? tr('il_dc85af8f2b') : tr('save'),
              style: TextStyle(
                color: (_isSubmitting || _playerRatings.isEmpty) ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Інформація про матч
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.2),
                  const Color(0xFF66BB6A).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏆 ${widget.match.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.match.teamA?.name ?? tr('il_e18d322f14')} vs ${widget.match.teamB?.name ?? tr('il_aceaf5d9ac')}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '📅 ${_formatDate(widget.match.date)} • 📍 ${widget.match.city}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tr('il_b09b392002'),
                    style: TextStyle(
                      color: const Color(0xFF4CAF50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
  padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Row(
      children: [
        Text(tr('mode_colon'), style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 10),
        ToggleButtons(
          isSelected: [_mode == RatingMode.simple, _mode == RatingMode.advanced],
          onPressed: (i) => setState(() => _mode = i == 0 ? RatingMode.simple : RatingMode.advanced),
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: const Color(0xFF4CAF50).withOpacity(0.3),
          color: Colors.white70,
          children: [
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text(tr('simple'))),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text(tr('advanced_mode'))),
          ],
        ),
      ],
    ),
  ),
),

          Expanded(
            child: _playerRatings.isEmpty
                ? _buildEmptyRatingsState()
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _playerRatings.length,
                    itemBuilder: (context, index) {
                      final playerId = _playerRatings.keys.elementAt(index);
                      final ratings = _playerRatings[playerId]!;
                      return _buildPlayerRatingCard(playerId, ratings);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || _playerRatings.isEmpty)
                      ? null
                      : _submitAllRatings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSubmitting
                        ? tr('il_dc85af8f2b')
                        : tr('il_fa204511ae'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyRatingsState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          tr('il_432d30edd9'),
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
    );
  }
  
  // Картка оцінювання гравця
  Widget _buildPlayerRatingCard(String playerId, Map<String, double> ratings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок гравця
            Row(
  children: [
    FutureBuilder<Map<String, String>>(
      future: _getUserProfile(playerId),
      builder: (context, snap) {
        final profile = snap.data ?? const {};
        final displayName = (profile['displayName'] ?? '').trim();
        final avatarUrl = (profile['avatarUrl'] ?? '').trim();
        final initials = (displayName.isNotEmpty
                ? displayName.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join()
                : playerId.substring(0, 2))
            .toUpperCase();

        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
  child: (avatarUrl.isNotEmpty)
      ? Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _AvatarFallback(initials: initials),
        )
      : _AvatarFallback(initials: initials),
)
            ),
            const SizedBox(width: 12),
            // Імʼя гравця
            Text(
              displayName.isNotEmpty ? displayName : tr('il_9e4608e723'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    ),
    const Spacer(),
  ],
),
            
            const SizedBox(height: 16),
            
            if (_mode == RatingMode.simple) ...[
  Text(tr('il_ee62b83057'), style: const TextStyle(color: Colors.white70)),
  const SizedBox(height: 8),
  SliderTheme(
    data: SliderTheme.of(context).copyWith(
      activeTrackColor: const Color(0xFF4CAF50),
      inactiveTrackColor: Colors.white24,
      thumbColor: const Color(0xFF4CAF50),
      overlayColor: const Color(0xFF4CAF50).withOpacity(0.2),
      valueIndicatorColor: const Color(0xFF4CAF50),
      valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
    ),
    child: Slider(
      value: _simpleRating[playerId] ?? 2.5,
      min: 0.0,
      max: 5.0,
      divisions: 50,
      label: (_simpleRating[playerId] ?? 2.5).toStringAsFixed(2),
      onChanged: (v) => setState(() => _simpleRating[playerId] = v),
    ),
  ),
  const SizedBox(height: 8),
] else ...[
  ...List.generate(_criteria.length, (index) {
    final criterion = _criteria[index];
    final label = _criteriaLabels[index];
    final value = ratings[criterion] ?? 2.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
              child: Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF4CAF50),
            inactiveTrackColor: Colors.white24,
            thumbColor: const Color(0xFF4CAF50),
            overlayColor: const Color(0xFF4CAF50).withOpacity(0.2),
            valueIndicatorColor: const Color(0xFF4CAF50),
            valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 5.0,
            divisions: 50,
            label: value.toStringAsFixed(2),
            onChanged: (nv) => setState(() => _playerRatings[playerId]![criterion] = nv),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }),
]
          ],
        ),
      ),
    );
  }
  
  // Збереження всіх оцінок
  Future<void> _submitAllRatings() async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      int successCount = 0;
      final List<String> failureMessages = [];
      final currentUserId = AppAuth.currentUserId;
      final idsToRate = _playerRatings.keys.where((id) => id != currentUserId).toList();
      final int totalCount = idsToRate.length;
      if (totalCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_d63bd4a9c8')),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      for (final playerId in idsToRate) {
        final ratings = _playerRatings[playerId]!;
        final double simple = _simpleRating[playerId] ?? 2.5;
        final Map<String, double> effectiveCriteria =
            (_mode == RatingMode.advanced)
                ? ratings
                : {'technical': simple, 'physical': simple, 'tactical': simple, 'teamwork': simple};
        try {
          await _ratingRepo.ratePlayerAfterMatch(
            matchId: widget.match.id,
            playerId: playerId,
            ratedBy: AppAuth.currentUserId!,
            criteria: effectiveCriteria,
          );
          successCount++;
          _playerRatings.remove(playerId);
          _simpleRating.remove(playerId);
        } catch (e) {
          final profile = _userCache[playerId] ?? const {};
          final playerName = (profile['displayName'] ?? '').toString().trim();
          failureMessages.add(
            '${playerName.isEmpty ? playerId : playerName}: ${_humanizeError(e)}',
          );
        }
      }
      setState(() {});

      if (successCount == totalCount) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_4641207a5f')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        final String headline = successCount == 0
            ? tr('il_b43497d860')
            : tr('il_7e27449e19');
        final String details = failureMessages.isNotEmpty ? '\n${failureMessages.first}' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$headline$details'),
            backgroundColor: successCount == 0 ? Colors.red : Colors.orange,
          ),
        );
      }
      
    } catch (e) {
      print('Error submitting ratings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_051ce3d417')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  String _humanizeError(Object error) {
    final raw = error.toString();
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
  
  // Форматування дати
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return tr('il_adf8ee5f65');
    } else if (difference.inHours > 0) {
      return tr('il_7634d1849f');
    } else if (difference.inMinutes > 0) {
      return tr('il_e0b53645d6');
    } else {
      return tr('il_66f53417d3');
    }
  }
}
class _AvatarFallback extends StatelessWidget {
  final String initials;
  const _AvatarFallback({Key? key, required this.initials}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF616161),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
