import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/rating_service.dart';
import '../models/match.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final RatingService _ratingService = RatingService();
  
  // Оцінки для кожного гравця
  Map<String, Map<String, double>> _playerRatings = {};
  
  // Критерії оцінювання
  final List<String> _criteria = [
    'technical',    // Техніка
    'physical',     // Фізика
    'tactical',     // Тактика
    'teamwork',     // Командна гра
  ];
  
  final List<String> _criteriaLabels = [
    '⚽ Техніка',
    '🏃 Фізика',
    '🧠 Тактика',
    '🤝 Командна гра',
  ];
  
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
    final List<String> allPlayers = [
  ...List<String>.from(widget.match.teamA?.playerIds ?? const <String>[]),
  ...List<String>.from(widget.match.teamB?.playerIds ?? const <String>[]),
];

// Якщо команди не існують, використовуємо всіх учасників матчу

final participantsSet = widget.match.participants.toSet();
final currentUserId = FirebaseAuth.instance.currentUser?.uid;

final List<String> teamAIds = List<String>.from(widget.match.teamA?.playerIds ?? const <String>[]);
final List<String> teamBIds = List<String>.from(widget.match.teamB?.playerIds ?? const <String>[]);

final bool teamsExist = teamAIds.isNotEmpty || teamBIds.isNotEmpty;

List<String> basePlayers;
if (teamsExist && currentUserId != null && teamAIds.contains(currentUserId)) {
  // Якщо я в команді А → оцінюю СВОЮ команду А (без себе)
  basePlayers = teamAIds.where((id) => id != currentUserId).toList();
} else if (teamsExist && currentUserId != null && teamBIds.contains(currentUserId)) {
  // Якщо я в команді Б → оцінюю СВОЮ команду Б (без себе)
  basePlayers = teamBIds.where((id) => id != currentUserId).toList();
} else {
  // Якщо команди не задані → оцінюю всіх учасників (без себе)
  basePlayers = widget.match.participants.where((id) => id != currentUserId).toList();
}

final playersToRate = basePlayers.where((id) => participantsSet.contains(id)).toSet().toList();
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
    print('RATING DEBUG allPlayers=${allPlayers.length}');
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
                const Text(
                  'Оцінка гравців',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Після матчу',
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
              _isSubmitting ? 'Зберігаємо...' : 'Зберегти',
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
                  '${widget.match.teamA?.name ?? 'Команда А'} vs ${widget.match.teamB?.name ?? 'Команда Б'}',
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
                    'Оцініть всіх гравців для справедливого рейтингу',
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

          // Список гравців для оцінювання
if (_playerRatings.isEmpty)
  Padding(
    padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Text(
        'Немає гравців для оцінювання.\nМожливо, ви вже оцінили всіх учасників цього матчу.',
        style: TextStyle(color: Colors.white70),
      ),
    ),
  )
else
  Expanded(
    child: ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _playerRatings.length,
      itemBuilder: (context, index) {
        final playerId = _playerRatings.keys.elementAt(index);
        final ratings = _playerRatings[playerId]!;
        return _buildPlayerRatingCard(playerId, ratings);
      },
    ),
  ),
        ],
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
              displayName.isNotEmpty ? displayName : 'Гравець ${playerId.substring(0, 8)}...',
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
            
            // Критерії оцінювання
            ...List.generate(_criteria.length, (index) {
              final criterion = _criteria[index];
              final label = _criteriaLabels[index];
              final value = ratings[criterion] ?? 2.5;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          value.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                      valueIndicatorTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      min: 0.0,
                      max: 5.0,
                      divisions: 50, // крок 0.1
                      label: value.toStringAsFixed(2),
                      onChanged: (newValue) {
                        print('🎚️ SLIDER CHANGED: playerId=$playerId, criterion=$criterion, value=$newValue');
                        setState(() {
                          _playerRatings[playerId]![criterion] = newValue;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
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
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final idsToRate = _playerRatings.keys.where((id) => id != currentUserId).toList();
      final int totalCount = idsToRate.length;
            if (totalCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Немає гравців для оцінювання'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

            for (final playerId in idsToRate) {
        final ratings = _playerRatings[playerId]!;
        print('💾 SAVING matchId=${widget.match.id}, playerId=$playerId with ratings:');
        print('   technical: ${ratings['technical']}');
        print('   physical: ${ratings['physical']}');
        print('   tactical: ${ratings['tactical']}');
        print('   teamwork: ${ratings['teamwork']}');
        final success = await _ratingService.ratePlayerAfterMatch(
          matchId: widget.match.id,
          playerId: playerId,
          ratedBy: FirebaseAuth.instance.currentUser!.uid,
          criteria: ratings,
        );
        if (success) {
  print('RATING DEBUG saved playerId=$playerId');
} else {
  print('RATING DEBUG FAILED playerId=$playerId');
}
        
        if (success) {
          successCount++;
        }
      }
      
      if (successCount == totalCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Всі оцінки збережено! Рейтинги оновлено.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Повертаємося назад
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Збережено $successCount з $totalCount оцінок'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
    } catch (e) {
      print('Error submitting ratings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Помилка збереження: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  // Форматування дати
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} дн. тому';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} год. тому';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} хв. тому';
    } else {
      return 'Щойно';
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
