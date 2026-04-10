import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/challenges/domain/challenge_failure.dart';
import 'package:flap_app/features/challenges/domain/entities/challenge_submission_entry.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/features/videos/presentation/screens/video_upload_screen.dart';
import 'challenge_video_player_screen.dart';
import 'package:flap_app/features/matches/data/rating_service.dart';
import 'package:flap_app/features/videos/data/thumbnail_service.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'challenge_completion_screen.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/video_preview_box.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
class ChallengeDetailsScreen extends StatefulWidget {
  final Challenge challenge;
  
  const ChallengeDetailsScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  _ChallengeDetailsScreenState createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
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
                        child: _buildStatChip(I18n.inline('👥 ${widget.challenge.participants.length} учасників', '👥 ${widget.challenge.participants.length} participants')),
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(I18n.inline('📹 ${widget.challenge.submissions.length} відео', '📹 ${widget.challenge.submissions.length} videos')),
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
    return StreamBuilder<List<ChallengeSubmissionEntry>>(
      stream: context.read<ChallengeRepository>().watchSubmissions(widget.challenge.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
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
                    I18n.inline('Поки що немає відео', 'No videos yet'),
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  Text(
                    I18n.inline('Будьте першим, хто прийме виклик!', 'Be the first to accept the challenge!'),
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
                    'Submissions (Supabase): 0',
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

        final sortedVideos = entries.toList()
          ..sort((a, b) {
            if (a.isCreatorVideo && !b.isCreatorVideo) return -1;
            if (!a.isCreatorVideo && b.isCreatorVideo) return 1;
            return b.averageRating.compareTo(a.averageRating);
          });

        return Column(
          children: sortedVideos.map(_buildVideoCard).toList(),
        );
      },
    );
  }

