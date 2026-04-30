import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../router/app_router.dart';
import '../../data/models/challenge.dart';
import '../../../video/data/services/thumbnail_service.dart';
import '../../../../widgets/video_preview_box.dart';
import '../../../../widgets/player_avatar_button.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/city_localization.dart';

import '../cubit/challenge_details_cubit.dart';

@RoutePage()
class ChallengeDetailsScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeDetailsScreen({super.key, required this.challenge});

  @override
  State<ChallengeDetailsScreen> createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  bool _celebrationChecked = false;
  bool _isOpeningVideoPlayer = false;
  late final ChallengeDetailsCubit _detailsCubit;

  final Map<String, ValueNotifier<double>> _voteNotifiers = {};

  /// PostgREST returns `snake_case` keys; camelCase for compatibility with mocks.
  String _profileAvatarUrl(Map<String, dynamic> p) {
    final v = p['avatar_url'] ?? p['avatarUrl'] ?? p['avatar'];
    if (v == null) return '';
    return v.toString();
  }

  String _profileDisplayName(Map<String, dynamic> p) {
    final dn = p['display_name'] ?? p['displayName'];
    if (dn is String && dn.isNotEmpty) return dn;
    final name = p['name'];
    if (name is String && name.isNotEmpty) return name;
    final email = p['email']?.toString();
    if (email != null && email.contains('@')) return email.split('@').first;
    return tr('il_b512d97e7c');
  }

  /// Small submitter mark on the video preview (for visibility while scrolling).
  Widget _submitterAvatarOnVideo(
    String userId,
    String userName,
    String avatarUrl,
  ) {
    if (userId.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: PlayerAvatarButton(
              userId: userId,
              displayName: userName,
              avatarUrl: avatarUrl,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _detailsCubit = ChallengeDetailsCubit(
      widget.challenge.id,
      challengeCreatorId: widget.challenge.creatorId,
    )..load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWinnerCelebration();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _detailsCubit,
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0f0f23),
          elevation: 0,
          title: Text(
            '🏆 ${widget.challenge.title}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
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
                          child: _buildStatChip(
                            tr(
                              'il_467d80c72d',
                              args: ['${widget.challenge.participants.length}'],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          tr(
                            'il_bb1d0b2b0e',
                            args: ['${widget.challenge.submissions.length}'],
                          ),
                        ),
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
              _buildVideosList(context),
            ],
          ),
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

  Widget _buildVideosList(BuildContext context) {
    return BlocBuilder<ChallengeDetailsCubit, ChallengeDetailsState>(
      builder: (context, state) {
        if (state.isLoading && state.submissions.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          );
        }

        if (state.error != null && state.submissions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              state.error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        if (state.submissions.isEmpty) {
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
                  const Icon(
                    Icons.video_library_outlined,
                    size: 48,
                    color: Colors.white30,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('il_7b1fd32345'),
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  Text(
                    tr('il_cab1225bc9'),
                    style: const TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final videos = state.submissions;

        // Client-side sort: creator video first
        final sortedVideos = videos.toList()
          ..sort((a, b) {
            final aIsCreator = a['isCreatorVideo'] ?? false;
            final bIsCreator = b['isCreatorVideo'] ?? false;
            final aRating = (a['averageRating'] ?? 0.0).toDouble();
            final bRating = (b['averageRating'] ?? 0.0).toDouble();

            if (aIsCreator && !bIsCreator) return -1;
            if (!aIsCreator && bIsCreator) return 1;
            return bRating.compareTo(aRating);
          });

        final myRatings = state.myRatingsBySubmissionId;
        final submitterProfiles = state.submitterProfilesByUserId;
        return Column(
          children: sortedVideos
              .map(
                (row) => _buildVideoCard(
                  row,
                  submitterProfilesByUserId: submitterProfiles,
                  myRatingRow: myRatings[row['id']?.toString() ?? ''],
                ),
              )
              .toList(),
        );
      },
    );
  }

  // Separate method for modal with full-width previews
  Widget _buildVideosListForModal(BuildContext context) {
    return BlocBuilder<ChallengeDetailsCubit, ChallengeDetailsState>(
      builder: (context, state) {
        if (state.isLoading && state.submissions.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          );
        }

        if (state.submissions.isEmpty) {
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

        final videos = state.submissions;

        // Client-side sort: creator video first
        final sortedVideos = videos.toList()
          ..sort((a, b) {
            final aIsCreator = a['isCreatorVideo'] ?? false;
            final bIsCreator = b['isCreatorVideo'] ?? false;

            if (aIsCreator && !bIsCreator) return -1;
            if (!aIsCreator && bIsCreator) return 1;
            return 0;
          });

        return Column(
          children: sortedVideos
              .map(
                (row) => _buildModalVideoCard(
                  row,
                  submitterProfilesByUserId: state.submitterProfilesByUserId,
                ),
              )
              .toList(),
        );
      },
    );
  }

  // Video card for modal with full-width preview
  Widget _buildModalVideoCard(
    Map<String, dynamic> data, {
    required Map<String, Map<String, dynamic>> submitterProfilesByUserId,
  }) {
    final videoId = data['id']?.toString() ?? '';
    final title = data['title'] ?? tr('il_f59ab8d133');
    final userId = data['userId'] ?? '';
    final videoUrl = data['videoUrl'] ?? '';
    final isCreatorVideo = data['isCreatorVideo'] ?? false;
    final rating = (data['averageRating'] ?? 0.0).toDouble();
    final voteCount = (data['voteCount'] is int)
        ? data['voteCount'] as int
        : int.tryParse('${data['voteCount'] ?? 0}') ?? 0;
    String thumb = (data['thumbnailUrl'] ?? '') as String;

    final userData = submitterProfilesByUserId[userId] ?? <String, dynamic>{};
    final avatarUrl = _profileAvatarUrl(userData);
    final userName = _profileDisplayName(userData);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String?>(
            future: _getThumbnailUrl(thumb, videoId, videoUrl, userId),
            builder: (context, snapshot) {
              final effectiveThumb = snapshot.data ?? thumb;
              return VideoPreviewBox(
                videoUrl: videoUrl,
                thumbnailUrl: effectiveThumb,
                onTap: () {
                  _openChallengeVideoPlayer(
                    videoUrl: videoUrl,
                    title: title,
                    submissionId: videoId,
                    authorName: userName,
                    thumbnailUrl: effectiveThumb,
                  );
                },
                borderRadius: 12,
                topLeft: isCreatorVideo
                    ? _badge(
                        tr('il_88447b8309'),
                        color: const Color(0xFF4caf50),
                      )
                    : null,
                bottomLeft: userId.isEmpty
                    ? null
                    : _submitterAvatarOnVideo(userId, userName, avatarUrl),
                bottomRight: _badge(
                  tr('il_22f29c1ea8', args: [rating.toStringAsFixed(1)]),
                  color: Colors.black.withOpacity(0.6),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (userId.isNotEmpty && userData.isEmpty)
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF4caf50),
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                )
              else
                PlayerAvatarButton(
                  userId: userId,
                  displayName: userName,
                  avatarUrl: avatarUrl,
                  size: 40,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                          tr('il_bc2a9a8bbb', args: ['$voteCount']),
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

  Widget _buildVideoCard(
    Map<String, dynamic> data, {
    required Map<String, Map<String, dynamic>> submitterProfilesByUserId,
    Map<String, dynamic>? myRatingRow,
  }) {
    final videoId = data['id']?.toString() ?? '';
    final title = data['title'] ?? tr('il_f59ab8d133');
    final userId = data['userId'] ?? '';
    final videoUrl = data['videoUrl'] ?? '';
    final isCreatorVideo = data['isCreatorVideo'] ?? false;
    final rating = (data['averageRating'] ?? 0.0).toDouble();
    final voteCount = (data['voteCount'] is int)
        ? data['voteCount'] as int
        : int.tryParse('${data['voteCount'] ?? 0}') ?? 0;
    String thumb = (data['thumbnailUrl'] ?? '') as String;
    final submissionId = data['id']?.toString() ?? '';
    final userData = submitterProfilesByUserId[userId] ?? <String, dynamic>{};
    final avatarUrl = _profileAvatarUrl(userData);
    final userName = _profileDisplayName(userData);

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
              if (userId.isNotEmpty && userData.isEmpty)
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF4caf50),
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                )
              else
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
                    _openChallengeVideoPlayer(
                      videoUrl: videoUrl,
                      title: title,
                      submissionId: videoId,
                      authorName: userName,
                      thumbnailUrl: thumb,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                tr('il_bc2a9a8bbb', args: ['$voteCount']),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Video preview (avatar on corner) + voting
          FutureBuilder<String?>(
            future: _getThumbnailUrl(thumb, submissionId, videoUrl, userId),
            builder: (context, snapThumb) {
              final effectiveThumb = snapThumb.data ?? thumb;
              return _buildVotingSection(
                videoId,
                videoUrl,
                title,
                userId,
                thumbnailUrl: effectiveThumb,
                myRatingRow: myRatingRow,
                authorDisplayName: userName,
                authorAvatarUrl: avatarUrl,
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
                  onPressed: () => _playVideo(
                    videoUrl,
                    title,
                    videoId,
                    userId,
                    thumbnailUrl: thumb,
                    authorName: userName,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(
                    tr('il_a71e757324'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _shareVideo(videoId),
                  icon: const Icon(Icons.share, size: 16),
                  label: Text(
                    tr('share'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in buttons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: b,
                      ),
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
          return const Icon(
            Icons.star_half,
            color: Color(0xFF4caf50),
            size: 16,
          );
        } else {
          return Icon(
            Icons.star_outline,
            color: Colors.white.withOpacity(0.3),
            size: 16,
          );
        }
      }),
    );
  }

  // Show participants list
  Widget _buildActionButtons() {
    final isFinished = widget.challenge.status == ChallengeStatus.completed;

    if (isFinished) {
      // Results button for completed challenges
      return ElevatedButton.icon(
        onPressed: _showResults,
        icon: const Icon(Icons.emoji_events),
        label: Text(
          tr('il_82389e3a90'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    // Active challenges: default action buttons
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
            child: Text(
              tr('il_b0237f6faf'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
            child: Text(
              tr(
                'il_55d4b4bd7f',
                args: ['${widget.challenge.submissions.length}'],
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  void _showResults() {
    context.router.push(
      ChallengeCompletionRoute(challengeId: widget.challenge.id),
    );
  }

  Future<void> _maybeShowWinnerCelebration() async {
    if (_celebrationChecked) return;
    _celebrationChecked = true;

    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;

    try {
      final challengeRow = await _sb
          .from('challenges')
          .select('status')
          .eq('id', widget.challenge.id)
          .maybeSingle();
      if (challengeRow == null) return;
      final status = challengeRow['status']?.toString() ?? '';
      if (status != 'completed') return;

      final prizeRows = await _sb
          .from('challenge_prize_places')
          .select('winner_user_id')
          .eq('challenge_id', widget.challenge.id);
      final winnerIds = <String>{};
      for (final raw in (prizeRows as List<dynamic>)) {
        final uid =
            (raw as Map<String, dynamic>)['winner_user_id']?.toString() ?? '';
        if (uid.isNotEmpty) winnerIds.add(uid);
      }
      if (!winnerIds.contains(currentUser.id)) return;

      if (!mounted) return;
      await context.router.push(
        ChallengeCompletionRoute(challengeId: widget.challenge.id),
      );
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
                        tr(
                          'challenge_participants_title',
                          namedArgs: {
                            'count':
                                '${widget.challenge.participants.length}',
                          },
                        ),
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
                          final participantId =
                              widget.challenge.participants[index];
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _sb
                                .from('profiles')
                                .select(
                                  'display_name,email,avatar_url,overall_rating,city',
                                )
                                .eq('id', participantId)
                                .maybeSingle(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF4caf50),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    tr('il_47d2a515ef'),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              final userData =
                                  snapshot.data ?? <String, dynamic>{};
                              final userName = _profileDisplayName(userData);
                              final avatarUrl = _profileAvatarUrl(userData);
                              final r =
                                  userData['overall_rating'] ??
                                  userData['rating'] ??
                                  0.0;
                              final rating = (r is num)
                                  ? r.toDouble()
                                  : (double.tryParse(r.toString()) ?? 0.0);
                              final city = localizeCity(
                                (userData['city'] ?? '').toString(),
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          const Icon(
                                            Icons.star,
                                            color: Color(0xFF4caf50),
                                            size: 14,
                                          ),
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
                                  trailing:
                                      participantId ==
                                          widget.challenge.creatorId
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF4caf50,
                                            ).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                      : const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.white54,
                                          size: 16,
                                        ),
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
    String videoId,
    String videoUrl,
    String title,
    String userId, {
    String? thumbnailUrl,
    Map<String, dynamic>? myRatingRow,
    String? authorDisplayName,
    String? authorAvatarUrl,
  }) {
    final currentUserId = AppAuth.currentUserId ?? '';
    // [myRatingRow] comes from cubit and is only populated for the signed-in voter.
    final ratingRow = myRatingRow;
    final hasVoted = ratingRow != null && currentUserId.isNotEmpty;
    double currentVote = (_voteNotifiers[videoId]?.value) ?? 0.0;

    if (ratingRow != null && currentUserId.isNotEmpty) {
      final serverVote = (ratingRow['overall_rating'] ?? 0.0).toDouble();
      if (_voteNotifiers.containsKey(videoId)) {
        if ((_voteNotifiers[videoId]!.value - serverVote).abs() > 0.01) {
          _voteNotifiers[videoId]!.value = serverVote;
        }
      } else {
        _voteNotifiers[videoId] = ValueNotifier<double>(serverVote);
      }
    } else {
      _voteNotifiers.putIfAbsent(
        videoId,
        () => ValueNotifier<double>(currentVote),
      );
    }

    final nameForPlayer =
        (authorDisplayName != null && authorDisplayName.isNotEmpty)
        ? authorDisplayName
        : tr('video_author_display_name');
    final av = authorAvatarUrl ?? '';
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
                _openChallengeVideoPlayer(
                  videoUrl: videoUrl,
                  title: title,
                  submissionId: videoId,
                  authorName: nameForPlayer,
                  thumbnailUrl: thumbnailUrl,
                );
              }
            },
            aspectRatio: 16 / 9,
            borderRadius: 12,
            bottomLeft: (userId.isNotEmpty)
                ? _submitterAvatarOnVideo(userId, nameForPlayer, av)
                : null,
            topRight: hasVoted
                ? _badge(
                    tr('il_24e6347ec5'),
                    color: const Color(0xFF4caf50).withOpacity(0.8),
                  )
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
                    // No dividers for smoother scrolling
                    activeColor: const Color(0xFF4caf50),
                    inactiveColor: Colors.white.withOpacity(0.2),
                    onChanged: hasVoted
                        ? null
                        : (v) {
                            _voteNotifiers[videoId]!.value = v;
                          },
                    onChangeEnd: hasVoted
                        ? null
                        : (v) {
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
                onPressed: hasVoted
                    ? null
                    : () =>
                          _submitVote(videoId, _voteNotifiers[videoId]!.value),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasVoted
                      ? Colors.grey
                      : const Color(0xFF4caf50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  hasVoted ? tr('il_9cf238dedb') : tr('il_cd5588db6f'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
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
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;

    // Block voting for own submission
    final submissionRow = await _sb
        .from('challenge_submissions')
        .select('id,user_id')
        .eq('id', videoId)
        .maybeSingle();
    if (submissionRow == null) return;
    if (!mounted) return;
    final submissionUserId = submissionRow['user_id']?.toString();

    if (submissionUserId == currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_2c08f46d5a')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _sb.from('challenge_submission_ratings').upsert({
        'challenge_submission_id': videoId,
        'voter_user_id': currentUser.id,
        'overall_rating': rating,
      });

      // Stored aggregates are optional in schema; UI recomputes from ratings on refresh.

      if (mounted) {
        await _detailsCubit.refresh();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_5acb71c66c', args: [rating.toStringAsFixed(1)])),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_53594cb961')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _playVideo(
    String videoUrl,
    String title,
    String videoId,
    String userId, {
    String? thumbnailUrl,
    String? authorName,
  }) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_fc512c458e'))));
      return;
    }

    _openChallengeVideoPlayer(
      videoUrl: videoUrl,
      title: title,
      submissionId: videoId,
      authorName: (authorName != null && authorName.isNotEmpty)
          ? authorName
          : tr('video_author_display_name'),
      thumbnailUrl: thumbnailUrl,
    );
  }

  Future<void> _openChallengeVideoPlayer({
    required String videoUrl,
    required String title,
    required String submissionId,
    required String authorName,
    String? thumbnailUrl,
  }) async {
    if (_isOpeningVideoPlayer || videoUrl.isEmpty) return;
    _isOpeningVideoPlayer = true;
    try {
      await context.router.push(
        ChallengeVideoPlayerRoute(
          videoUrl: videoUrl,
          title: title,
          authorName: authorName,
          challengeId: widget.challenge.id,
          submissionId: submissionId,
          thumbnailUrl: thumbnailUrl,
        ),
      );
    } finally {
      _isOpeningVideoPlayer = false;
    }
  }

  Future<String?> _getThumbnailUrl(
    String submissionThumb,
    String submissionId,
    String videoUrl,
    String participantUserId,
  ) async {
    if (submissionThumb.isNotEmpty) {
      return submissionThumb;
    }
    if (videoUrl.isNotEmpty && submissionId.isNotEmpty) {
      try {
        final thumbnailService = ThumbnailService();
        final uploader = participantUserId.isNotEmpty
            ? participantUserId
            : (AppAuth.currentUserId ?? '');
        final thumbnailUrl = await thumbnailService.generateSubmissionThumbnail(
          videoUrl: videoUrl,
          challengeId: widget.challenge.id,
          submissionId: submissionId,
          userId: uploader,
        );
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          return thumbnailUrl;
        }
      } catch (e) {
        print('[challenge_details] WARN: Error generating submission thumbnail: $e');
      }
    }
    return null;
  }

  void _shareVideo(String videoId) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('il_68d6f33dd6'))));
  }

  void _saveVideo(String videoId) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('il_f2d73b37cf'))));
  }

  void _uploadVideo() {
    context.router
        .push(
          VideoUploadRoute(
            challengeId: widget.challenge.id,
            challengeTitle: widget.challenge.title,
          ),
        )
        .then((_) {
          if (!mounted) return;
          _detailsCubit.refresh();
        });
  }

  void _showChallengeVideos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: _detailsCubit,
        child: Container(
          height: MediaQuery.of(sheetContext).size.height * 0.8,
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
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildVideosListForModal(sheetContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detailsCubit.close();
    super.dispose();
  }
}
