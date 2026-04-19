import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/challenge.dart';
import '../../../../utils/i18n.dart';

@RoutePage()
class ChallengeCompletionScreen extends StatefulWidget {
  final String challengeId;
  
  const ChallengeCompletionScreen({
    Key? key,
    required this.challengeId,
  }) : super(key: key);

  @override
  _ChallengeCompletionScreenState createState() => _ChallengeCompletionScreenState();
}

class _ChallengeCompletionScreenState extends State<ChallengeCompletionScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _winnerController;
  late AnimationController _rewardController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _winnerScaleAnimation;
  late Animation<double> _rewardAnimation;
  
  Challenge? _challenge;
  List<Map<String, dynamic>> _winners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadChallengeData();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _winnerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _rewardController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _winnerScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _winnerController,
      curve: Curves.elasticOut,
    ));

    _rewardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rewardController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _loadChallengeData() async {
    try {
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .get();
      
      if (challengeDoc.exists) {
        setState(() {
          _challenge = Challenge.fromFirestore(challengeDoc);
          _isLoading = false;
        });
        
        // Завантажуємо переможців
        await _loadWinners();
        
        // Запускаємо анімації
        _startAnimations();
      }
    } catch (e) {
      print('Error loading challenge: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWinners() async {
    try {
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .collection('submissions')
          .orderBy('averageRating', descending: true)
          .limit(3)
          .get();

      final winners = <Map<String, dynamic>>[];
      
      final prizeOverrides = _challenge?.winnerPrizes ?? const <String, int>{};

      for (int i = 0; i < submissionsSnapshot.docs.length; i++) {
        final doc = submissionsSnapshot.docs[i];
        final data = doc.data();
        
        // Отримуємо дані користувача
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['userId'])
            .get();
        
        final userData = userDoc.data() ?? {};
        final winnerId = data['userId'] as String? ?? '';
        final override = prizeOverrides[winnerId];
        final prize = (override ?? _calculatePrize(i + 1)).toDouble();
        
        winners.add({
          'position': i + 1,
          'userId': winnerId,
          'userName': userData['displayName'] ?? userData['name'] ?? I18n.inline('Невідомий', 'Unknown'),
          'userAvatar': userData['avatarUrl'] ?? userData['photoUrl'] ?? '',
          'rating': data['averageRating'] ?? 0.0,
          'prize': prize,
        });
      }
      
      setState(() {
        _winners = winners;
      });
    } catch (e) {
      print('Error loading winners: $e');
    }
  }

  double _calculatePrize(int position) {
    if (_challenge == null) return 0.0;
    
    final totalPrize = _challenge!.prizePool;
    
    switch (position) {
      case 1:
        return totalPrize * 0.5; // 50% за 1 місце
      case 2:
        return totalPrize * 0.3; // 30% за 2 місце
      case 3:
        return totalPrize * 0.2; // 20% за 3 місце
      default:
        return 0.0;
    }
  }

  void _startAnimations() {
    _mainController.forward();
    
    Future.delayed(const Duration(milliseconds: 800), () {
      _winnerController.forward();
    });
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      _rewardController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _winnerController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_challenge == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        body: Center(
          child: Text(
            I18n.t('challenge_not_found'),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    // Заголовок
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            I18n.t('challenge_completed'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _challenge!.title,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    // Переможці
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _winnerController,
                        builder: (context, child) {
                          return ScaleTransition(
                            scale: _winnerScaleAnimation,
                            child: _buildWinnersList(),
                          );
                        },
                      ),
                    ),
                    
                    // Кнопка закриття
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: AnimatedBuilder(
                        animation: _rewardController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _rewardAnimation,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Text(
                                I18n.t('close'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWinnersList() {
    if (_winners.isEmpty) {
      return Center(
        child: Text(
          I18n.t('no_winners'),
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _winners.length,
      itemBuilder: (context, index) {
        final winner = _winners[index];
        return _buildWinnerCard(winner, index);
      },
    );
  }

  Widget _buildWinnerCard(Map<String, dynamic> winner, int index) {
    final position = winner['position'] as int;
    final userName = winner['userName'] as String;
    final userAvatar = winner['userAvatar'] as String;
    final rating = winner['rating'] as double;
    final prize = winner['prize'] as double;

    Color positionColor;
    IconData positionIcon;
    
    switch (position) {
      case 1:
        positionColor = const Color(0xFFFFD700); // Золото
        positionIcon = Icons.emoji_events;
        break;
      case 2:
        positionColor = const Color(0xFFC0C0C0); // Срібло
        positionIcon = Icons.emoji_events;
        break;
      case 3:
        positionColor = const Color(0xFFCD7F32); // Бронза
        positionIcon = Icons.emoji_events;
        break;
      default:
        positionColor = Colors.white70;
        positionIcon = Icons.person;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            positionColor.withOpacity(0.1),
            positionColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: positionColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Позиція
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: positionColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              positionIcon,
              color: Colors.white,
              size: 30,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Аватар
          CircleAvatar(
            radius: 25,
            backgroundImage: userAvatar.isNotEmpty
                ? NetworkImage(userAvatar)
                : null,
            child: userAvatar.isEmpty
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // Інформація
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${I18n.t('rating')}: ${rating.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Нагорода
          Column(
            children: [
              Icon(
                Icons.monetization_on,
                color: positionColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                '${prize.toStringAsFixed(0)}₴',
                style: TextStyle(
                  color: positionColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


