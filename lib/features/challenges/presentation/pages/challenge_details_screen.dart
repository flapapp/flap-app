import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../../../../router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/challenge.dart';
import '../../../video/presentation/pages/video_upload_screen.dart';
import 'challenge_video_player_screen.dart';
import '../../../video/data/services/thumbnail_service.dart';
import 'challenge_completion_screen.dart';
import '../../../../widgets/video_preview_box.dart';
import '../../../../widgets/player_avatar_button.dart';

@RoutePage()
class ChallengeDetailsScreen extends StatefulWidget {
  final Challenge challenge;
  
  const ChallengeDetailsScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  _ChallengeDetailsScreenState createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isJoining = false;
  bool _isSubmitting = false;
  bool _celebrationChecked = false;

  final Map<String, ValueNotifier<double>> _voteNotifiers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWinnerCelebration();
    });
  }

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
                      GestureDetector(
                        onTap: _showParticipants,
                        child: _buildStatChip(tr('il_467d80c72d')),
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(tr('il_bb1d0b2b0e')),
                      const SizedBox(width: 8),
                      _buildStatChip('💰 ${widget.challenge.prizePool}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons - exactly like MVP
            _buildActionButtons(),
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
                  Text(
                    tr('il_7b1fd32345'),
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  Text(
                    tr('il_cab1225bc9'),
                    style: const TextStyle(color: Colors.white30, fontSize: 14),
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
            final aRating = (aData['averageRating'] ?? 0.0).toDouble();
            final bRating = (bData['averageRating'] ?? 0.0).toDouble();

            if (aIsCreator && !bIsCreator) return -1;
            if (!aIsCreator && bIsCreator) return 1;
            return bRating.compareTo(aRating);
          });
        
        return Column(
          children: sortedVideos.map((doc) => _buildVideoCard(doc)).toList(),
        );
      },
    );
  }

  // Окремий метод для модального вікна з повноширінними прев'ю
  Widget _buildVideosListForModal() {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                const SizedBox(height: 12),
                Text(
                  tr('il_7b1fd32345'),
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
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
          children: sortedVideos.map((doc) => _buildModalVideoCard(doc)).toList(),
        );
      },
    );
  }

  // Відео картка для модального вікна з повноширінним прев'ю
  Widget _buildModalVideoCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final videoId = doc.id;
    final title = data['title'] ?? tr('il_f59ab8d133');
    final userId = data['userId'] ?? '';
    final videoUrl = data['videoUrl'] ?? '';
    final isCreatorVideo = data['isCreatorVideo'] ?? false;
    final rating = (data['averageRating'] ?? 0.0).toDouble();
    final likesCount = data['voteCount'] ?? 0;
    String thumb = (data['thumbnailUrl'] ?? '') as String;
    final videoDocId = data['videoId'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Прев'ю відео - займає весь простір (як на YouTube)
          FutureBuilder<String?>(
            future: _getThumbnailUrl(thumb, videoDocId, videoUrl),
            builder: (context, snapshot) {
              final effectiveThumb = snapshot.data ?? thumb;
              return VideoPreviewBox(
                videoUrl: videoUrl,
                thumbnailUrl: effectiveThumb,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChallengeVideoPlayerScreen(
                        videoUrl: videoUrl,
                        title: title,
                        authorName: 'Автор відео',
                        challengeId: widget.challenge.id,
                        submissionId: videoId,
                        thumbnailUrl: effectiveThumb,
                      ),
                    ),
                  );
                },
                borderRadius: 12,
                topLeft: isCreatorVideo
                    ? _badge(tr('il_88447b8309'), color: const Color(0xFF4caf50))
                    : null,
                bottomRight: _badge(
                  tr('il_22f29c1ea8'),
                  color: Colors.black.withOpacity(0.6),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          
          // Інформація про відео
          Row(
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF4caf50),
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    );
                  }
                  
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
                  final userName = userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? tr('il_b512d97e7c');
                  
                  return PlayerAvatarButton(
                    userId: userId,
                    displayName: userName,
                    avatarUrl: avatarUrl,
                    size: 40,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCreatorVideo)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4caf50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tr('il_fdd5f6745e'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStars(rating),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Color(0xFF66bb6a),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          tr('il_bc2a9a8bbb'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final videoId = doc.id;
    final title = data['title'] ?? tr('il_f59ab8d133');
    final userId = data['userId'] ?? '';
    final videoUrl = data['videoUrl'] ?? '';
    final isCreatorVideo = data['isCreatorVideo'] ?? false;
    final rating = (data['averageRating'] ?? 0.0).toDouble();
    final likesCount = data['voteCount'] ?? 0;
    // Отримуємо thumbnailUrl з submission, якщо немає - спробуємо з основного відео документа
    String thumb = (data['thumbnailUrl'] ?? '') as String;
    final videoDocId = data['videoId'] ?? '';

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
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, userSnapshot) {
              final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
              final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
              final userName = userData['displayName'] ??
                  userData['name'] ??
                  userData['email']?.split('@')[0] ??
                  tr('il_b512d97e7c');
              return Row(
                children: [
                  PlayerAvatarButton(
                    userId: userId,
                    displayName: userName,
                    avatarUrl: avatarUrl,
                    size: 34,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChallengeVideoPlayerScreen(
                              videoUrl: videoUrl,
                              title: title,
                              authorName: userName,
                              challengeId: widget.challenge.id,
                              submissionId: videoId,
                              thumbnailUrl: thumb,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
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
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4caf50),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tr('il_fdd5f6745e'),
                                    style: const TextStyle(
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
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Rating display
          Row(
            children: [
              _buildStars(rating),
              const SizedBox(width: 6),
              Text(
                rating.toStringAsFixed(2),
                style: const TextStyle(
                  color: Color(0xFF66bb6a),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                tr('il_bc2a9a8bbb'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Voting section - exactly like MVP (video preview comes first, then voting controls)
          FutureBuilder<String?>(
            future: _getThumbnailUrl(thumb, videoDocId, videoUrl),
            builder: (context, snapshot) {
              final effectiveThumb = snapshot.data ?? thumb;
              return _buildVotingSection(videoId, videoUrl, title, userId, thumbnailUrl: effectiveThumb);
            },
          ),
          const SizedBox(height: 8),

          // Action buttons
          LayoutBuilder(
  builder: (context, constraints) {
    final isNarrow = constraints.maxWidth < 360;

    final buttons = <Widget>[
      ElevatedButton.icon(
        onPressed: () => _playVideo(videoUrl, title, videoId, userId, thumbnailUrl: thumb),
        icon: const Icon(Icons.play_arrow, size: 16),
        label: Text(tr('il_a71e757324'), style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(0, 36),
        ),
      ),
      ElevatedButton.icon(
        onPressed: () => _shareVideo(videoId),
        icon: const Icon(Icons.share, size: 16),
        label: Text(tr('share'), style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(0, 36),
        ),
      ),
      ElevatedButton.icon(
        onPressed: () => _saveVideo(videoId),
        icon: const Icon(Icons.bookmark_outline, size: 16),
        label: Text(tr('save'), style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(0, 36),
        ),
      ),
    ];

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in buttons)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: b),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: buttons
          .map((b) => SizedBox(height: 36, child: b))
          .toList(),
    );
  },
)
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

  // Показати список учасників
  Widget _buildActionButtons() {
    final now = DateTime.now();
    final isFinished = widget.challenge.endDate.isBefore(now);
    
    if (isFinished) {
      // Показуємо кнопку результатів для завершених челенджів
      return ElevatedButton.icon(
        onPressed: _showResults,
        icon: const Icon(Icons.emoji_events),
        label: Text(tr('il_82389e3a90'), style: const TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }
    
    // Для активних челенджів - звичайні кнопки
    return Row(
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
            child: Text(tr('il_b0237f6faf'), style: const TextStyle(fontWeight: FontWeight.w600)),
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
            child: Text(tr('il_55d4b4bd7f'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  void _showResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeCompletionScreen(challengeId: widget.challenge.id),
      ),
    );
  }

  Future<void> _maybeShowWinnerCelebration() async {
    if (_celebrationChecked) return;
    _celebrationChecked = true;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .get();
      if (!challengeDoc.exists) return;

      final latestChallenge = Challenge.fromFirestore(challengeDoc);
      if (latestChallenge.status != ChallengeStatus.completed) return;
      if (!latestChallenge.winners.contains(currentUser.uid)) return;

      final celebrationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('challengeCelebrations')
          .doc(widget.challenge.id);
      final shownDoc = await celebrationRef.get();
      if (shownDoc.exists) return;

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ChallengeCompletionScreen(
            challengeId: widget.challenge.id,
          ),
        ),
      );

      await celebrationRef.set({
        'challengeId': widget.challenge.id,
        'shownAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to show celebration: $e');
    }
  }

  void _showParticipants() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Учасники челенджу (${widget.challenge.participants.length})',
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
              const Divider(color: Colors.white24, height: 1),
              // Participants list
              Expanded(
                child: widget.challenge.participants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('il_e051442724'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.challenge.participants.length,
                        itemBuilder: (context, index) {
                          final participantId = widget.challenge.participants[index];
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(participantId)
                                .get(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF4caf50),
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(tr('il_47d2a515ef'), style: const TextStyle(color: Colors.white)),
                                );
                              }

                              final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                              final userName = userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? tr('il_b512d97e7c');
                              final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
                              final rating = (userData['rating'] ?? 0.0).toDouble();
                              final city = userData['city'] ?? tr('il_2491fe94a7');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.router.push(
                                      PlayerProfileRoute(
                                        playerId: participantId,
                                        playerName: userName,
                                      ),
                                    );
                                  },
                                  leading: PlayerAvatarButton(
                                    userId: participantId,
                                    displayName: userName,
                                    avatarUrl: avatarUrl,
                                    size: 40,
                                  ),
                                  title: Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        city,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Color(0xFF4caf50), size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Color(0xFF4caf50),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: participantId == widget.challenge.creatorId
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4caf50).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            tr('il_88447b8309'),
                                            style: const TextStyle(
                                              color: Color(0xFF4caf50),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVotingSection(String videoId, String videoUrl, String title, String userId, {String? thumbnailUrl}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id)
          .collection('votes')
          .doc('${FirebaseAuth.instance.currentUser?.uid}_$videoId')
          .snapshots(),
      builder: (context, voteSnapshot) {
        final hasVoted = voteSnapshot.hasData && voteSnapshot.data!.exists;
        double currentVote = (_voteNotifiers[videoId]?.value) ?? 0.0;

        if (hasVoted) {
          final voteData =
              voteSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final serverVote = (voteData['rating'] ?? 0.0).toDouble();
          if (_voteNotifiers.containsKey(videoId)) {
            if ((_voteNotifiers[videoId]!.value - serverVote).abs() > 0.01) {
              _voteNotifiers[videoId]!.value = serverVote;
            }
          } else {
            _voteNotifiers[videoId] = ValueNotifier<double>(serverVote);
          }
        } else {
          _voteNotifiers.putIfAbsent(
              videoId, () => ValueNotifier<double>(currentVote));
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
              // Video preview with thumbnail
              VideoPreviewBox(
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                onTap: () {
                  if (videoUrl.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChallengeVideoPlayerScreen(
                          videoUrl: videoUrl,
                          title: title,
                          authorName: 'Автор відео',
                          challengeId: widget.challenge.id,
                          submissionId: videoId,
                          thumbnailUrl: thumbnailUrl,
                        ),
                      ),
                    );
                  }
                },
                aspectRatio: 16 / 9,
                borderRadius: 12,
                topRight: hasVoted
                    ? _badge(tr('il_24e6347ec5'),
                        color: const Color(0xFF4caf50).withOpacity(0.8))
                    : null,
              ),
              Row(
                children: [
                  Text(
                    tr('il_30b17903f7'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _voteNotifiers[videoId]!,
                      builder: (context, value, _) => Slider(
                        value: value,
                        min: 0.0,
                        max: 5.0,
                        // без divisions для плавності
                        activeColor: const Color(0xFF4caf50),
                        inactiveColor: Colors.white.withOpacity(0.2),
                        onChanged: hasVoted ? null : (v) {
                          _voteNotifiers[videoId]!.value = v;
                        },
                        onChangeEnd: hasVoted ? null : (v) {
                          final rounded = (v * 100).round() / 100;
                          _voteNotifiers[videoId]!.value = rounded;
                        },
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _voteNotifiers[videoId]!,
                      builder: (context, v, _) => Text(
                        v.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Color(0xFF66bb6a),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: hasVoted ? null : () => _submitVote(videoId, _voteNotifiers[videoId]!.value),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasVoted ? Colors.grey : const Color(0xFF4caf50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      hasVoted ? tr('il_9cf238dedb') : tr('il_cd5588db6f'),
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

  Widget _previewPlaceholder(String title) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF8bc34a)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _badge(String label, {Color color = const Color(0x99000000)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _submitVote(String videoId, double rating) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Перевіряємо чи користувач не голосує за себе
    final submissionDoc = await FirebaseFirestore.instance
        .collection('challenges')
        .doc(widget.challenge.id)
        .collection('submissions')
        .doc(videoId)
        .get();
        
    if (submissionDoc.exists) {
      final submissionData = submissionDoc.data() as Map<String, dynamic>;
      final submissionUserId = submissionData['userId'];
      
      if (submissionUserId == currentUser.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_2c08f46d5a')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

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

      // Recompute overall rating for the submission author (affects player rating)
      try {
        final submission = await submissionRef.get();
        if (submission.exists) {
          final userId = (submission.data() as Map<String, dynamic>)['userId'] as String?;
          if (userId != null && userId.isNotEmpty && userId != currentUser.uid) {
            await sl<RatingsRepository>().recomputeOverallRating(
              userId,
              reason: 'challenge_vote',
              source: currentUser.displayName ?? '',
              sourceType: 'challenge',
              sourceId: widget.challenge.id,
            );
          }
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_5acb71c66c')),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_53594cb961')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _playVideo(String videoUrl, String title, String videoId, String userId, {String? thumbnailUrl}) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_fc512c458e'))),
      );
      return;
    }

    // Використовуємо ChallengeVideoPlayerScreen для відео в челенджах
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeVideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
          authorName: 'Автор відео',
          challengeId: widget.challenge.id,
          submissionId: videoId,
          thumbnailUrl: thumbnailUrl,
        ),
      ),
    );
  }

  // Отримує thumbnailUrl: спочатку з submission, потім з основного відео документа, якщо немає - генеруємо
  Future<String?> _getThumbnailUrl(String submissionThumb, String videoDocId, String videoUrl) async {
    // Якщо є thumbnail в submission, повертаємо його
    if (submissionThumb.isNotEmpty) {
      return submissionThumb;
    }
    
    // Якщо є videoId, спробуємо отримати thumbnail з основного відео документа
    if (videoDocId.isNotEmpty) {
      try {
        final videoDoc = await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoDocId)
            .get();
        
        if (videoDoc.exists) {
          final videoData = videoDoc.data() as Map<String, dynamic>;
          final videoThumb = (videoData['thumbnailUrl'] ?? '') as String;
          if (videoThumb.isNotEmpty) {
            // Оновлюємо submission з thumbnailUrl з основного відео
            try {
              await FirebaseFirestore.instance
                  .collection('challenges')
                  .doc(widget.challenge.id)
                  .collection('submissions')
                  .doc(videoDoc.id)
                  .update({'thumbnailUrl': videoThumb});
            } catch (_) {}
            return videoThumb;
          }
        }
      } catch (e) {
        print('⚠️ Error getting thumbnail from video doc: $e');
      }
    }
    
    // Якщо немає thumbnail, спробуємо згенерувати його
    if (videoUrl.isNotEmpty && videoDocId.isNotEmpty) {
      try {
        final thumbnailService = ThumbnailService();
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final thumbnailUrl = await thumbnailService.generateSubmissionThumbnail(
          videoUrl: videoUrl,
          challengeId: widget.challenge.id,
          submissionId: videoDocId,
          userId: userId,
        );
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          return thumbnailUrl;
        }
      } catch (e) {
        print('⚠️ Error generating thumbnail: $e');
      }
    }
    
    return null;
  }

  void _shareVideo(String videoId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('il_68d6f33dd6'))),
    );
  }

  void _saveVideo(String videoId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('il_f2d73b37cf'))),
    );
  }

  void _uploadVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoUploadScreen(
          challengeId: widget.challenge.id,
          challengeTitle: widget.challenge.title,
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
                child: _buildVideosListForModal(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
