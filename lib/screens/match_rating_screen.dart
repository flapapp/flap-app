import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/rating_service.dart';
import '../models/match.dart';

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
  
  @override
  void initState() {
    super.initState();
    _initializeRatings();
  }
  
  void _initializeRatings() {
    // Ініціалізуємо оцінки для всіх гравців
    final allPlayers = [
      ...widget.match.teamA?.playerIds ?? [],
      ...widget.match.teamB?.playerIds ?? [],
    ];
    
    for (final playerId in allPlayers) {
      _playerRatings[playerId] = {};
      for (final criterion in _criteria) {
        _playerRatings[playerId]![criterion] = 2.5; // Середня оцінка за замовчуванням
      }
    }
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
            onPressed: _isSubmitting ? null : _submitAllRatings,
            child: Text(
              _isSubmitting ? 'Зберігаємо...' : 'Зберегти',
              style: TextStyle(
                color: _isSubmitting ? Colors.white54 : Colors.white,
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      playerId.substring(0, 2).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Гравець ${playerId.substring(0, 8)}...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Оберіть оцінку за кожним критерієм',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
                          value.toStringAsFixed(1),
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
                      label: value.toStringAsFixed(1),
                      onChanged: (newValue) {
                        setState(() {
                          ratings[criterion] = newValue;
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
      int totalCount = _playerRatings.length;
      
      // Оцінюємо кожного гравця
      for (final entry in _playerRatings.entries) {
        final playerId = entry.key;
        final ratings = entry.value;
        
        final success = await _ratingService.ratePlayerAfterMatch(
          matchId: widget.match.id,
          playerId: playerId,
          ratedBy: 'current_user_id', // TODO: Отримати ID поточного користувача
          criteria: ratings,
        );
        
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
