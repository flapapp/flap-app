import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/challenge.dart';

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
  final SupabaseClient _sb = Supabase.instance.client;
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
      final row = await _sb
          .from('challenges')
          .select()
          .eq('id', widget.challengeId)
          .maybeSingle();

      if (row != null) {
        setState(() {
          _challenge = Challenge.fromFirestore(
            _MapDoc(widget.challengeId, <String, dynamic>{
              'title': row['title'],
              'description': row['description'],
              'type': '',
              'status': row['status'],
              'entryFee': row['entry_fee'] ?? 0,
              'maxParticipants': row['max_participants'] ?? 0,
              'participants': const <String>[],
              'prizePool': 0,
              'startDate': row['starts_at'],
              'endDate': row['ends_at'],
              'createdAt': row['created_at'],
              'createdBy': row['creator_id'],
              'city': row['city'],
              'isTeamChallenge': false,
              'creatorVideoUrl': '',
              'creatorThumbnailUrl': row['image_url'],
              'submissionDeadline': row['submission_deadline'],
              'votingDeadline': row['voting_deadline'],
            }),
          );
          _isLoading = false;
        });
        
        // Load winners
        await _loadWinners();
        
        // Start animations
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
      final submissionsRows = await _sb
          .from('challenge_submissions')
          .select('id, user_id')
          .eq('challenge_id', widget.challengeId)
          .limit(50);

      final prizesRows = await _sb
          .from('challenge_prize_places')
          .select('place, prize_amount, winner_user_id')
          .eq('challenge_id', widget.challengeId);

      final winners = <Map<String, dynamic>>[];

      final scored = <Map<String, dynamic>>[];
      for (final raw in submissionsRows as List<dynamic>) {
        final sub = raw as Map<String, dynamic>;
        final sid = (sub['id'] ?? '').toString();
        final uid = (sub['user_id'] ?? '').toString();
        if (sid.isEmpty || uid.isEmpty) continue;
        final ratings = await _sb
            .from('challenge_submission_ratings')
            .select('overall_rating')
            .eq('challenge_submission_id', sid);
        final vals = (ratings as List<dynamic>)
            .map((r) => (((r as Map<String, dynamic>)['overall_rating'] as num?) ?? 0).toDouble())
            .toList(growable: false);
        final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
        scored.add(<String, dynamic>{'user_id': uid, 'avg': avg});
      }
      scored.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));

      final prizeByUser = <String, double>{};
      for (final raw in prizesRows as List<dynamic>) {
        final p = raw as Map<String, dynamic>;
        final uid = (p['winner_user_id'] ?? '').toString();
        if (uid.isEmpty) continue;
        prizeByUser[uid] = ((p['prize_amount'] as num?) ?? 0).toDouble();
      }

      for (int i = 0; i < scored.length && i < 3; i++) {
        final winnerId = (scored[i]['user_id'] ?? '').toString();
        final profile = await _sb
            .from('profiles')
            .select('display_name, avatar_url')
            .eq('id', winnerId)
            .maybeSingle();
        final prize = prizeByUser[winnerId] ?? _calculatePrize(i + 1);
        winners.add({
          'position': i + 1,
          'userId': winnerId,
          'userName': profile?['display_name'] ?? tr('il_b764cdc0ea'),
          'userAvatar': profile?['avatar_url'] ?? '',
          'rating': (scored[i]['avg'] as double?) ?? 0.0,
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
        return totalPrize * 0.5; // 50% for 1st place
      case 2:
        return totalPrize * 0.3; // 30% for 2nd place
      case 3:
        return totalPrize * 0.2; // 20% for 3rd place
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
            tr('challenge_not_found'),
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
                    // Title
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            tr('challenge_completed'),
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
                    
                    // Winners
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
                    
                    // Close button
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
                                tr('close'),
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
          tr('no_winners'),
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
        positionColor = const Color(0xFFFFD700); // Gold
        positionIcon = Icons.emoji_events;
        break;
      case 2:
        positionColor = const Color(0xFFC0C0C0); // Silver
        positionIcon = Icons.emoji_events;
        break;
      case 3:
        positionColor = const Color(0xFFCD7F32); // Bronze
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
          // Position
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
          
          // Avatar
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
          
          // Info
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
                  '${tr('rating')}: ${rating.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Prize
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

class _MapDoc {
  _MapDoc(this.id, this._data);
  final String id;
  final Map<String, dynamic> _data;
  Map<String, dynamic> data() => _data;
}


