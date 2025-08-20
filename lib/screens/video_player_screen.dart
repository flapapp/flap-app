import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String authorName;
  final String videoId;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.videoId,
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  
  // Лайки та коментарі
  bool _isLiked = false;
  int _likesCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isCommenting = false;

  // Голосування за відео (0.00 - 5.00 з кроком 0.01)
  double _technical = 2.50;
  double _creativity = 2.50;
  double _difficulty = 2.50;
  double _quality = 2.50;
  bool _hasVoted = false;
  bool _isSubmittingVote = false;
  String? _videoAuthorId;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoData();
  }

  Future<void> _loadVideoData() async {
    try {
      // Завантажуємо дані про лайки
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .get();
      
      if (videoDoc.exists) {
        final data = videoDoc.data()!;
        setState(() {
          _likesCount = data['likes'] ?? 0;
          _videoAuthorId = data['userId'] as String?;
        });
        
        // Перевіряємо чи користувач вже лайкнув
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final likeDoc = await FirebaseFirestore.instance
              .collection('videos')
              .doc(widget.videoId)
              .collection('likes')
              .doc(currentUser.uid)
              .get();
          
          setState(() {
            _isLiked = likeDoc.exists;
          });

          // Перевіряємо, чи користувач вже голосував
          final voteDoc = await FirebaseFirestore.instance
              .collection('videos')
              .doc(widget.videoId)
              .collection('votes')
              .doc(currentUser.uid)
              .get();
          if (voteDoc.exists) {
            final v = voteDoc.data() as Map<String, dynamic>;
            setState(() {
              _hasVoted = true;
              _technical = (v['technical'] ?? 0.0).toDouble();
              _creativity = (v['creativity'] ?? 0.0).toDouble();
              _difficulty = (v['difficulty'] ?? 0.0).toDouble();
              _quality = (v['quality'] ?? 0.0).toDouble();
            });
          }
        }
      }
      
      // Завантажуємо коментарі
      _loadComments();
    } catch (e) {
      print('Error loading video data: $e');
    }
  }

  Future<void> _submitVote() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (_hasVoted) return;
    if (_videoAuthorId != null && _videoAuthorId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не можна голосувати за власне відео')),
      );
      return;
    }

    setState(() {
      _isSubmittingVote = true;
    });

    final weighted = _technical * 0.4 + _creativity * 0.3 + _difficulty * 0.2 + _quality * 0.1;
    final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoId);
    final voteRef = videoRef.collection('votes').doc(currentUser.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(videoRef);
        if (!snap.exists) {
          throw Exception('Відео не знайдено');
        }
        final data = snap.data() as Map<String, dynamic>;
        final currentAvg = (data['rating'] ?? 0.0).toDouble();
        final currentVotes = (data['totalVotes'] ?? 0).toInt();

        // Запис голосу користувача
        txn.set(voteRef, {
          'technical': double.parse(_technical.toStringAsFixed(2)),
          'creativity': double.parse(_creativity.toStringAsFixed(2)),
          'difficulty': double.parse(_difficulty.toStringAsFixed(2)),
          'quality': double.parse(_quality.toStringAsFixed(2)),
          'total': double.parse(weighted.toStringAsFixed(2)),
          'userId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Оновлення середнього рейтингу та кількості голосів
        final newVotes = currentVotes + 1;
        final newAvg = ((currentAvg * currentVotes) + weighted) / newVotes;
        txn.update(videoRef, {
          'totalVotes': newVotes,
          'rating': double.parse(newAvg.toStringAsFixed(2)),
        });
      });

      setState(() {
        _hasVoted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дякуємо за ваш голос!')),
      );
    } catch (e) {
      print('Error submitting vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка голосування: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingVote = false;
        });
      }
    }
  }

  Future<void> _loadComments() async {
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();
      
      final comments = <Map<String, dynamic>>[];
      for (final doc in commentsSnapshot.docs) {
        final data = doc.data();
        comments.add({
          'id': doc.id,
          'text': data['text'] ?? '',
          'authorName': data['authorName'] ?? 'Невідомий',
          'createdAt': data['createdAt'],
        });
      }
      
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Помилка завантаження відео',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLike() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      final likeRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('likes')
          .doc(currentUser.uid);
      
      if (_isLiked) {
        // Видаляємо лайк
        await likeRef.delete();
        setState(() {
          _isLiked = false;
          _likesCount--;
        });
        
        // Оновлюємо загальну кількість лайків
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.videoId)
            .update({'likes': FieldValue.increment(-1)});
      } else {
        // Додаємо лайк
        await likeRef.set({
          'userId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isLiked = true;
          _likesCount++;
        });
        
        // Оновлюємо загальну кількість лайків
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.videoId)
            .update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Отримуємо ім'я користувача
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final authorName = userDoc.exists 
          ? (userDoc.data()!['displayName'] ?? 'Невідомий')
          : 'Невідомий';
      
      // Додаємо коментар
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'authorId': currentUser.uid,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Очищаємо поле та перезавантажуємо коментарі
      _commentController.clear();
      _loadComments();
      
      // Оновлюємо кількість коментарів
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .update({'commentsCount': FieldValue.increment(1)});
      
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  String _formatCommentDate(dynamic timestamp) {
    if (timestamp == null) return 'Нещодавно';
    
    try {
      final date = timestamp.toDate();
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
    } catch (e) {
      return 'Нещодавно';
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged, {bool enabled = true}) {
    final slider = Slider(
      value: value.clamp(0.0, 5.0),
      min: 0.0,
      max: 5.0,
      divisions: 500, // крок ~0.01
      label: value.toStringAsFixed(2),
      onChanged: enabled ? onChanged : null,
      activeColor: const Color(0xFF4caf50),
      inactiveColor: Colors.white24,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white, fontFeatures: []),
              ),
            )
          ],
        ),
        SliderTheme(
          data: const SliderThemeData(thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8)),
          child: slider,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
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
                      Text(
                        'Помилка завантаження відео',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Video player
                    Expanded(
                      child: Chewie(controller: _chewieController!),
                    ),
                    
                    // Video info
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and author
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Автор: ${widget.authorName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Actions row (like, comment, share)
                          Row(
                            children: [
                              // Like button
                              GestureDetector(
                                onTap: _toggleLike,
                                child: Row(
                                  children: [
                                    Icon(
                                      _isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: _isLiked ? Colors.red : Colors.white70,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$_likesCount',
                                      style: TextStyle(
                                        color: _isLiked ? Colors.red : Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 30),
                              
                              // Comment button
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isCommenting = !_isCommenting;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.comment_outlined,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_comments.length}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 30),
                              
                              // Share button
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Функція поширення')),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.share_outlined,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Поділитися',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          // Блок голосування за відео (4 повзунки, крок 0.01)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.how_to_vote, color: Colors.white70, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _hasVoted ? 'Ваш голос зараховано' : 'Голосування за відео',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                _buildSliderRow('Техніка', _technical, (v) => setState(() => _technical = v), enabled: !_hasVoted),
                                const SizedBox(height: 8),
                                _buildSliderRow('Креативність', _creativity, (v) => setState(() => _creativity = v), enabled: !_hasVoted),
                                const SizedBox(height: 8),
                                _buildSliderRow('Складність', _difficulty, (v) => setState(() => _difficulty = v), enabled: !_hasVoted),
                                const SizedBox(height: 8),
                                _buildSliderRow('Якість відео', _quality, (v) => setState(() => _quality = v), enabled: !_hasVoted),

                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: (!_hasVoted && !_isSubmittingVote) ? _submitVote : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4caf50),
                                      disabledBackgroundColor: Colors.white24,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(
                                      _hasVoted ? 'Ви вже проголосували' : (_isSubmittingVote ? 'Надсилаємо...' : 'Проголосувати'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Comment input
                          if (_isCommenting) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Додати коментар...',
                                      hintStyle: TextStyle(color: Colors.white54),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide: BorderSide(color: Colors.white54),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide: BorderSide(color: Colors.white54),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide: BorderSide(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: _addComment,
                                  icon: const Icon(Icons.send, color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF4caf50),
                                    shape: const CircleBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          // Comments list
                          if (_comments.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Коментарі',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ...(_comments.map((comment) => Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment['authorName'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatCommentDate(comment['createdAt']),
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment['text'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList()),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}