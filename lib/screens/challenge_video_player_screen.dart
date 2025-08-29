import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChallengeVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String authorName;
  final String challengeId;
  final String submissionId;

  const ChallengeVideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.challengeId,
    required this.submissionId,
  }) : super(key: key);

  @override
  _ChallengeVideoPlayerScreenState createState() => _ChallengeVideoPlayerScreenState();
}

class _ChallengeVideoPlayerScreenState extends State<ChallengeVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  
  // Голосування за відео в челенджі (0.00 - 5.00 з кроком 0.01) - ОДНИМ повзунком
  double _rating = 2.50;
  double _tempRating = 2.50; // Тимчасове значення для плавності
  bool _hasVoted = false;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkIfVoted();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: false,
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Помилка відтворення відео',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfVoted() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final voteDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .collection('votes')
          .doc('${currentUser.uid}_${widget.submissionId}')
          .get();

      if (voteDoc.exists) {
        final voteData = voteDoc.data() as Map<String, dynamic>;
        setState(() {
          _hasVoted = true;
          _rating = (voteData['rating'] ?? 2.50).toDouble();
        });
      }
    } catch (e) {
      print('Error checking vote status: $e');
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Автор: ${widget.authorName}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareVideo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Video Player
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Помилка завантаження відео',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : _chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : const SizedBox(),
            ),
          ),

          // Voting Section - ОДНИМ повзунком для челенджів
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0f0f23),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      const Icon(Icons.how_to_vote, color: Color(0xFF4caf50), size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Ваша оцінка',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_hasVoted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4caf50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Проголосовано',
                            style: TextStyle(
                              color: Color(0xFF4caf50),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Single Rating Slider
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Загальна оцінка:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4caf50).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF4caf50)),
                              ),
                              child: Text(
                                _tempRating.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Color(0xFF4caf50),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF4caf50),
                            inactiveTrackColor: const Color(0xFF4caf50).withOpacity(0.3),
                            thumbColor: const Color(0xFF4caf50),
                            overlayColor: const Color(0xFF4caf50).withOpacity(0.2),
                            valueIndicatorColor: const Color(0xFF4caf50),
                            valueIndicatorTextStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: Slider(
                            value: _tempRating,
                            min: 0.0,
                            max: 5.0,
                            // Видаляю divisions для плавності
                            label: _tempRating.toStringAsFixed(2),
                            onChanged: _hasVoted ? null : (value) {
                              // Оновлюємо тільки тимчасове значення для максимальної плавності
                              _tempRating = value;
                            },
                            onChangeEnd: _hasVoted ? null : (value) {
                              // Зберігаємо остаточне значення з округленням до 0.01
                              final roundedValue = (value * 100).round() / 100;
                              setState(() {
                                _rating = roundedValue;
                                _tempRating = roundedValue;
                              });
                            },
                          ),
                        ),
                        
                        // Rating scale
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0.00',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '2.50',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '5.00',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Vote Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _hasVoted || _isVoting ? null : _submitVote,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasVoted 
                                  ? Colors.grey 
                                  : const Color(0xFF4caf50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isVoting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _hasVoted 
                                        ? 'Ви вже проголосували' 
                                        : '🗳️ Проголосувати (+1 монета)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Help text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Оціните відео від 0.00 до 5.00. Ваша оцінка впливає на результат челенджу.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitVote() async {
    if (_hasVoted || _isVoting) return;

    setState(() {
      _isVoting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Перевіряємо чи користувач не голосує за себе
      final submissionDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .collection('submissions')
          .doc(widget.submissionId)
          .get();
          
      if (submissionDoc.exists) {
        final submissionData = submissionDoc.data() as Map<String, dynamic>;
        final submissionUserId = submissionData['userId'];
        
        if (submissionUserId == currentUser.uid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Не можна голосувати за себе!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isVoting = false);
          return;
        }
      }

      // Save vote to challenge votes subcollection
      await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .collection('votes')
          .doc('${currentUser.uid}_${widget.submissionId}')
          .set({
        'userId': currentUser.uid,
        'submissionId': widget.submissionId,
        'challengeId': widget.challengeId,
        'rating': _rating,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update submission rating
      final submissionRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .collection('submissions')
          .doc(widget.submissionId);
          
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final submissionDoc = await transaction.get(submissionRef);
        if (!submissionDoc.exists) return;

        final data = submissionDoc.data() as Map<String, dynamic>;
        final currentRating = (data['averageRating'] ?? 0.0).toDouble();
        final currentVotes = (data['voteCount'] ?? 0).toInt();
        
        final newVotes = currentVotes + 1;
        final newRating = ((currentRating * currentVotes) + _rating) / newVotes;

        transaction.update(submissionRef, {
          'averageRating': newRating,
          'voteCount': newVotes,
        });
      });

      // Award coins for voting
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'coins': FieldValue.increment(1), // +1 coin for voting
      });

      // Record transaction
      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': currentUser.uid,
        'type': 'challenge_vote',
        'amount': 1,
        'challengeId': widget.challengeId,
        'submissionId': widget.submissionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Голосування в челенджі',
      });

      setState(() {
        _hasVoted = true;
        _isVoting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Ваша оцінка ${_rating.toStringAsFixed(2)} збережена! +1 монета'),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      setState(() {
        _isVoting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Помилка збереження оцінки: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔗 Посилання на відео скопійовано'),
        backgroundColor: Color(0xFF4caf50),
      ),
    );
  }
}

