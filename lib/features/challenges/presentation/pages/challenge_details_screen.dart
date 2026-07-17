import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/interactions/interaction_store.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
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

  @override
  void initState() {
    super.initState();
    // Seed the cubit with the snapshot we already have from the card so the
    // header is never blank for a frame; `load()` overwrites it with the
    // database values as soon as the queries return.
    _detailsCubit = ChallengeDetailsCubit(
      widget.challenge.id,
      challengeCreatorId: widget.challenge.creatorId,
      initialEntryFee: widget.challenge.entryFee,
      initialParticipantCount: widget.challenge.participants.length,
      initialSubmissionCount: widget.challenge.submissions.length,
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
        backgroundColor: FlapColors.bg,
        appBar: AppBar(
          backgroundColor: FlapColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leadingWidth: 60,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _glassIconButton(
                  Icons.chevron_left, () => Navigator.pop(context)),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _glassIconButton(Icons.ios_share, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('il_28a4a65f94'))),
                );
              }, size: 18),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailHero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatPills(),
                    const SizedBox(height: 22),
                    _buildContentSection(context),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildActionDock(),
      ),
    );
  }

  // ----------------------------------------------------------- hero + stages

  Widget _glassIconButton(IconData icon, VoidCallback onTap, {double size = 19}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: FlapColors.border),
        ),
        child: Icon(icon, color: FlapColors.text, size: size),
      ),
    );
  }

  String _stageLabel(ChallengeStatus s) {
    switch (s) {
      case ChallengeStatus.recruiting:
        return tr('challenge_stage_recruiting');
      case ChallengeStatus.submission:
        return tr('challenge_stage_submission');
      case ChallengeStatus.voting:
        return tr('challenge_stage_voting');
      case ChallengeStatus.completed:
        return tr('challenge_stage_completed');
    }
  }

  Color _stageColor(ChallengeStatus s) {
    switch (s) {
      case ChallengeStatus.recruiting:
        return FlapColors.blue;
      case ChallengeStatus.submission:
        return FlapColors.amber;
      case ChallengeStatus.voting:
        return FlapColors.greenBright;
      case ChallengeStatus.completed:
        return FlapColors.muted;
    }
  }

  Widget _buildDetailHero() {
    final status = widget.challenge.status;
    final accent = _stageColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlapColors.green.withValues(alpha: 0.16),
            FlapColors.card2,
          ],
          stops: const [0.0, 0.55],
        ),
        border: const Border(bottom: BorderSide(color: FlapColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, size: 13, color: accent),
                const SizedBox(width: 6),
                Text(
                  _stageLabel(status),
                  style: FlapText.sora(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.challenge.title.toUpperCase(),
            style: FlapText.cond(fontSize: 30, fontWeight: FontWeight.w700)
                .copyWith(height: 0.98),
          ),
          if (widget.challenge.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.challenge.description,
              style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted)
                  .copyWith(height: 1.5),
            ),
          ],
          if ((widget.challenge.creatorVideoUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCreatorVideo(),
          ],
          _buildStageTimeline(status.index),
        ],
      ),
    );
  }

  /// The creator's reference clip — the "main" challenge video that defines
  /// the task. Tapping opens it in the standard immersive player (no voting).
  Widget _buildCreatorVideo() {
    return VideoPreviewBox(
      videoUrl: widget.challenge.creatorVideoUrl,
      thumbnailUrl: widget.challenge.imageUrl,
      aspectRatio: 16 / 9,
      borderRadius: 16,
      showPlayIcon: true,
      placeholderColor: const Color(0xFF0D1A15),
      onTap: _openCreatorVideo,
      bottomLeft: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill,
                size: 13, color: FlapColors.greenBright),
            const SizedBox(width: 5),
            Text(
              tr('challenge_creator_video'),
              style: FlapText.sora(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreatorVideo() {
    final url = widget.challenge.creatorVideoUrl ?? '';
    if (url.isEmpty) return;
    context.router.push(
      VideoPlayerRoute(
        videoUrl: url,
        title: widget.challenge.title,
        authorName: widget.challenge.creatorName,
        videoId: '',
      ),
    );
  }

  Widget _buildStageTimeline(int current) {
    final labels = [
      tr('challenge_stage_recruiting'),
      tr('challenge_stage_submission'),
      tr('challenge_stage_voting'),
      tr('challenge_stage_completed'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 18, left: 4, right: 4),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final span = w * 0.75;
          final prog = span * (current / 3).clamp(0.0, 1.0);
          return SizedBox(
            height: 46,
            child: Stack(
              children: [
                Positioned(
                  left: w * 0.125,
                  top: 6,
                  child: Container(
                      width: span,
                      height: 2,
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                Positioned(
                  left: w * 0.125,
                  top: 6,
                  child: Container(
                    width: prog,
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        FlapColors.green,
                        FlapColors.greenBright,
                      ]),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(4, (i) {
                    final done = i < current;
                    final cur = i == current;
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? FlapColors.green
                                  : cur
                                      ? FlapColors.greenBright
                                      : FlapColors.bg,
                              border: Border.all(
                                color: done || cur
                                    ? (cur
                                        ? FlapColors.greenBright
                                        : FlapColors.green)
                                    : Colors.white.withValues(alpha: 0.2),
                                width: 2,
                              ),
                              boxShadow: cur
                                  ? [
                                      BoxShadow(
                                        color: FlapColors.green
                                            .withValues(alpha: 0.22),
                                        blurRadius: 0,
                                        spreadRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            style: FlapText.sora(
                              fontSize: 10,
                              fontWeight:
                                  cur ? FontWeight.w700 : FontWeight.w500,
                              color: cur
                                  ? FlapColors.greenBright
                                  : done
                                      ? FlapColors.text
                                      : FlapColors.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatPills() {
    return BlocBuilder<ChallengeDetailsCubit, ChallengeDetailsState>(
      buildWhen: (prev, next) =>
          prev.participantCount != next.participantCount ||
          prev.submissionCount != next.submissionCount ||
          prev.prizePool != next.prizePool,
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: _statPill(
                value: '${state.prizePool}',
                label: tr('challenge_prize_pool'),
                valueColor: FlapColors.gold,
                icon: Icons.monetization_on,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statPill(
                value: '${widget.challenge.entryFee} FL',
                label: tr('challenge_entry_fee'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _showParticipants,
                child: _statPill(
                  value: '${state.participantCount}',
                  label: tr('challenge_players'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statPill({
    required String value,
    required String label,
    Color? valueColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: valueColor ?? FlapColors.text),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.cond(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? FlapColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.muted)
                .copyWith(letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------- body content section

  /// Recruiting / submission stages show "How it works"; voting / completed
  /// stages show the submissions grid (design parity).
  Widget _buildContentSection(BuildContext context) {
    final status = widget.challenge.status;
    final showsSubmissions = status == ChallengeStatus.voting ||
        status == ChallengeStatus.completed;
    if (!showsSubmissions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('challenge_how_it_works'),
            style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _buildHowItWorks(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == ChallengeStatus.completed) ...[
          _buildResultsButton(),
          const SizedBox(height: 22),
        ],
        _buildSubmissionsHeader(),
        const SizedBox(height: 14),
        _buildVideosList(context),
      ],
    );
  }

  Widget _buildHowItWorks() {
    final fee = '${widget.challenge.entryFee}';
    final prize = widget.challenge.prizePool > 0
        ? '${widget.challenge.prizePool.toInt()}'
        : tr('challenge_prize_tbd');
    return Column(
      children: [
        _inforow(Icons.group_rounded, tr('challenge_hiw_recruit_t'),
            tr('challenge_hiw_recruit_b', namedArgs: {'fee': fee})),
        _inforow(Icons.bolt_rounded, tr('challenge_hiw_submit_t'),
            tr('challenge_hiw_submit_b')),
        _inforow(Icons.star_rounded, tr('challenge_hiw_vote_t'),
            tr('challenge_hiw_vote_b')),
        _inforow(Icons.emoji_events_rounded, tr('challenge_hiw_win_t'),
            tr('challenge_hiw_win_b', namedArgs: {'prize': prize}), last: true),
      ],
    );
  }

  Widget _inforow(IconData icon, String title, String body,
      {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: FlapColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FlapColors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: FlapColors.border),
            ),
            child: Icon(icon, size: 18, color: FlapColors.greenBright),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FlapText.sora(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: FlapText.sora(fontSize: 12, color: FlapColors.muted)
                      .copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosList(BuildContext context) {
    return BlocBuilder<ChallengeDetailsCubit, ChallengeDetailsState>(
      builder: (context, state) {
        if (state.isLoading && state.submissions.isEmpty) {
          return const FlapLoadingGrid(
            itemCount: 4,
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            padding: EdgeInsets.all(16),
            radius: 16,
          );
        }

        if (state.error != null && state.submissions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              state.error!,
              style: const TextStyle(color: FlapColors.red),
            ),
          );
        }

        if (state.submissions.isEmpty) {
          return _submissionEmptyState();
        }

        // Client-side sort: creator video first, then by rating.
        final sortedVideos = state.submissions.toList()
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
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: sortedVideos.length,
          itemBuilder: (context, index) {
            final row = sortedVideos[index];
            return _buildSubmissionCard(
              row,
              rank: index + 1,
              submitterProfilesByUserId: submitterProfiles,
              myRatingRow: myRatings[row['id']?.toString() ?? ''],
            );
          },
        );
      },
    );
  }

  Widget _submissionEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.video_library_outlined,
              size: 44, color: FlapColors.muted2),
          const SizedBox(height: 12),
          Text(
            tr('challenge_no_submissions'),
            style: FlapText.sora(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            tr('challenge_no_submissions_sub'),
            textAlign: TextAlign.center,
            style: FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- submission card

  Widget _buildSubmissionCard(
    Map<String, dynamic> data, {
    required int rank,
    required Map<String, Map<String, dynamic>> submitterProfilesByUserId,
    Map<String, dynamic>? myRatingRow,
  }) {
    final videoId = data['id']?.toString() ?? '';
    final userId = data['userId'] ?? '';
    final videoUrl = data['videoUrl'] ?? '';
    final isCreatorVideo = data['isCreatorVideo'] ?? false;
    final rating = (data['averageRating'] ?? 0.0).toDouble();
    final thumb = (data['thumbnailUrl'] ?? '') as String;
    final userData = submitterProfilesByUserId[userId] ?? <String, dynamic>{};
    final userName = _profileDisplayName(userData);
    final firstName = userName.split(' ').first;
    final hasVoted = myRatingRow != null;

    const rankColors = [
      Color(0xFFE7C25A),
      Color(0xFFC0C0C0),
      Color(0xFFCD7F32),
    ];
    final rankBg =
        rank <= 3 ? rankColors[rank - 1] : Colors.white.withValues(alpha: 0.14);
    final rankFg =
        rank <= 3 ? const Color(0xFF06140A) : const Color(0xFFCDD4CE);

    final title = data['title'] ?? tr('il_f59ab8d133');
    // Same as the videos flow: tapping a submission opens the immersive
    // player; rating happens on the player's "Rate" rail.
    void open() => _openChallengeVideoPlayer(
          videoUrl: videoUrl,
          title: title,
          submissionId: videoId,
          authorName: userName,
          thumbnailUrl: thumb,
        );

    return GestureDetector(
      onTap: open,
      child: Container(
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCreatorVideo
                ? FlapColors.green.withValues(alpha: 0.4)
                : FlapColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<String?>(
                    future: _getThumbnailUrl(thumb, videoId, videoUrl, userId),
                    builder: (context, snap) {
                      final eff = snap.data ?? thumb;
                      return VideoPreviewBox(
                        videoUrl: videoUrl,
                        thumbnailUrl: eff,
                        aspectRatio: 1,
                        borderRadius: 0,
                        showPlayIcon: false,
                        onTap: open,
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rankBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rank',
                        style: FlapText.cond(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: rankFg),
                      ),
                    ),
                  ),
                  if (hasVoted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: FlapColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 12, color: FlapColors.onGreen),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlapText.sora(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  // Reactive: avg rating + voted state come from the shared
                  // store so a vote anywhere updates this card instantly.
                  ValueListenableBuilder<ContentInteraction>(
                    valueListenable:
                        sl<InteractionStore>().watchSubmission(videoId),
                    builder: (context, ci, _) {
                      final displayRating =
                          ci.loaded ? ci.ratingAvg : rating;
                      final displayVoted = ci.loaded ? ci.votedByMe : hasVoted;
                      return Row(
                        children: [
                          const Icon(Icons.star,
                              size: 12, color: FlapColors.gold),
                          const SizedBox(width: 4),
                          Text(
                            displayRating > 0
                                ? displayRating.toStringAsFixed(2)
                                : '—',
                            style: FlapText.sora(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: FlapColors.gold),
                          ),
                          if (displayVoted) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '· ${tr('challenge_voted')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FlapText.sora(
                                    fontSize: 11,
                                    color: FlapColors.greenBright),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetGrip() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _sheetCloseButton(BuildContext ctx) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: FlapColors.border),
        ),
        child: const Icon(Icons.close, size: 18, color: FlapColors.text),
      ),
    );
  }

  // Show participants list
  Widget _buildSubmissionsHeader() {
    return BlocBuilder<ChallengeDetailsCubit, ChallengeDetailsState>(
      buildWhen: (prev, next) =>
          prev.submissionCount != next.submissionCount,
      builder: (context, state) {
        return Row(
          children: [
            Text(
              tr('challenge_submissions'),
              style: FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              tr('challenge_entries_count',
                  namedArgs: {'count': '${state.submissionCount}'}),
              style: FlapText.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FlapColors.muted),
            ),
          ],
        );
      },
    );
  }

  /// Bottom dock drives the primary action while a challenge is live (upload).
  /// Completed challenges have no bottom action — results live inline in the
  /// content section instead — so the dock is omitted.
  Widget? _buildActionDock() {
    if (widget.challenge.status == ChallengeStatus.completed) return null;

    // Reactive to the cubit so the dock disappears the moment the current
    // user's submission lands (and stays hidden when they've already entered).
    return BlocBuilder<ChallengeDetailsCubit, ChallengeDetailsState>(
      builder: (context, state) {
        final myId = AppAuth.currentUserId ?? '';
        final alreadySubmitted = myId.isNotEmpty &&
            state.submissions.any(
              (s) => (s['userId'] ?? '').toString() == myId,
            );
        // Once entered, replace the upload CTA with a confirmation message.
        if (alreadySubmitted) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: FlapColors.bg,
              border: Border(top: BorderSide(color: FlapColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: FlapColors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: FlapColors.green.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: FlapColors.greenBright, size: 19),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr('challenge_error_already_submitted_video'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: FlapColors.greenBright),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: FlapColors.bg,
            border: Border(top: BorderSide(color: FlapColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: GestureDetector(
              onTap: _uploadVideo,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: FlapColors.primaryButton,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr('il_b0237f6faf'),
                      style: FlapText.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: FlapColors.onGreen),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: FlapColors.onGreen, size: 19),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Full-width primary button (new gradient style) that opens the results
  /// sheet. Shown inline for completed challenges, above the submissions grid.
  Widget _buildResultsButton() {
    return GestureDetector(
      onTap: _showResults,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlapColors.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlapColors.green.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: FlapColors.greenBright, size: 19),
            const SizedBox(width: 8),
            Text(
              tr('il_82389e3a90'),
              style: FlapText.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FlapColors.greenBright),
            ),
          ],
        ),
      ),
    );
  }

  void _showResults() {
    _showResultsSheet();
  }

  /// Final ranking + prizes shown as a bottom sheet (no full-page nav).
  /// Submissions come from the live cubit; prize amounts from
  /// `challenge_prize_places`, falling back to a 50/30/20 pool split.
  void _showResultsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return BlocProvider.value(
          value: _detailsCubit,
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (sheetCtx, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: FlapColors.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(top: BorderSide(color: FlapColors.borderStrong)),
                ),
                child: Column(
                  children: [
                    _sheetGrip(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('challenge_results'),
                                  style: FlapText.sora(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.challenge.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FlapText.sora(
                                      fontSize: 12.5,
                                      color: FlapColors.muted),
                                ),
                              ],
                            ),
                          ),
                          _sheetCloseButton(sheetCtx),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<Map<String, double>>(
                        future: _loadPrizeByUser(),
                        builder: (context, prizeSnap) {
                          final prizeByUser = prizeSnap.data ?? const {};
                          return BlocBuilder<ChallengeDetailsCubit,
                              ChallengeDetailsState>(
                            builder: (context, state) {
                              final ranked =
                                  List<Map<String, dynamic>>.from(
                                      state.submissions)
                                    ..sort((a, b) =>
                                        ((b['averageRating'] as num?) ?? 0)
                                            .compareTo((a['averageRating']
                                                    as num?) ??
                                                0));
                              if (state.isLoading && ranked.isEmpty) {
                                return const FlapLoadingGrid(
                                  itemCount: 4,
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.72,
                                  padding: EdgeInsets.all(16),
                                  radius: 16,
                                );
                              }
                              if (ranked.isEmpty) {
                                return _resultsEmpty();
                              }
                              return ListView.separated(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(20, 6, 20, 28),
                                itemCount: ranked.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  return _resultRow(
                                    sheetCtx,
                                    rank: index + 1,
                                    submission: ranked[index],
                                    state: state,
                                    prizeByUser: prizeByUser,
                                  );
                                },
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
          ),
        );
      },
    );
  }

  /// Prize amount keyed by winner user id. Falls back to an empty map so the
  /// row builder can apply the pool-split default.
  Future<Map<String, double>> _loadPrizeByUser() async {
    try {
      final rows = await _sb
          .from('challenge_prize_places')
          .select('prize_amount, winner_user_id')
          .eq('challenge_id', widget.challenge.id);
      final out = <String, double>{};
      for (final raw in (rows as List<dynamic>)) {
        final p = raw as Map<String, dynamic>;
        final uid = (p['winner_user_id'] ?? '').toString();
        if (uid.isEmpty) continue;
        out[uid] = ((p['prize_amount'] as num?) ?? 0).toDouble();
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Widget _resultsEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 44, color: FlapColors.muted2),
          const SizedBox(height: 12),
          Text(
            tr('no_winners'),
            style: FlapText.sora(fontSize: 14, color: FlapColors.muted),
          ),
        ],
      ),
    );
  }

  /// One ranked leaderboard entry. Top three get medal-tinted badges; #1
  /// gets a slightly emphasized card.
  Widget _resultRow(
    BuildContext sheetCtx, {
    required int rank,
    required Map<String, dynamic> submission,
    required ChallengeDetailsState state,
    required Map<String, double> prizeByUser,
  }) {
    final userId = (submission['userId'] ?? '').toString();
    final profile = state.submitterProfilesByUserId[userId] ?? const {};
    final name = _profileDisplayName(profile);
    final avatar = _profileAvatarUrl(profile);
    final rating = ((submission['averageRating'] as num?) ?? 0).toDouble();
    final voteCount = ((submission['voteCount'] as num?) ?? 0).toInt();

    final (Color medalBg, Color medalFg) = switch (rank) {
      1 => (FlapColors.gold, FlapColors.onGreen),
      2 => (const Color(0xFFC7CDD2), FlapColors.onGreen),
      3 => (const Color(0xFFCD7F32), Colors.white),
      _ => (FlapColors.surface2, FlapColors.muted),
    };

    final prize = prizeByUser[userId] ?? 0.0;
    final isTop = rank == 1;

    return GestureDetector(
      onTap: () {
        if (userId.isEmpty) return;
        Navigator.pop(sheetCtx);
        context.router.push(
          PlayerProfileRoute(playerId: userId, playerName: name),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isTop
              ? FlapColors.gold.withValues(alpha: 0.08)
              : FlapColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTop
                ? FlapColors.gold.withValues(alpha: 0.35)
                : FlapColors.border,
          ),
        ),
        child: Row(
          children: [
            // Rank / medal badge.
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: medalBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: rank <= 3
                  ? Icon(Icons.emoji_events, size: 16, color: medalFg)
                  : Text(
                      '$rank',
                      style: FlapText.cond(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: medalFg),
                    ),
            ),
            const SizedBox(width: 12),
            PlayerAvatarButton(
              userId: userId,
              displayName: name,
              avatarUrl: avatar,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlapText.sora(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: FlapColors.gold),
                      const SizedBox(width: 3),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(2) : '—',
                        style: FlapText.sora(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FlapColors.gold),
                      ),
                      Text('  ·  ',
                          style: FlapText.sora(
                              fontSize: 12, color: FlapColors.muted2)),
                      Text(
                        tr('challenge_votes_count',
                            namedArgs: {'count': '$voteCount'}),
                        style: FlapText.sora(
                            fontSize: 12, color: FlapColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (prize > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: FlapColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on,
                        size: 14, color: FlapColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      prize.toStringAsFixed(0),
                      style: FlapText.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FlapColors.gold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
      _showResultsSheet();
    } catch (e) {
      print('Failed to show celebration: $e');
    }
  }

  void _showParticipants() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        // Pipe the existing cubit into the modal so the participants
        // sheet stays live as new joiners arrive while it is open.
        return BlocProvider.value(
          value: _detailsCubit,
          child: Container(
            height: MediaQuery.of(modalContext).size.height * 0.7,
            decoration: const BoxDecoration(
              color: FlapColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(top: BorderSide(color: FlapColors.borderStrong)),
            ),
            child: BlocBuilder<ChallengeDetailsCubit, ChallengeDetailsState>(
              buildWhen: (prev, next) =>
                  prev.participantIds.length != next.participantIds.length ||
                  prev.participantCount != next.participantCount,
              builder: (context, state) {
                final ids = state.participantIds;
                return Column(
                  children: [
                    _sheetGrip(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr(
                                'challenge_participants_title',
                                namedArgs: {'count': '${state.participantCount}'},
                              ),
                              style: FlapText.sora(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                          _sheetCloseButton(modalContext),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ids.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.people_outline,
                                      size: 56, color: FlapColors.muted2),
                                  const SizedBox(height: 14),
                                  Text(
                                    tr('il_e051442724'),
                                    style: FlapText.sora(
                                        fontSize: 14, color: FlapColors.muted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: ids.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) =>
                                  _participantRow(ids[index], modalContext),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _participantRow(String participantId, BuildContext modalContext) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sb
          .from('profiles')
          .select('display_name,email,avatar_url,overall_rating,city')
          .eq('id', participantId)
          .maybeSingle(),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? <String, dynamic>{};
        final userName = snapshot.connectionState == ConnectionState.waiting
            ? tr('il_47d2a515ef')
            : _profileDisplayName(userData);
        final avatarUrl = _profileAvatarUrl(userData);
        final r = userData['overall_rating'] ?? userData['rating'] ?? 0.0;
        final rating =
            (r is num) ? r.toDouble() : (double.tryParse(r.toString()) ?? 0.0);
        final city = localizeCity((userData['city'] ?? '').toString());
        final isCreator = participantId == widget.challenge.creatorId;

        return GestureDetector(
          onTap: () {
            Navigator.pop(modalContext);
            context.router.push(
              PlayerProfileRoute(
                playerId: participantId,
                playerName: userName,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FlapColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlapColors.border),
            ),
            child: Row(
              children: [
                PlayerAvatarButton(
                  userId: participantId,
                  displayName: userName,
                  avatarUrl: avatarUrl,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (city.isNotEmpty) ...[
                            Text(
                              city,
                              style: FlapText.sora(
                                  fontSize: 12, color: FlapColors.muted),
                            ),
                            Text('  ·  ',
                                style: FlapText.sora(
                                    fontSize: 12, color: FlapColors.muted2)),
                          ],
                          const Icon(Icons.star,
                              size: 13, color: FlapColors.gold),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(2),
                            style: FlapText.sora(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FlapColors.gold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isCreator)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlapColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tr('il_88447b8309'),
                      style: FlapText.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: FlapColors.greenBright),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right,
                      color: FlapColors.muted2, size: 20),
              ],
            ),
          ),
        );
      },
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
      // Refresh aggregates / my-vote state after returning from the player.
      if (mounted) await _detailsCubit.refresh();
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

  @override
  void dispose() {
    _detailsCubit.close();
    super.dispose();
  }
}
