import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import 'video_upload_screen.dart';
import 'video_player_screen.dart';

class ChallengeDetailsScreen extends StatefulWidget {
  final Challenge challenge;
  
  const ChallengeDetailsScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  _ChallengeDetailsScreenState createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isJoining = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23),
        elevation: 0,
        title: Text(
          '🏆 ${widget.challenge.title}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Challenge info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.challenge.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatChip('👥 ${widget.challenge.participants.length} учасників'),
                      const SizedBox(width: 8),
                      _buildStatChip('📹 ${widget.challenge.submissions.length} відео'),
                      const SizedBox(width: 8),
                      _buildStatChip('💰 ${widget.challenge.prizePool}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons - exactly like MVP
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _uploadVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4caf50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('📤 Завантажити відео', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showChallengeVideos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('📹 Переглянути (${widget.challenge.submissions.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Videos list (like MVP)
            _buildVideosList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildVideosList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('submissions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.video_library_outlined, size: 48, color: Colors.white30),
                  const SizedBox(height: 12),
                  const Text(
                    'Поки що немає відео',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const Text(
                    'Будьте першим, хто прийме виклик!',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Challenge ID: ${widget.challenge.id}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  Text(
                    'Participants: ${widget.challenge.participants.length}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  Text(
                    'Submissions array: ${widget.challenge.submissions.length}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  Text(
                    'Submissions collection: ${snapshot.data?.docs.length ?? 0}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  Text(
                    'Status: ${widget.challenge.status}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  Text(
                    'Creator ID: ${widget.challenge.creatorId}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final videos = snapshot.data!.docs;
        
        // Сортуємо клієнтською стороною: відео створювача першим
        final sortedVideos = videos.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aIsCreator = aData['isCreatorVideo'] ?? false;
            final bIsCreator = bData['isCreatorVideo'] ?? false;
            
            if (aIsCreator && !bIsCreator) return -1;
            if (!aIsCreator && bIsCreator) return 1;
            return 0;
          });
        
        return Column(
          children: sortedVideos.map((doc) => _buildVideoCard(doc)).toList(),
        );
      },
    );
  }

  Widget _buildVideoCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final videoId = doc.id;
    final title = data['title'] ?? 'Без назви';
    final userId = data['userId'] ?? '';
    final videoUrl = data['videoUrl'] ?? '';
    final isCreatorVideo = data['isCreatorVideo'] ?? false;
    final rating = (data['averageRating'] ?? 0.0).toDouble();
    final likesCount = data['voteCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isCreatorVideo ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCreatorVideo 
            ? const Color(0xFF4caf50).withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
          width: isCreatorVideo ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and title
          Row(
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF4caf50),
                      child: Icon(Icons.person, color: Colors.white, size: 16),
                    );
                  }
                  
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final avatarUrl = userData['avatarUrl'] ?? '';
                  final userName = userData['name'] ?? 'Невідомий гравець';
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        backgroundColor: const Color(0xFF4caf50),
                        child: avatarUrl.isEmpty ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ) : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCreatorVideo)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4caf50),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'АВТОР',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Color(0xFF66bb6a),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rating display
          Row(
            children: [
              _buildStars(rating),
              const SizedBox(width: 6),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Color(0xFF66bb6a),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                ' (${likesCount} оцінок)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Voting section - exactly like MVP
          _buildVotingSection(videoId),
          const SizedBox(height: 8),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () => _playVideo(videoUrl, title, videoId, userId),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Дивитися', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () => _shareVideo(videoId),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Поділитися', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () => _saveVideo(videoId),
                  icon: const Icon(Icons.bookmark_outline, size: 16),
                  label: const Text('Зберегти', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Color(0xFF4caf50), size: 16);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Color(0xFF4caf50), size: 16);
        } else {
          return Icon(Icons.star_outline, color: Colors.white.withOpacity(0.3), size: 16);
        }
      }),
    );
  }

  Widget _buildVotingSection(String videoId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('votes')
          .doc('${FirebaseAuth.instance.currentUser?.uid}_$videoId')
          .snapshots(),
      builder: (context, voteSnapshot) {
        final hasVoted = voteSnapshot.hasData && voteSnapshot.data!.exists;
        double currentVote = 0.0;
        
        if (hasVoted) {
          final voteData = voteSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          currentVote = (voteData['rating'] ?? 0.0).toDouble();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Ваша оцінка:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: currentVote,
                      min: 0.0,
                      max: 5.0,
                      divisions: 50,
                      activeColor: const Color(0xFF4caf50),
                      inactiveColor: Colors.white.withOpacity(0.2),
                      onChanged: hasVoted ? null : (value) {
                        setState(() {
                          currentVote = value;
                        });
                      },
                    ),
                  ),
                  Container(
                    width: 30,
                    child: Text(
                      currentVote.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFF66bb6a),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: hasVoted ? null : () => _submitVote(videoId, currentVote),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasVoted ? Colors.grey : const Color(0xFF4caf50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      hasVoted ? 'Проголосовано' : 'Голос',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitVote(String videoId, double rating) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Save vote to challenge votes subcollection
      await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('votes')
          .doc('${currentUser.uid}_$videoId')
          .set({
        'userId': currentUser.uid,
        'videoId': videoId,
        'challengeId': widget.challenge.id,
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update submission rating
      final submissionRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('submissions')
          .doc(videoId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final submissionDoc = await transaction.get(submissionRef);
        if (!submissionDoc.exists) return;

        final data = submissionDoc.data() as Map<String, dynamic>;
        final currentRating = (data['averageRating'] ?? 0.0).toDouble();
        final currentVotes = (data['voteCount'] ?? 0).toInt();
        
        final newVotes = currentVotes + 1;
        final newRating = ((currentRating * currentVotes) + rating) / newVotes;

        transaction.update(submissionRef, {
          'averageRating': newRating,
          'voteCount': newVotes,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Ваша оцінка ${rating.toStringAsFixed(1)} збережена!'),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Помилка збереження оцінки'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _playVideo(String videoUrl, String title, String videoId, String userId) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Відео недоступне')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
          authorName: 'Автор відео', // Додаємо обов'язковий параметр
          videoId: videoId,
          challengeId: widget.challenge.id,
          submissionUserId: userId,
        ),
      ),
    );
  }

  void _shareVideo(String videoId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔗 Посилання скопійовано')),
    );
  }

  void _saveVideo(String videoId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💾 Відео збережено')),
    );
  }

  void _uploadVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoUploadScreen(
          challengeId: widget.challenge.id,
        ),
      ),
    ).then((_) {
      // Refresh the page when returning from video upload
      setState(() {});
    });
  }

  void _showChallengeVideos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF0f0f23),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '🏆 ${widget.challenge.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildVideosList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}