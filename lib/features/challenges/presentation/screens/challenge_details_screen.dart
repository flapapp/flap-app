import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/challenges/domain/challenge_failure.dart';
import 'package:flap_app/features/challenges/domain/entities/challenge_submission_entry.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/features/challenges/presentation/screens/challenge_detail/challenge_detail_design.dart';
import 'package:flap_app/features/challenges/presentation/screens/challenge_completion_screen.dart';
import 'package:flap_app/features/challenges/presentation/screens/challenge_video_player_screen.dart';
import 'package:flap_app/features/matches/data/rating_service.dart';
import 'package:flap_app/features/videos/data/thumbnail_service.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/features/videos/presentation/screens/video_upload_screen.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/widgets/video_preview_box.dart';

@RoutePage()
class ChallengeDetailsScreen extends StatefulWidget {
  const ChallengeDetailsScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  State<ChallengeDetailsScreen> createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
  static const int _videosPageSize = 5;

  bool _celebrationChecked = false;
  bool _isLoadingVideos = false;
  bool _hasMoreVideos = true;
  int _videosOffset = 0;
  final List<ChallengeSubmissionEntry> _videoEntries = <ChallengeSubmissionEntry>[];

  final Map<String, ValueNotifier<double>> _voteNotifiers = {};
  final ScrollController _modalVideosScrollController = ScrollController();

  late final DateFormat _dateFmt;

