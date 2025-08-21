import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import 'video_upload_screen.dart';
import 'challenge_voting_screen.dart';
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
    final currentUser = _auth.currentUser;
    final isCreator = currentUser?.uid == widget.challenge.creatorId;
    final isParticipant = widget.challenge.participants.contains(currentUser?.uid);
    final hasSubmitted = widget.challenge.submissions.contains(currentUser?.uid);

    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      body: CustomScrollView(
        slivers: [
          // App Bar з зображенням
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1e7d32),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.challenge.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1e7d32),
                      const Color(0xFF2e7d32),
                    ],
                  ),
                ),
                child: widget.challenge.imageUrl != null
                    ? Image.network(
                        widget.challenge.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Icon(
                          Icons.emoji_events,
                          size: 64,
                          color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Контент
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Опис
        Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.challenge.description,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
          ),
        ],
      ),
                  ),
                  const SizedBox(height: 20),

                  // Відео учасників
                  _buildVideosSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.video_library, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Відео учасників',
                  style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('challenges')
                .doc(widget.challenge.id)
                .collection('submissions')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Помилка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.videocam_off,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
          Text(
                        'Поки що немає відео',
            style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final userId = docs[index].id;
                  final author = data['authorName'] ?? 'Учасник';
                  final videoUrl = data['videoUrl'] as String?;
                  final rating = (data['averageRating'] ?? 0.0).toDouble();
                  final voteCount = data['voteCount'] ?? 0;
                  
    return Container(
                    padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
            children: [
                        // Avatar (кліабельний)
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/player-profile',
                              arguments: {
                                'playerId': userId,
                                'playerName': author,
                              },
                            );
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4caf50).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                author.isNotEmpty ? author[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/player-profile',
                                    arguments: {
                                      'playerId': userId,
                                      'playerName': author,
                                    },
                                  );
                                },
                                child: Text(
                                  author,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white30,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (rating > 0) ...[
                                    // Зірочки як в MVP
                                    ...List.generate(5, (index) {
                                      return Icon(
                                        rating > index 
                                          ? (rating > index + 0.5 ? Icons.star : Icons.star_half)
                                          : Icons.star_border,
                                        color: Colors.amber,
                                        size: 14,
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${rating.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($voteCount)',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      'Ще не оцінено',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
            ),
        ],
      ),
                        ),
                        // Actions
                        Row(
        children: [
                            // Watch button
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                onPressed: () {
                      if (videoUrl == null || videoUrl.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoUrl: videoUrl,
                                        title: 'Відео учасника: $author',
                            authorName: author,
                            videoId: 'challenge_${docs[index].id}',
                          ),
                        ),
                      );
                    },
                                icon: const Icon(Icons.play_arrow, color: Colors.white),
                                tooltip: 'Дивитися',
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Vote button
                            if (widget.challenge.isVotingOpen)
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  onPressed: () => _showVotingDialog(userId),
                                  icon: const Icon(Icons.how_to_vote, color: Colors.white),
                                  tooltip: 'Голосувати',
                                ),
                                                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Voting section як в MVP
                        if (widget.challenge.isVotingOpen)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
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
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '0.0',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Slider(
                                  value: 0.0,
                                  min: 0.0,
                                  max: 5.0,
                                  divisions: 50,
                                  activeColor: Colors.amber,
                                  inactiveColor: Colors.white.withOpacity(0.2),
                                  onChanged: (value) {
                                    // TODO: Implement voting logic
                                  },
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // TODO: Submit vote
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4caf50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Голос',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showVotingDialog(String userId) {
    double currentRating = 0.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '⭐ Голосування', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          content: Container(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Оцініть відео гравця:',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Зірочки для відображення
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      currentRating > index 
                        ? (currentRating > index + 0.5 ? Icons.star : Icons.star_half)
                        : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Повзунок для вибору оцінки
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Ваша оцінка:',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const Spacer(),
                          Text(
                            currentRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: currentRating,
                        min: 0.0,
                        max: 5.0,
                        divisions: 50,
                        activeColor: Colors.amber,
                        inactiveColor: Colors.white.withOpacity(0.2),
                        onChanged: (value) {
                          setState(() {
                            currentRating = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Скасувати',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: currentRating > 0 ? () async {
                  await _submitVote(userId, currentRating);
                  Navigator.pop(context);
                } : null,
                child: const Text(
                  '🗳️ Голосувати',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVote(String userId, double rating) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Перевірити чи вже голосував
      final voteDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('votes')
          .doc('${currentUser.uid}_$userId')
          .get();

      if (voteDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Ви вже голосували за це відео!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Зберегти голос
      await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('votes')
          .doc('${currentUser.uid}_$userId')
          .set({
        'voterId': currentUser.uid,
        'targetUserId': userId,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Оновити рейтинг відео
      final submissionQuery = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('submissions')
          .where('userId', isEqualTo: userId)
          .get();

      if (submissionQuery.docs.isNotEmpty) {
        final submissionDoc = submissionQuery.docs.first;
        final currentRating = submissionDoc.data()['rating']?.toDouble() ?? 0.0;
        final currentVotes = submissionDoc.data()['voteCount']?.toInt() ?? 0;
        
        final newVoteCount = currentVotes + 1;
        final newRating = ((currentRating * currentVotes) + rating) / newVoteCount;

        await submissionDoc.reference.update({
          'rating': newRating,
          'voteCount': newVoteCount,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Ваш голос (${rating.toStringAsFixed(1)} ⭐) збережено!'),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Помилка голосування: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}