import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/challenges/domain/challenge_failure.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/features/matches/data/rating_service.dart';
import 'package:flap_app/features/profile/data/user_settings_service.dart';
import 'package:flap_app/widgets/user_chip.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/core/app_auth_context.dart';

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
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  // Голосування за відео в челенджі (0.00 - 5.00 з кроком 0.01) - ОДНИМ повзунком
  double _rating = 2.50;
  double _tempRating = 2.50; // Тимчасове значення для плавності
  bool _hasVoted = false;
  bool _isVoting = false;
  final ValueNotifier<double> _tempRatingNotifier = ValueNotifier<double>(2.50);
  double? _submissionAverageRating;
  int? _submissionVoteCount;
  String? _submissionAuthorId;
  String? _submissionAuthorName;
  String? _submissionAuthorAvatar;
  bool _autoplayVideos = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _tempRatingNotifier.value = _tempRating;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfVoted();
      _loadSubmissionAggregate();
    });
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
                    I18n.inline('Помилка відтворення відео', 'Video playback error'),
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
    if (!mounted) return;
    try {
      final entry = await context.read<ChallengeRepository>().getSubmission(
            challengeId: widget.challengeId,
            submissionUserId: widget.submissionId,
          );
      if (!mounted) return;
      if (entry != null) {
        setState(() {
          _submissionAverageRating = entry.averageRating;
          _submissionVoteCount = entry.voteCount;
          _submissionAuthorId = entry.userId.isNotEmpty ? entry.userId : widget.submissionId;
        });
        final aid = _submissionAuthorId;
        if (aid != null && aid.isNotEmpty) {
          try {
            final prof = await context.read<UserProfileRepository>().loadProfile(aid);
            if (!mounted) return;
            if (prof != null) {
              setState(() {
                _submissionAuthorName = prof.resolveDisplayName().isNotEmpty
                    ? prof.resolveDisplayName()
                    : (entry.authorName.isNotEmpty
                        ? entry.authorName
                        : I18n.inline('Користувач', 'User'));
                _submissionAuthorAvatar = prof.avatarUrl ?? '';
              });
            } else if (entry.authorName.isNotEmpty) {
              setState(() {
                _submissionAuthorName = entry.authorName;
              });
            }
          } catch (_) {}
        }
      } else {
        setState(() {
          _submissionAuthorId = widget.submissionId;
          _submissionAuthorName = widget.authorName;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkIfVoted() async {
    if (!mounted) return;
    try {
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) return;

      final myVotes = await context.read<ChallengeRepository>().loadMyVotes(widget.challengeId);
      final existing = myVotes[widget.submissionId];
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _hasVoted = true;
          _rating = existing;
          _tempRating = existing;
          _tempRatingNotifier.value = existing;
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
                                I18n.inline('Помилка завантаження відео', 'Video loading error'),
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

          // Voting Section - ОДНИМ повзунком для челенджів
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
                        I18n.inline('Ваша оцінка', 'Your rating'),
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
                            I18n.inline('Проголосовано', 'Voted'),
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
                              I18n.inline('Загальна оцінка:', 'Overall rating:'),
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
                                        ? I18n.inline('Ви вже проголосували', 'You already voted') 
                                        : I18n.inline('🗳️ Проголосувати (+1 монета)', '🗳️ Vote (+1 coin)'),
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
                            I18n.inline('Оціните відео від 0.00 до 5.00. Ваша оцінка впливає на результат челенджу.', 'Rate video from 0.00 to 5.00. Your rating affects challenge results.'),
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
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) {
        throw Exception(I18n.inline('Користувач не авторизований', 'User not authorized'));
      }

      final submissionUserId = widget.submissionId;
      if (submissionUserId == currentUser.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(I18n.inline('❌ Не можна голосувати за себе!', '❌ Cannot vote for yourself!')),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isVoting = false);
        return;
      }

      final repo = context.read<ChallengeRepository>();
      final entry = await repo.getSubmission(
        challengeId: widget.challengeId,
        submissionUserId: submissionUserId,
      );
      final submissionVideoId = entry?.videoId;

      await repo.castVote(
        challengeId: widget.challengeId,
        submissionUserId: submissionUserId,
        rating: _rating,
        awardCoin: true,
      );

      if (submissionVideoId != null && submissionVideoId.isNotEmpty) {
        try {
          await RatingService().rateVideo(
            videoId: submissionVideoId,
            ratedBy: currentUser.id,
            criteria: {
              'technical': _rating,
              'creativity': _rating,
              'difficulty': _rating,
              'quality': _rating,
            },
          );
        } catch (_) {}
      }

      final updated = await repo.getSubmission(
        challengeId: widget.challengeId,
        submissionUserId: submissionUserId,
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _submissionAverageRating = updated.averageRating;
          _submissionVoteCount = updated.voteCount;
        });
      }

      setState(() {
        _hasVoted = true;
        _isVoting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline(
              '✅ Ваша оцінка ${_rating.toStringAsFixed(2)} збережена! +1 монета',
              '✅ Your rating ${_rating.toStringAsFixed(2)} saved! +1 coin',
            )),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
      }
    } on ChallengeFailure catch (f) {
      if (mounted) {
        setState(() => _isVoting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('❌ ${f.message}', '❌ ${f.message}')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVoting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline(
              '❌ Помилка збереження оцінки: ${e.toString()}',
              '❌ Error saving rating: ${e.toString()}',
            )),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(I18n.inline('🔗 Посилання на відео скопійовано', '🔗 Video link copied')),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }
}

