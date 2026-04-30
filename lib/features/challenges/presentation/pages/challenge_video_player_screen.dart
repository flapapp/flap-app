import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../profile/data/services/user_settings_service.dart';
import '../../../../widgets/user_chip.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import '../../../../core/supabase/coin_ledger.dart';

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

class _ChallengeVideoPlayerScreenState extends State<ChallengeVideoPlayerScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  
  // Challenge video vote (0.00–5.00, step 0.01) — single slider
  double _rating = 2.50;
  double _tempRating = 2.50; // Temporary value for smooth slider updates
  bool _hasVoted = false;
  bool _isVoting = false;
  final ValueNotifier<double> _tempRatingNotifier = ValueNotifier<double>(2.50);
  double? _submissionAverageRating;
  String? _submissionAuthorId;
  String? _submissionAuthorName;
  String? _submissionAuthorAvatar;
  bool _autoplayVideos = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkIfVoted();
    _tempRatingNotifier.value = _tempRating;
    _loadSubmissionAggregate();
  }

  Future<void> _initializeVideo() async {
    try {
      _autoplayVideos = await UserSettingsService().isAutoplayEnabled();
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio == 0
            ? 16 / 9
            : _videoPlayerController.value.aspectRatio,
        autoPlay: _autoplayVideos,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: false,
        autoInitialize: true,
        placeholder: _buildVideoPlaceholder(),
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF4caf50),
          handleColor: Colors.white,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
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
                    tr('il_6529e83499'),
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

  Widget _buildVideoPlaceholder() {
    final thumb = widget.thumbnailUrl ?? '';
    if (thumb.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            thumb,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholderBackdrop(),
          ),
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 72,
            ),
          ),
        ],
      );
    }
    return _placeholderBackdrop();
  }

  Widget _placeholderBackdrop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0f0f23), Color(0xFF1b5e20)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.sports_soccer,
          color: Colors.white24,
          size: 64,
        ),
      ),
    );
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
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    _tempRatingNotifier.dispose();
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
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_submissionAverageRating != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700)),
                  const SizedBox(width: 4),
                  Text(
                    _submissionAverageRating!.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
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
                              Text(
                                tr('il_8073f27473'),
                                style: const TextStyle(color: Colors.white, fontSize: 18),
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

          // Author info under the video
          if (_submissionAuthorId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black,
              child: Row(
                children: [
                  Expanded(
                    child: UserChip(
                      userId: _submissionAuthorId!,
                      name: _submissionAuthorName,
                      avatarUrl: _submissionAuthorAvatar,
                      showName: true,
                    ),
                  ),
                  if (_submissionAverageRating != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _submissionAverageRating!.toStringAsFixed(2),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Voting section — single slider for challenges
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
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
                      Text(
                        tr('il_68548b47e7'),
                        style: const TextStyle(
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
                          child: Text(
                            tr('il_9cf238dedb'),
                            style: const TextStyle(
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
                            Text(
                              tr('il_c1be3e30f1'),
                              style: const TextStyle(
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
                              child: ValueListenableBuilder<double>(
                                valueListenable: _tempRatingNotifier,
                                builder: (context, value, _) => Text(
                                  value.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Color(0xFF4caf50),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          child: ValueListenableBuilder<double>(
                            valueListenable: _tempRatingNotifier,
                            builder: (context, tempValue, _) => SliderTheme(
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
                                value: tempValue,
                                min: 0.0,
                                max: 5.0,
                                label: tempValue.toStringAsFixed(2),
                                onChanged: _hasVoted ? null : (value) {
                                  _tempRatingNotifier.value = value;
                                },
                                onChangeEnd: _hasVoted ? null : (value) {
                                  final roundedValue = (value * 100).round() / 100;
                                  _tempRating = roundedValue;
                                  _tempRatingNotifier.value = roundedValue;
                                  _rating = roundedValue;
                                },
                              ),
                            ),
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
                                        ? tr('il_4737e31c44') 
                                        : tr('il_c829c4660c'),
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
                            tr('il_f434505723'),
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
      _submissionAverageRating = newRating;

      // Award coins for voting (ledger-based).
      await insertCoinTransaction(
        _sb,
        currentUser.id,
        'voting_reward',
        1,
        tr('il_97e061af07'),
      );

      setState(() {
        _hasVoted = true;
        _isVoting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_acf6612bf4', args: [_rating.toStringAsFixed(1)])),
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