  // Окремий метод для модального вікна з повноширінними прев'ю
  Widget _buildVideosListForModal() {
    return StreamBuilder<List<ChallengeSubmissionEntry>>(
      stream: context.read<ChallengeRepository>().watchSubmissions(widget.challenge.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                const SizedBox(height: 12),
                Text(
                  I18n.inline('Поки що немає відео', 'No videos yet'),
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final sortedVideos = entries.toList()
          ..sort((a, b) {
            if (a.isCreatorVideo && !b.isCreatorVideo) return -1;
            if (!a.isCreatorVideo && b.isCreatorVideo) return 1;
            return 0;
          });

        return Column(
          children: sortedVideos.map(_buildModalVideoCard).toList(),
        );
      },
    );
  }

  // Відео картка для модального вікна з повноширінним прев'ю
  Widget _buildModalVideoCard(ChallengeSubmissionEntry s) {
    final submissionUserId = s.userId;
    final title = s.title.isNotEmpty ? s.title : I18n.inline('Без назви', 'Untitled');
    final userId = s.userId;
    final videoUrl = s.videoUrl;
    final isCreatorVideo = s.isCreatorVideo;
    final rating = s.averageRating;
    final likesCount = s.voteCount;
    String thumb = s.thumbnailUrl;
    final videoDocId = s.videoId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Прев'ю відео - займає весь простір (як на YouTube)
          FutureBuilder<String?>(
            future: _getThumbnailUrl(thumb, submissionUserId, videoDocId, videoUrl),
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
                        authorName: s.authorName.isNotEmpty ? s.authorName : I18n.inline('Автор відео', 'Author'),
                        challengeId: widget.challenge.id,
                        submissionId: submissionUserId,
                        thumbnailUrl: effectiveThumb,
                      ),
                    ),
                  );
                },
                borderRadius: 12,
                topLeft: isCreatorVideo
                    ? _badge(I18n.inline('Автор', 'Creator'), color: const Color(0xFF4caf50))
                    : null,
                bottomRight: _badge(
                  I18n.inline('${rating.toStringAsFixed(1)}★', '${rating.toStringAsFixed(1)}★'),
                  color: Colors.black.withOpacity(0.6),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          
          // Інформація про відео
          Row(
            children: [
              FutureBuilder(
                future: context.read<UserProfileRepository>().loadProfile(userId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF4caf50),
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    );
                  }

                  final prof = userSnapshot.data;
                  final avatarUrl = prof?.avatarUrl ?? '';
                  final userName = prof?.resolveDisplayName().isNotEmpty == true
                      ? prof!.resolveDisplayName()
                      : (s.authorName.isNotEmpty
                          ? s.authorName
                          : I18n.inline('Користувач', 'User'));

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
                              I18n.inline('АВТОР', 'CREATOR'),
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
                          I18n.inline(' (${likesCount} оцінок)', ' (${likesCount} votes)'),
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

  Widget _buildVideoCard(ChallengeSubmissionEntry s) {
    final submissionUserId = s.userId;
    final title = s.title.isNotEmpty ? s.title : I18n.inline('Без назви', 'Untitled');
    final userId = s.userId;
    final videoUrl = s.videoUrl;
    final isCreatorVideo = s.isCreatorVideo;
    final rating = s.averageRating;
    final likesCount = s.voteCount;
    String thumb = s.thumbnailUrl;
    final videoDocId = s.videoId;

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
          FutureBuilder(
            future: context.read<UserProfileRepository>().loadProfile(userId),
            builder: (context, userSnapshot) {
              final prof = userSnapshot.data;
              final avatarUrl = prof?.avatarUrl ?? '';
              final userName = prof?.resolveDisplayName().isNotEmpty == true
                  ? prof!.resolveDisplayName()
                  : (s.authorName.isNotEmpty
                      ? s.authorName
                      : I18n.inline('Користувач', 'User'));
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
                              submissionId: submissionUserId,
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
                                    I18n.inline('АВТОР', 'CREATOR'),
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
                I18n.inline(' (${likesCount} оцінок)', ' (${likesCount} votes)'),
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
            future: _getThumbnailUrl(thumb, submissionUserId, videoDocId, videoUrl),
            builder: (context, snapshot) {
              final effectiveThumb = snapshot.data ?? thumb;
              return _buildVotingSection(
                submissionUserId,
                videoUrl,
                title,
                thumbnailUrl: effectiveThumb,
              );
            },
          ),
          const SizedBox(height: 8),

          // Action buttons
          LayoutBuilder(
  builder: (context, constraints) {
    final isNarrow = constraints.maxWidth < 360;

    final buttons = <Widget>[
      ElevatedButton.icon(
        onPressed: () => _playVideo(videoUrl, title, submissionUserId, thumbnailUrl: thumb),
        icon: const Icon(Icons.play_arrow, size: 16),
        label: Text(I18n.inline('Дивитися', 'Watch'), style: const TextStyle(fontSize: 12)),
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
        onPressed: () => _shareVideo(submissionUserId),
        icon: const Icon(Icons.share, size: 16),
        label: Text(I18n.t('share'), style: const TextStyle(fontSize: 12)),
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
        onPressed: () => _saveVideo(submissionUserId),
        icon: const Icon(Icons.bookmark_outline, size: 16),
        label: Text(I18n.t('save'), style: const TextStyle(fontSize: 12)),
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
        label: Text(I18n.inline('🏆 Результати', '🏆 Results'), style: const TextStyle(fontWeight: FontWeight.w600)),
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
            child: Text(I18n.inline('📤 Завантажити відео', '📤 Upload video'), style: const TextStyle(fontWeight: FontWeight.w600)),
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
            child: Text(I18n.inline('📹 Переглянути (${widget.challenge.submissions.length})', '📹 View (${widget.challenge.submissions.length})'), style: const TextStyle(fontWeight: FontWeight.w600)),
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

    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;

    try {
      final repo = context.read<ChallengeRepository>();
      final latestChallenge = await repo.getChallenge(widget.challenge.id);
      if (latestChallenge == null) return;
      if (latestChallenge.status != ChallengeStatus.completed) return;
      if (!latestChallenge.winners.contains(currentUser.id)) return;

      if (await repo.hasCelebrationAck(widget.challenge.id)) return;

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

      await repo.ackCelebration(widget.challenge.id);
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
                              I18n.inline('Поки немає учасників', 'No participants yet'),
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
                          return FutureBuilder(
                            future: context.read<UserProfileRepository>().loadProfile(participantId),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF4caf50),
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(I18n.inline('Завантаження...', 'Loading...'), style: const TextStyle(color: Colors.white)),
                                );
                              }

                              final prof = snapshot.data;
                              final userName = prof?.resolveDisplayName().isNotEmpty == true
                                  ? prof!.resolveDisplayName()
                                  : I18n.inline('Користувач', 'User');
                              final avatarUrl = prof?.avatarUrl ?? '';
                              final rating = prof?.rating ?? 0.0;
                              final city = prof?.city?.isNotEmpty == true
                                  ? prof!.city!
                                  : I18n.inline('Невідоме місто', 'Unknown city');

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
                                    Navigator.pushNamed(
                                      context,
                                      '/player-profile',
                                      arguments: {
                                        'playerId': participantId,
                                        'playerName': userName,
                                      },
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
                                            I18n.inline('Творець', 'Creator'),
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

  Widget _buildVotingSection(
    String submissionUserId,
    String videoUrl,
    String title, {
    String? thumbnailUrl,
  }) {
    return StreamBuilder<Map<String, double>>(
      stream: context.read<ChallengeRepository>().watchMyVotes(widget.challenge.id),
      builder: (context, voteSnapshot) {
        final myVotes = voteSnapshot.data ?? {};
        final existingVote = myVotes[submissionUserId];
        final hasVoted = existingVote != null;
        double currentVote = (_voteNotifiers[submissionUserId]?.value) ?? 0.0;

        if (existingVote != null) {
          final sv = existingVote;
          if (_voteNotifiers.containsKey(submissionUserId)) {
            if ((_voteNotifiers[submissionUserId]!.value - sv).abs() > 0.01) {
              _voteNotifiers[submissionUserId]!.value = sv;
            }
          } else {
            _voteNotifiers[submissionUserId] = ValueNotifier<double>(sv);
          }
        } else {
          _voteNotifiers.putIfAbsent(
            submissionUserId,
            () => ValueNotifier<double>(currentVote),
          );
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
                          submissionId: submissionUserId,
                          thumbnailUrl: thumbnailUrl,
                        ),
                      ),
                    );
                  }
                },
                aspectRatio: 16 / 9,
                borderRadius: 12,
                topRight: hasVoted
                    ? _badge(I18n.inline('Мій голос', 'My vote'),
                        color: const Color(0xFF4caf50).withOpacity(0.8))
                    : null,
              ),
              Row(
                children: [
                  Text(
                    I18n.inline('Ваша оцінка:', 'Your rating:'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _voteNotifiers[submissionUserId]!,
                      builder: (context, value, _) => Slider(
                        value: value,
                        min: 0.0,
                        max: 5.0,
                        activeColor: const Color(0xFF4caf50),
                        inactiveColor: Colors.white.withOpacity(0.2),
                        onChanged: hasVoted ? null : (v) {
                          _voteNotifiers[submissionUserId]!.value = v;
                        },
                        onChangeEnd: hasVoted ? null : (v) {
                          final rounded = (v * 100).round() / 100;
                          _voteNotifiers[submissionUserId]!.value = rounded;
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _voteNotifiers[submissionUserId]!,
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
                    onPressed: hasVoted
                        ? null
                        : () => _submitVote(
                              submissionUserId,
                              _voteNotifiers[submissionUserId]!.value,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasVoted ? Colors.grey : const Color(0xFF4caf50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      hasVoted ? I18n.inline('Проголосовано', 'Voted') : I18n.inline('Голос', 'Vote'),
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

  Future<void> _submitVote(String submissionUserId, double rating) async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;

    if (submissionUserId == currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('❌ Не можна голосувати за себе!', '❌ Cannot vote for yourself!')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await context.read<ChallengeRepository>().castVote(
            challengeId: widget.challenge.id,
            submissionUserId: submissionUserId,
            rating: rating,
            awardCoin: false,
          );

      try {
        await RatingService().recomputeOverallRating(
          submissionUserId,
          reason: 'challenge_vote',
          source: currentUser.displayName ?? '',
          sourceType: 'challenge',
          sourceId: widget.challenge.id,
        );
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline(
            '✅ Ваша оцінка ${rating.toStringAsFixed(1)} збережена!',
            '✅ Your rating ${rating.toStringAsFixed(1)} saved!',
          )),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } on ChallengeFailure catch (f) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('❌ ${f.message}', '❌ ${f.message}')),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('❌ Помилка збереження оцінки', '❌ Error saving rating')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _playVideo(
    String videoUrl,
    String title,
    String submissionUserId, {
    String? thumbnailUrl,
  }) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('❌ Відео недоступне', '❌ Video unavailable'))),
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
          submissionId: submissionUserId,
          thumbnailUrl: thumbnailUrl,
        ),
      ),
    );
  }

  // Отримує thumbnailUrl: спочатку з submission, потім з основного відео документа, якщо немає - генеруємо
  Future<String?> _getThumbnailUrl(
    String submissionThumb,
    String submissionUserId,
    String videoDocId,
    String videoUrl,
  ) async {
    if (submissionThumb.isNotEmpty) {
      return submissionThumb;
    }

    if (videoDocId.isNotEmpty) {
      try {
        final video = await context.read<VideosRepository>().fetchVideo(videoDocId);
        final videoThumb = video?.thumbnailUrl ?? '';
        if (videoThumb.isNotEmpty) {
          try {
            await context.read<ChallengeRepository>().setSubmissionThumbnail(
                  challengeId: widget.challenge.id,
                  userId: submissionUserId,
                  thumbnailUrl: videoThumb,
                );
          } catch (_) {}
          return videoThumb;
        }
      } catch (e) {
        print('⚠️ Error getting thumbnail from video doc: $e');
      }
    }

    if (videoUrl.isNotEmpty && submissionUserId.isNotEmpty) {
      try {
        final thumbnailService = ThumbnailService();
        final userId = AppAuthContext.userId ?? '';
        final thumbnailUrl = await thumbnailService.generateSubmissionThumbnail(
          videosRepository: context.read<VideosRepository>(),
          videoUrl: videoUrl,
          challengeId: widget.challenge.id,
          submissionId: submissionUserId,
          userId: userId,
        );
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          try {
            await context.read<ChallengeRepository>().setSubmissionThumbnail(
                  challengeId: widget.challenge.id,
                  userId: submissionUserId,
                  thumbnailUrl: thumbnailUrl,
                );
          } catch (_) {}
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
      SnackBar(content: Text(I18n.inline('🔗 Посилання скопійовано', '🔗 Link copied'))),
    );
  }

  void _saveVideo(String videoId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('💾 Відео збережено', '💾 Video saved'))),
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