  @override
  void initState() {
    super.initState();
    _dateFmt = DateFormat.yMMMd();
    _modalVideosScrollController.addListener(_onModalVideosScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialVideosPage();
      _maybeShowWinnerCelebration();
    });
  }

  @override
  void dispose() {
    _modalVideosScrollController.removeListener(_onModalVideosScroll);
    _modalVideosScrollController.dispose();
    for (final notifier in _voteNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  List<ChallengeSubmissionEntry> get _sortedVideoEntries {
    return _videoEntries.toList()
      ..sort((a, b) {
        if (a.isCreatorVideo && !b.isCreatorVideo) return -1;
        if (!a.isCreatorVideo && b.isCreatorVideo) return 1;
        return b.averageRating.compareTo(a.averageRating);
      });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final now = DateTime.now();
    final mq = MediaQuery.of(context);
    const maxContent = 720.0;
    final screenW = mq.size.width;
    final horizontalGutter = screenW > 920 ? math.max(20.0, (screenW - maxContent) / 2) : 20.0;

    return Scaffold(
      backgroundColor: CdpColors.bgDeep,
      body: CdpMeshBackdrop(
        child: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 180) {
                _loadNextVideosPage();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: CdpColors.bgDeep.withValues(alpha: 0.88),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: CdpColors.textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    I18n.inline('Деталі', 'Details'),
                    style: const TextStyle(
                      color: CdpColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  centerTitle: true,
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: maxContent),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(horizontalGutter, 8, horizontalGutter, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeroBlock(c, now),
                            const SizedBox(height: 20),
                            _buildMetaRail(c),
                            const SizedBox(height: 20),
                            _buildOrganizerCard(c),
                            const SizedBox(height: 20),
                            _buildTimelineCard(c, now),
                            const SizedBox(height: 20),
                            _buildActionRegion(c, now),
                            const SizedBox(height: 28),
                            CdpSectionLabel(
                              title: I18n.inline('Участь та голоси', 'Entries & votes'),
                              trailing: Text(
                                '${_videoEntries.length}',
                                style: const TextStyle(
                                  color: CdpColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_videoEntries.isEmpty && _isLoadingVideos)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(color: CdpColors.primary)),
                  )
                else if (_videoEntries.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: maxContent),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalGutter),
                          child: _buildEmptySubmissions(),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalGutter,
                      0,
                      horizontalGutter,
                      mq.padding.bottom + 24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sorted = _sortedVideoEntries;
                          if (index < sorted.length) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildVideoCard(sorted[index], index + 1),
                            );
                          }
                          if (_isLoadingVideos) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(color: CdpColors.primary),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        childCount: _sortedVideoEntries.length + (_isLoadingVideos ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBlock(Challenge c, DateTime now) {
    final isEnded = c.endDate.isBefore(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.title,
          style: const TextStyle(
            color: CdpColors.textPrimary,
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusCapsule(cdpStatusHeadline(c, now), isEnded: isEnded),
            if (c.tags.isNotEmpty)
              ...c.tags.take(4).map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: CdpColors.bgElevated,
                        border: Border.all(color: CdpColors.stroke),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: CdpColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 16),
        CdpGlassCard(
          padding: const EdgeInsets.all(18),
          child: Text(
            c.description.isNotEmpty
                ? c.description
                : I18n.inline('Опис зʼявиться незабаром.', 'Description coming soon.'),
            style: const TextStyle(
              color: CdpColors.textSecondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCapsule(String label, {required bool isEnded}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isEnded ? CdpColors.stroke : CdpColors.primary.withValues(alpha: 0.45),
        ),
        color: isEnded ? CdpColors.bgElevated : CdpColors.primary.withValues(alpha: 0.1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isEnded ? CdpColors.textSecondary : CdpColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildMetaRail(Challenge c) {
    return CdpMetaRail(
      children: [
        CdpMetaPill(
          icon: Icons.bolt_rounded,
          label: c.typeText,
          emphasize: true,
        ),
        CdpMetaPill(
          icon: Icons.radar_rounded,
          label: cdpAudienceLabel(c.audience),
        ),
        if (c.city.isNotEmpty)
          CdpMetaPill(
            icon: Icons.location_on_outlined,
            label: c.city,
          ),
        CdpMetaPill(
          icon: Icons.paid_outlined,
          label: I18n.inline('Вхід ${c.entryFee}', 'Entry ${c.entryFee}'),
        ),
        CdpMetaPill(
          icon: Icons.savings_outlined,
          label: I18n.inline('Пул ${c.prizePool.toStringAsFixed(0)}', 'Pool ${c.prizePool.toStringAsFixed(0)}'),
        ),
      ],
    );
  }

  Widget _buildOrganizerCard(Challenge c) {
    return CdpGlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          FutureBuilder(
            future: context.read<UserProfileRepository>().loadProfile(c.creatorId),
            builder: (context, snapshot) {
              final prof = snapshot.data;
              final name = prof?.resolveDisplayName().isNotEmpty == true
                  ? prof!.resolveDisplayName()
                  : (c.creatorName.isNotEmpty
                      ? c.creatorName
                      : I18n.inline('Організатор', 'Organizer'));
              final avatar = prof?.avatarUrl ?? '';
              return PlayerAvatarButton(
                userId: c.creatorId,
                displayName: name,
                avatarUrl: avatar,
                size: 48,
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.inline('Куратор', 'Curator'),
                  style: const TextStyle(
                    color: CdpColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder(
                  future: context.read<UserProfileRepository>().loadProfile(c.creatorId),
                  builder: (context, snapshot) {
                    final prof = snapshot.data;
                    final name = prof?.resolveDisplayName().isNotEmpty == true
                        ? prof!.resolveDisplayName()
                        : (c.creatorName.isNotEmpty
                            ? c.creatorName
                            : I18n.inline('Організатор', 'Organizer'));
                    return Text(
                      name,
                      style: const TextStyle(
                        color: CdpColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showParticipants,
            child: Text(
              I18n.inline('Учасники', 'Roster'),
              style: const TextStyle(
                color: CdpColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Challenge c, DateTime now) {
    final entries = <CdpTimelineEntry>[
      CdpTimelineEntry(
        title: I18n.inline('Дедлайн відео', 'Video cutoff'),
        subtitle: _dateFmt.format(c.submissionDeadline.toLocal()),
        isPast: now.isAfter(c.submissionDeadline),
      ),
      CdpTimelineEntry(
        title: I18n.inline('Старт голосування', 'Voting opens'),
        subtitle: _dateFmt.format(c.votingDeadline.toLocal()),
        isPast: now.isAfter(c.votingDeadline),
      ),
      CdpTimelineEntry(
        title: I18n.inline('Фінал', 'Finale'),
        subtitle: _dateFmt.format(c.endDate.toLocal()),
        isPast: now.isAfter(c.endDate),
      ),
    ];

    return CdpGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CdpSectionLabel(title: I18n.inline('Календар', 'Timeline')),
          const SizedBox(height: 4),
          CdpTimeline(entries: entries),
        ],
      ),
    );
  }

  Widget _buildActionRegion(Challenge c, DateTime now) {
    final isFinished = c.endDate.isBefore(now);
    if (isFinished) {
      return CdpPrimaryCta(
        label: I18n.inline('Переглянути підсумки', 'View results'),
        icon: Icons.emoji_events_rounded,
        onPressed: _showResults,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CdpPrimaryCta(
          label: I18n.inline('Додати відео', 'Submit video'),
          icon: Icons.add_circle_outline_rounded,
          onPressed: _uploadVideo,
        ),
        const SizedBox(height: 12),
        CdpSecondaryCta(
          label: I18n.inline(
            'Галерея роликів (${c.submissions.length})',
            'Clip gallery (${c.submissions.length})',
          ),
          icon: Icons.grid_view_rounded,
          onPressed: _showChallengeVideos,
        ),
      ],
    );
  }

  Widget _buildEmptySubmissions() {
    return CdpGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.movie_filter_outlined,
            size: 52,
            color: CdpColors.textSecondary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            I18n.inline('Ще немає робіт', 'No entries yet'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CdpColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.inline(
              'Станьте першим, хто покаже свій стиль.',
              'Be the first to set the tone.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: CdpColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(ChallengeSubmissionEntry s, int rank) {
    final submissionUserId = s.userId;
    final title = s.title.isNotEmpty ? s.title : I18n.inline('Без назви', 'Untitled');
    final userId = s.userId;
    final videoUrl = s.videoUrl;
    final isCreatorVideo = s.isCreatorVideo;
    final rating = s.averageRating;
    final likesCount = s.voteCount;
    final thumb = s.thumbnailUrl;
    final videoDocId = s.videoId;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CdpColors.bgCard,
        border: Border.all(color: CdpColors.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CdpColors.primary,
                    CdpColors.primaryMuted.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: CdpColors.bgElevated,
                            border: Border.all(color: CdpColors.stroke),
                          ),
                          child: Text(
                            '#$rank',
                            style: const TextStyle(
                              color: CdpColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FutureBuilder(
                            future: context.read<UserProfileRepository>().loadProfile(userId),
                            builder: (context, userSnapshot) {
                              final prof = userSnapshot.data;
                              final avatarUrl = prof?.avatarUrl ?? '';
                              final userName = prof?.resolveDisplayName().isNotEmpty == true
                                  ? prof!.resolveDisplayName()
                                  : (s.authorName.isNotEmpty
                                      ? s.authorName
                                      : I18n.inline('Гравець', 'Player'));
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PlayerAvatarButton(
                                    userId: userId,
                                    displayName: userName,
                                    avatarUrl: avatarUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 10),
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
                                                    color: CdpColors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isCreatorVideo)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    color: CdpColors.primary.withValues(alpha: 0.18),
                                                    border: Border.all(
                                                      color: CdpColors.primary.withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    I18n.inline('АВТОР', 'CREATOR'),
                                                    style: const TextStyle(
                                                      color: CdpColors.primary,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.6,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            userName,
                                            style: const TextStyle(
                                              color: CdpColors.textSecondary,
                                              fontSize: 13,
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStars(rating),
                        const SizedBox(width: 8),
                        Text(
                          rating.toStringAsFixed(2),
                          style: const TextStyle(
                            color: CdpColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          I18n.inline(' · $likesCount голосів', ' · $likesCount votes'),
                          style: const TextStyle(
                            color: CdpColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<String?>(
                      future: _getThumbnailUrl(thumb, submissionUserId, videoDocId, videoUrl),
                      builder: (context, snapshot) {
                        final effectiveThumb = snapshot.data ?? thumb;
                        return _buildVotingSection(
                          submissionUserId,
                          videoUrl,
                          title,
                          authorName: s.authorName.isNotEmpty
                              ? s.authorName
                              : I18n.inline('Автор', 'Author'),
                          thumbnailUrl: effectiveThumb,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 360;
                        final actions = <Widget>[
                          _outlineMiniAction(
                            icon: Icons.play_arrow_rounded,
                            label: I18n.inline('Дивитись', 'Watch'),
                            onPressed: () => _playVideo(
                              videoUrl,
                              title,
                              submissionUserId,
                              authorName: s.authorName.isNotEmpty
                                  ? s.authorName
                                  : I18n.inline('Автор', 'Author'),
                              thumbnailUrl: thumb,
                            ),
                          ),
                          _outlineMiniAction(
                            icon: Icons.share_rounded,
                            label: I18n.t('share'),
                            onPressed: () => _shareVideo(submissionUserId),
                          ),
                          _outlineMiniAction(
                            icon: Icons.bookmark_outline_rounded,
                            label: I18n.t('save'),
                            onPressed: () => _saveVideo(submissionUserId),
                          ),
                        ];
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final w in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: w),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: actions[i]),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineMiniAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: CdpColors.textSecondary),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: CdpColors.textPrimary,
        side: const BorderSide(color: CdpColors.stroke),
        backgroundColor: CdpColors.bgElevated,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildVideosListForModal() {
    if (_videoEntries.isEmpty && _isLoadingVideos) {
      return const Center(child: CircularProgressIndicator(color: CdpColors.primary));
    }
    if (_videoEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_outlined, size: 56, color: CdpColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              I18n.inline('Поки що немає відео', 'No videos yet'),
              style: const TextStyle(color: CdpColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final sortedVideos = _videoEntries.toList()
      ..sort((a, b) {
        if (a.isCreatorVideo && !b.isCreatorVideo) return -1;
        if (!a.isCreatorVideo && b.isCreatorVideo) return 1;
        return 0;
      });

    return ListView.builder(
      controller: _modalVideosScrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: sortedVideos.length + (_isLoadingVideos ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= sortedVideos.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: CdpColors.primary)),
          );
        }
        return _buildModalVideoCard(sortedVideos[index]);
      },
    );
  }

  Widget _buildModalVideoCard(ChallengeSubmissionEntry s) {
    final submissionUserId = s.userId;
    final title = s.title.isNotEmpty ? s.title : I18n.inline('Без назви', 'Untitled');
    final userId = s.userId;
    final videoUrl = s.videoUrl;
    final isCreatorVideo = s.isCreatorVideo;
    final rating = s.averageRating;
    final likesCount = s.voteCount;
    var thumb = s.thumbnailUrl;
    final videoDocId = s.videoId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String?>(
            future: _getThumbnailUrl(thumb, submissionUserId, videoDocId, videoUrl),
            builder: (context, snapshot) {
              final effectiveThumb = snapshot.data ?? thumb;
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: VideoPreviewBox(
                  videoUrl: videoUrl,
                  thumbnailUrl: effectiveThumb,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChallengeVideoPlayerScreen(
                          videoUrl: videoUrl,
                          title: title,
                          authorName: s.authorName.isNotEmpty
                              ? s.authorName
                              : I18n.inline('Автор', 'Author'),
                          challengeId: widget.challenge.id,
                          submissionId: submissionUserId,
                          thumbnailUrl: effectiveThumb,
                        ),
                      ),
                    );
                  },
                  borderRadius: 0,
                  topLeft: isCreatorVideo
                      ? _badge(
                          I18n.inline('Автор', 'Creator'),
                          fg: CdpColors.textPrimary,
                        )
                      : null,
                  bottomRight: _badge(
                    I18n.inline('${rating.toStringAsFixed(1)} ★', '${rating.toStringAsFixed(1)} ★'),
                    bg: CdpColors.bgDeep.withValues(alpha: 0.75),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder(
                future: context.read<UserProfileRepository>().loadProfile(userId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const CircleAvatar(
                      radius: 22,
                      backgroundColor: CdpColors.bgElevated,
                      child: Icon(Icons.person_rounded, color: CdpColors.textSecondary, size: 22),
                    );
                  }

                  final prof = userSnapshot.data;
                  final avatarUrl = prof?.avatarUrl ?? '';
                  final userName = prof?.resolveDisplayName().isNotEmpty == true
                      ? prof!.resolveDisplayName()
                      : (s.authorName.isNotEmpty ? s.authorName : I18n.inline('Гравець', 'Player'));

                  return PlayerAvatarButton(
                    userId: userId,
                    displayName: userName,
                    avatarUrl: avatarUrl,
                    size: 44,
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
                              color: CdpColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCreatorVideo)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CdpColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: CdpColors.primary.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              I18n.inline('АВТОР', 'CREATOR'),
                              style: const TextStyle(
                                color: CdpColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStars(rating),
                        const SizedBox(width: 8),
                        Text(
                          rating.toStringAsFixed(2),
                          style: const TextStyle(
                            color: CdpColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          I18n.inline(' ($likesCount)', ' ($likesCount)'),
                          style: const TextStyle(
                            color: CdpColors.textSecondary,
                            fontSize: 12,
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

  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star_rounded, color: CdpColors.primary, size: 17);
        } else if (index < rating) {
          return const Icon(Icons.star_half_rounded, color: CdpColors.primary, size: 17);
        } else {
          return Icon(Icons.star_outline_rounded, color: CdpColors.textSecondary.withValues(alpha: 0.35), size: 17);
        }
      }),
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
      // ignore: avoid_print
      print('Failed to show celebration: $e');
    }
  }

  void _showParticipants() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return CdpSheetChrome(
              title: I18n.inline(
                'Учасники (${widget.challenge.participants.length})',
                'Participants (${widget.challenge.participants.length})',
              ),
              onClose: () => Navigator.pop(context),
              child: widget.challenge.participants.isEmpty
                  ? Center(
                      child: Text(
                        I18n.inline('Поки немає учасників', 'No participants yet'),
                        style: const TextStyle(color: CdpColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: widget.challenge.participants.length,
                      itemBuilder: (context, index) {
                        final participantId = widget.challenge.participants[index];
                        return FutureBuilder(
                          future: context.read<UserProfileRepository>().loadProfile(participantId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: CdpColors.bgElevated,
                                  child: Icon(Icons.person_rounded, color: CdpColors.textSecondary),
                                ),
                                title: Text(
                                  I18n.inline('Завантаження…', 'Loading…'),
                                  style: const TextStyle(color: CdpColors.textSecondary),
                                ),
                              );
                            }

                            final prof = snapshot.data;
                            final userName = prof?.resolveDisplayName().isNotEmpty == true
                                ? prof!.resolveDisplayName()
                                : I18n.inline('Гравець', 'Player');
                            final avatarUrl = prof?.avatarUrl ?? '';
                            final rating = prof?.rating ?? 0.0;
                            final city = prof?.city?.isNotEmpty == true
                                ? prof!.city!
                                : I18n.inline('Місто невідоме', 'Unknown city');

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: CdpColors.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        PlayerAvatarButton(
                                          userId: participantId,
                                          displayName: userName,
                                          avatarUrl: avatarUrl,
                                          size: 44,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                userName,
                                                style: const TextStyle(
                                                  color: CdpColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                city,
                                                style: const TextStyle(
                                                  color: CdpColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star_rounded, color: CdpColors.primary, size: 15),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    rating.toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      color: CdpColors.primary,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (participantId == widget.challenge.creatorId)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: CdpColors.primary.withValues(alpha: 0.4)),
                                              color: CdpColors.primary.withValues(alpha: 0.12),
                                            ),
                                            child: Text(
                                              I18n.inline('Куратор', 'Curator'),
                                              style: const TextStyle(
                                                color: CdpColors.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: CdpColors.textSecondary,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildVotingSection(
    String submissionUserId,
    String videoUrl,
    String title, {
    required String authorName,
    String? thumbnailUrl,
  }) {
    return StreamBuilder<Map<String, double>>(
      stream: context.read<ChallengeRepository>().watchMyVotes(widget.challenge.id),
      builder: (context, voteSnapshot) {
        final myVotes = voteSnapshot.data ?? {};
        final existingVote = myVotes[submissionUserId];
        final hasVoted = existingVote != null;
        final currentVote = (_voteNotifiers[submissionUserId]?.value) ?? 0.0;

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
            color: CdpColors.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CdpColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              authorName: authorName,
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
                    ? _badge(
                        I18n.inline('Ваш голос', 'Your vote'),
                        fg: CdpColors.textPrimary,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                I18n.inline('Оцінка', 'Score'),
                style: const TextStyle(
                  color: CdpColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _voteNotifiers[submissionUserId]!,
                      builder: (context, value, _) => SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                        ),
                        child: Slider(
                          value: value,
                          min: 0.0,
                          max: 5.0,
                          activeColor: CdpColors.primary,
                          inactiveColor: CdpColors.textSecondary.withValues(alpha: 0.2),
                          onChanged: hasVoted
                              ? null
                              : (v) {
                                  _voteNotifiers[submissionUserId]!.value = v;
                                },
                          onChangeEnd: hasVoted
                              ? null
                              : (v) {
                                  final rounded = (v * 100).round() / 100;
                                  _voteNotifiers[submissionUserId]!.value = rounded;
                                },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _voteNotifiers[submissionUserId]!,
                      builder: (context, v, _) => Text(
                        v.toStringAsFixed(2),
                        style: const TextStyle(
                          color: CdpColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: hasVoted
                        ? null
                        : () => _submitVote(
                              submissionUserId,
                              _voteNotifiers[submissionUserId]!.value,
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: CdpColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: CdpColors.textSecondary.withValues(alpha: 0.25),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      hasVoted ? I18n.inline('Зафіксовано', 'Locked in') : I18n.inline('Надіслати', 'Submit'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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

  Widget _badge(String label, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? CdpColors.primary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg ?? Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
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
          content: Text(I18n.inline('Не можна голосувати за себе', 'You cannot vote for yourself')),
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
          content: Text(
            I18n.inline(
              'Оцінка ${rating.toStringAsFixed(1)} збережено',
              'Saved rating ${rating.toStringAsFixed(1)}',
            ),
          ),
          backgroundColor: CdpColors.primary,
        ),
      );
    } on ChallengeFailure catch (f) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(f.message ?? I18n.inline('Помилка', 'Something went wrong')),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка збереження', 'Could not save')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _playVideo(
    String videoUrl,
    String title,
    String submissionUserId, {
    required String authorName,
    String? thumbnailUrl,
  }) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Відео недоступне', 'Video unavailable'))),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeVideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
          authorName: authorName,
          challengeId: widget.challenge.id,
          submissionId: submissionUserId,
          thumbnailUrl: thumbnailUrl,
        ),
      ),
    );
  }

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
        // ignore: avoid_print
        print('Thumbnail from video doc: $e');
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
        // ignore: avoid_print
        print('Thumbnail generation: $e');
      }
    }

    return null;
  }

  void _shareVideo(String videoId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Посилання скопійовано', 'Link copied'))),
    );
  }

  void _saveVideo(String videoId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Збережено', 'Saved'))),
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
      setState(() {});
    });
  }

  void _showChallengeVideos() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: CdpSheetChrome(
          title: widget.challenge.title,
          onClose: () => Navigator.pop(context),
          child: _buildVideosListForModal(),
        ),
      ),
    );
  }

  void _onModalVideosScroll() {
    if (!_modalVideosScrollController.hasClients) return;
    final pos = _modalVideosScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 180) {
      _loadNextVideosPage();
    }
  }

  Future<void> _loadInitialVideosPage() async {
    _videoEntries.clear();
    _videosOffset = 0;
    _hasMoreVideos = true;
    await _loadNextVideosPage();
  }

  Future<void> _loadNextVideosPage() async {
    if (_isLoadingVideos || !_hasMoreVideos) return;
    if (!mounted) return;
    setState(() => _isLoadingVideos = true);
    try {
      final page = await context.read<ChallengeRepository>().getSubmissionsPage(
            widget.challenge.id,
            limit: _videosPageSize,
            offset: _videosOffset,
          );
      if (!mounted) return;
      setState(() {
        _videoEntries.addAll(page);
        _videosOffset += page.length;
        _hasMoreVideos = page.length == _videosPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasMoreVideos = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingVideos = false);
      }
    }
  }
}
