import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/interactions/interaction_store.dart';
import '../../../profile/data/services/user_settings_service.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import '../../../../core/supabase/coin_ledger.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../router/app_router.dart';

@RoutePage()
class ChallengeVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String authorName;
  final String challengeId;
  final String submissionId;
  final String? thumbnailUrl;

  const ChallengeVideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.challengeId,
    required this.submissionId,
    this.thumbnailUrl,
  }) : super(key: key);

  @override
  _ChallengeVideoPlayerScreenState createState() => _ChallengeVideoPlayerScreenState();
}

class _ChallengeVideoPlayerScreenState extends State<ChallengeVideoPlayerScreen>
    with AutoRouteAwareStateMixin<ChallengeVideoPlayerScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  late VideoPlayerController _videoPlayerController;
  bool _isLoading = true;
  String? _error;
  // The controller is `late`; this guards RouteAware callbacks that may fire
  // before initialization completes (or after it fails).
  bool _videoReady = false;
  // Whether playback was active when a new screen was pushed over this one, so
  // we know to resume on return rather than start a video the user had paused.
  bool _resumeAfterReturn = false;
  // Tracks a deliberate user pause. The center play affordance is gated on this
  // (not the raw isPlaying) so the brief non-playing frame at a loop boundary
  // never flashes the play icon.
  bool _userPaused = false;
  
  // Challenge video vote (0.00–5.00, step 0.01) — single slider
  double _rating = 2.50;
  bool _hasVoted = false;
  bool _isVoting = false;
  double? _submissionAverageRating;
  String? _submissionAuthorId;
  String? _submissionAuthorName;
  String? _submissionAuthorAvatar;
  bool _autoplayVideos = true;
  // Voting is only permitted while the parent challenge is in its voting phase.
  bool _isVotingOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkIfVoted();
    _loadSubmissionAggregate();
    _loadChallengeStatus();
  }

  Future<void> _loadChallengeStatus() async {
    try {
      final row = await _sb
          .from('challenges')
          .select('status')
          .eq('id', widget.challengeId)
          .maybeSingle();
      final status = row?['status']?.toString() ?? '';
      if (mounted) setState(() => _isVotingOpen = status == 'voting');
    } catch (_) {}
  }

  Future<void> _initializeVideo() async {
    try {
      _autoplayVideos =
          (await sl<UserSettingsService>().getSettings()).autoplayVideos;
      // When autoplay is off the video starts paused, so the play affordance
      // should be visible immediately.
      _userPaused = !_autoplayVideos;
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController.initialize();
      await _videoPlayerController.setLooping(true);
      _videoPlayerController.addListener(_loopWatcher);
      if (_autoplayVideos) {
        _videoPlayerController.play();
      }
      _videoReady = true;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Belt-and-suspenders auto-restart in addition to setLooping(true). Skips
  // restarting when the user deliberately paused so it doesn't fight them.
  void _loopWatcher() {
    if (!mounted) return;
    final v = _videoPlayerController.value;
    if (v.isInitialized &&
        !v.isPlaying &&
        !_userPaused &&
        v.duration > Duration.zero &&
        v.position >= v.duration) {
      _videoPlayerController.seekTo(Duration.zero);
      _videoPlayerController.play();
    }
  }

  /// A new screen was pushed over this one — pause so the video doesn't keep
  /// playing in the background. Remember it was playing so we can resume.
  @override
  void didPushNext() {
    if (!_videoReady) return;
    if (_videoPlayerController.value.isPlaying) {
      _resumeAfterReturn = true;
      _videoPlayerController.pause();
    }
  }

  /// Returned to this screen — resume from the position where we paused.
  @override
  void didPopNext() {
    if (!_videoReady) return;
    if (_resumeAfterReturn) {
      _resumeAfterReturn = false;
      _videoPlayerController.play();
    }
  }

  Future<void> _loadSubmissionAggregate() async {
    try {
      final data = await _sb
          .from('challenge_submissions')
          .select('id, user_id')
          .eq('id', widget.submissionId)
          .eq('challenge_id', widget.challengeId)
          .maybeSingle();
      if (data != null) {
        final ratings = await _sb
            .from('challenge_submission_ratings')
            .select('overall_rating')
            .eq('challenge_submission_id', widget.submissionId);
        final values = (ratings as List<dynamic>)
            .map((r) => (((r as Map<String, dynamic>)['overall_rating'] as num?) ?? 0).toDouble())
            .toList();
        final avg = values.isEmpty
            ? 0.0
            : values.reduce((a, b) => a + b) / values.length;
        setState(() {
          _submissionAverageRating = avg;
          _submissionAuthorId = (data['user_id'] ?? '').toString();
        });
        // Load author profile
        if (_submissionAuthorId != null && _submissionAuthorId!.isNotEmpty) {
          try {
            final u = await _sb
                .from('profiles')
                .select('display_name, avatar_url, email')
                .eq('id', _submissionAuthorId!)
                .maybeSingle();
            if (u != null) {
              setState(() {
                _submissionAuthorName = u['display_name'] ??
                    u['email']?.toString().split('@').first ??
                    tr('il_b512d97e7c');
                _submissionAuthorAvatar = (u['avatar_url'] ?? '').toString();
              });
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _checkIfVoted() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return;

      final voteDoc = await _sb
          .from('challenge_submission_ratings')
          .select('overall_rating')
          .eq('challenge_submission_id', widget.submissionId)
          .eq('voter_user_id', currentUser.id)
          .maybeSingle();

      if (voteDoc != null) {
        setState(() {
          _hasVoted = true;
          _rating = ((voteDoc['overall_rating'] as num?) ?? 2.50).toDouble();
        });
      }
    } catch (e) {
      print('Error checking vote status: $e');
    }
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_loopWatcher);
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 70,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _glassIconButton(
                Icons.chevron_left, () => Navigator.pop(context)),
          ),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FlapText.sora(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        titleSpacing: 4,
      ),
      body: _isLoading
          ? _buildPlayerSkeleton()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text(tr('il_8073f27473'),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full-bleed video; tap toggles play/pause.
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: ColoredBox(
                        color: Colors.black,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoPlayerController.value.size.width <= 0
                                ? 9
                                : _videoPlayerController.value.size.width,
                            height:
                                _videoPlayerController.value.size.height <= 0
                                    ? 16
                                    : _videoPlayerController.value.size.height,
                            child: VideoPlayer(_videoPlayerController),
                          ),
                        ),
                      ),
                    ),
                    // Legibility scrims.
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.0, 0.22, 0.62, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Center play affordance — shown only when the user paused,
                    // so the transient non-playing frame at a loop boundary
                    // never flashes the icon.
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _videoPlayerController,
                      builder: (context, value, _) {
                        if (!_userPaused) return const SizedBox.shrink();
                        return Center(
                          child: GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 74,
                              height: 74,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.14),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.28)),
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 38),
                            ),
                          ),
                        );
                      },
                    ),
                    // Right action rail.
                    Positioned(right: 12, bottom: 128, child: _buildRail()),
                    // Bottom creator caption.
                    Positioned(
                      left: 16,
                      right: 84,
                      bottom: 28,
                      child: SafeArea(top: false, child: _buildPlayerCaption()),
                    ),
                  ],
                ),
    );
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
        _userPaused = true;
      } else {
        _videoPlayerController.play();
        _userPaused = false;
      }
    });
  }

  Widget _glassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }

  Widget _buildRail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Voting is only available while the challenge is in its voting phase.
        // Outside that, keep the "voted" badge for users who already rated.
        if (_isVotingOpen || _hasVoted) ...[
          _railButton(
            icon: Icons.star_rounded,
            label: _hasVoted ? tr('voted') : tr('vote'),
            onTap: _hasVoted ? () {} : _showVoteSheet,
            active: _hasVoted,
            activeColor: FlapColors.gold,
          ),
          const SizedBox(height: 18),
        ],
        _railButton(
          icon: Icons.reply_outlined,
          label: tr('share'),
          onTap: _shareVideo,
        ),
      ],
    );
  }

  Widget _railButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Color activeColor = FlapColors.greenBright,
  }) {
    final Color tint = active ? activeColor : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? activeColor.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: active
                    ? activeColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
                fontSize: 11, fontWeight: FontWeight.w600, color: tint),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCaption() {
    final name = (_submissionAuthorName != null &&
            _submissionAuthorName!.isNotEmpty)
        ? _submissionAuthorName!
        : widget.authorName;
    final ratingText =
        (_submissionAverageRating != null && _submissionAverageRating! > 0)
            ? _submissionAverageRating!.toStringAsFixed(2)
            : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_submissionAuthorId != null &&
                _submissionAuthorId!.isNotEmpty) {
              context.router.push(
                PlayerProfileRoute(
                  playerId: _submissionAuthorId!,
                  playerName: name,
                ),
              );
            }
          },
          child: Row(
            children: [
              _creatorAvatar(_submissionAuthorAvatar, name),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: FlapText.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE2E8E3))
              .copyWith(height: 1.4),
        ),
        if (ratingText != null) ...[
          const SizedBox(height: 10),
          _captionChip('$ratingText ${tr('video_avg')}'),
        ],
      ],
    );
  }

  Widget _captionChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 13, color: FlapColors.gold),
          const SizedBox(width: 4),
          Text(
            text,
            style: FlapText.sora(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFCDD4CE)),
          ),
        ],
      ),
    );
  }

  Widget _creatorAvatar(String? avatarUrl, String name) {
    final hasImg = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FlapColors.green,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
        image: hasImg
            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImg
          ? null
          : Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
    );
  }

  Widget _buildPlayerSkeleton() {
    return FlapShimmer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0E1310)),
          Positioned(
            right: 12,
            bottom: 128,
            child: Column(
              children: const [
                FlapSkeletonBox(width: 48, height: 48, radius: 24),
                SizedBox(height: 18),
                FlapSkeletonBox(width: 48, height: 48, radius: 24),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 84,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                FlapSkeletonBox(width: 40, height: 40, radius: 20),
                SizedBox(height: 12),
                FlapSkeletonBox(width: double.infinity, height: 13, radius: 5),
                SizedBox(height: 8),
                FlapSkeletonBox(width: 160, height: 13, radius: 5),
              ],
            ),
          ),
        ],
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

  /// Criterion rows — label and weight on top, a 0.00–5.00 slider (step 0.01) below.
  Widget _voteCriteriaTable(
      Map<String, double> scores, void Function(String, double) setS) {
    Widget critRow(String key, String label, int weight) {
      final value = scores[key]!.clamp(0.0, 5.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune,
                    size: 14, color: FlapColors.greenBright),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
                  ),
                ),
                const SizedBox(width: 5),
                Text('$weight%',
                    style: FlapText.sora(
                        fontSize: 12.5, color: FlapColors.muted2)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      activeTrackColor: FlapColors.greenBright,
                      inactiveTrackColor: const Color(0x14FFFFFF),
                      thumbColor: FlapColors.gold,
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: value,
                      min: 0,
                      max: 5,
                      divisions: 500,
                      label: value.toStringAsFixed(2),
                      onChanged: (v) => setS(key, v),
                    ),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    value.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: FlapText.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FlapColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        critRow('t', tr('il_e851504f43'), 40),
        critRow('c', tr('il_1c9fe98ba9'), 30),
        critRow('d', tr('il_be44133ed5'), 20),
        critRow('q', tr('il_b8c237eb0d'), 10),
      ],
    );
  }

  void _showVoteSheet() {
    if (_hasVoted || !_isVotingOpen) return;
    final firstName = widget.authorName.split(' ').first;
    final scores = <String, double>{'t': 0, 'c': 0, 'd': 0, 'q': 0};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            final weighted = scores['t']! * 0.4 +
                scores['c']! * 0.3 +
                scores['d']! * 0.2 +
                scores['q']! * 0.1;
            return Container(
              decoration: const BoxDecoration(
                color: FlapColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                border:
                    Border(top: BorderSide(color: FlapColors.borderStrong)),
              ),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetGrip(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('challenge_vote_title',
                                  namedArgs: {'name': firstName}),
                              style: FlapText.sora(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          _sheetCloseButton(sheetCtx),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
                      child: Column(
                        children: [
                          _voteCriteriaTable(
                              scores, (k, v) => setSheet(() => scores[k] = v)),
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: weighted <= 0
                                ? null
                                : () {
                                    Navigator.pop(sheetCtx);
                                    _rating = double.parse(
                                        weighted.toStringAsFixed(2));
                                    _submitVote();
                                  },
                            child: Opacity(
                              opacity: weighted <= 0 ? 0.5 : 1,
                              child: Container(
                                height: 54,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: FlapColors.primaryButton,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  weighted > 0
                                      ? '${tr('challenge_vote_submit')} (${weighted.toStringAsFixed(2)})'
                                      : tr('challenge_vote_submit'),
                                  style: FlapText.sora(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: FlapColors.onGreen),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

    Future<void> _submitVote() async {
    if (_hasVoted || _isVoting) return;

    setState(() {
      _isVoting = true;
    });

    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('il_76144c407d'));
      }

      final submissionData = await _sb
          .from('challenge_submissions')
          .select('id, user_id')
          .eq('id', widget.submissionId)
          .eq('challenge_id', widget.challengeId)
          .maybeSingle();

      if (submissionData == null) {
        throw Exception(
          tr('il_01a804d574', args: [tr('il_e861519b9c')]),
        );
      }
      final submissionUserId = (submissionData['user_id'] ?? '').toString();

      if (submissionUserId == currentUser.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('il_2c08f46d5a')),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isVoting = false);
        return;
      }

      final existingVote = await _sb
          .from('challenge_submission_ratings')
          .select('id')
          .eq('challenge_submission_id', widget.submissionId)
          .eq('voter_user_id', currentUser.id)
          .maybeSingle();
      if (existingVote != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('il_97003fa042')),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isVoting = false);
        return;
      }

      await _sb.from('challenge_submission_ratings').insert({
        'challenge_submission_id': widget.submissionId,
        'voter_user_id': currentUser.id,
        'overall_rating': _rating,
      });

      final ratings = await _sb
          .from('challenge_submission_ratings')
          .select('overall_rating')
          .eq('challenge_submission_id', widget.submissionId);
      final values = (ratings as List<dynamic>)
          .map((r) => (((r as Map<String, dynamic>)['overall_rating'] as num?) ?? 0).toDouble())
          .toList();
      final newVotes = values.length;
      final newRating = newVotes == 0
          ? 0.0
          : values.reduce((a, b) => a + b) / newVotes;

      // Award coins for voting (ledger-based).
      await insertCoinTransaction(
        _sb,
        currentUser.id,
        'voting_reward',
        1,
        tr('il_97e061af07'),
      );

      // Reconcile the shared store so the submission card in challenge details
      // updates avg/count/voted instantly.
      sl<InteractionStore>().reconcileVote(
        widget.submissionId,
        ratingAvg: double.parse(newRating.toStringAsFixed(2)),
        voteCount: newVotes,
        votedByMe: true,
      );

      setState(() {
        _submissionAverageRating = newRating;
        _hasVoted = true;
        _isVoting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_acf6612bf4', args: [_rating.toStringAsFixed(2)])),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isVoting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_01a804d574', args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('il_5e912f6fff')),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }
}

