import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import '../../../subscriptions/presentation/premium_gate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/interactions/interaction_store.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../../../../router/app_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../profile/data/services/user_settings_service.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../constants/video_categories.dart';
import '../../../../core/locale/football_position.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import '../../../../core/supabase/supabase_date.dart';

@RoutePage()
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String authorName;
  final String videoId;
  final String? challengeId; // Set when video is from a challenge
  final String? submissionUserId; // Submission author for voting
  final bool autoOpenRating;

  /// Optional feed for TikTok-style vertical paging. Each entry should carry
  /// at least `id`, `videoUrl`, `title` and an author-name field. When omitted
  /// (or single-item), the screen shows just the one video.
  final List<Map<String, dynamic>>? playlist;
  final int initialIndex;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.videoId,
    this.challengeId,
    this.submissionUserId,
    this.autoOpenRating = false,
    this.playlist,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  bool get _hasPlaylist =>
      widget.playlist != null && widget.playlist!.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = _hasPlaylist
        ? widget.initialIndex.clamp(0, widget.playlist!.length - 1)
        : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _str(Map<String, dynamic> v, List<String> keys) {
    for (final k in keys) {
      final val = v[k];
      if (val != null && val.toString().isNotEmpty) return val.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPlaylist) {
      return _VideoPage(
        videoUrl: widget.videoUrl,
        title: widget.title,
        authorName: widget.authorName,
        videoId: widget.videoId,
        challengeId: widget.challengeId,
        submissionUserId: widget.submissionUserId,
        autoOpenRating: widget.autoOpenRating,
        isActive: true,
      );
    }
    final items = widget.playlist!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: items.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final v = items[i];
          final id = _str(v, ['id']);
          return _VideoPage(
            key: ValueKey(id.isNotEmpty ? id : 'page-$i'),
            videoId: id,
            videoUrl: _str(v, ['videoUrl']),
            title: _str(v, ['title']),
            authorName: _str(v, ['authorName', 'displayName', 'userName']),
            autoOpenRating: false,
            isActive: i == _currentIndex,
          );
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String authorName;
  final String videoId;
  final String? challengeId;
  final String? submissionUserId;
  final bool autoOpenRating;
  final bool isActive;

  const _VideoPage({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.videoId,
    this.challengeId,
    this.submissionUserId,
    this.autoOpenRating = false,
    this.isActive = true,
  }) : super(key: key);

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage>
    with AutoRouteAwareStateMixin<_VideoPage> {
  final SupabaseClient _sb = Supabase.instance.client;
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  // Whether playback was active when a new screen was pushed over the player,
  // so we resume on return instead of starting a paused/inactive video.
  bool _resumeAfterReturn = false;
  
  // Likes and comments
  bool _isLiked = false;
  int _likesCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  // Video vote (0.00–5.00, step 0.01)
  double _technical = 2.50;
  double _creativity = 2.50;
  double _difficulty = 2.50;
  double _quality = 2.50;
  bool _hasVoted = false;
  bool _isSubmittingVote = false;
  bool _isAdvancedVoting = false; // Simple (false) vs advanced (true)
  String? _videoAuthorId;
  String? _videoAuthorName;
  String? _videoAuthorAvatar;
  String? _authorPosition;
  String _videoCategory = '';
  bool get _isChallengeSubmission => widget.challengeId != null && widget.submissionUserId != null;
  double? _videoAverageRating;
  int? _videoVoteCount;
  bool _pendingRatingPrompt = false;
  bool _autoplayVideos = true;
  // Tracks whether the user deliberately paused. The center play affordance is
  // gated on this (not the raw isPlaying) so the brief non-playing frame at a
  // loop boundary never flashes the play icon.
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoData();
    _pendingRatingPrompt = widget.autoOpenRating;
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Play only the page the user is currently looking at (TikTok-style).
    if (widget.isActive != oldWidget.isActive && !_isLoading) {
      if (widget.isActive) {
        if (_autoplayVideos) _videoPlayerController.play();
      } else {
        _videoPlayerController.pause();
        _videoPlayerController.seekTo(Duration.zero);
      }
    }
  }

  /// A new screen was pushed over the player — pause so the video doesn't keep
  /// playing in the background. Position is preserved for resume on return.
  @override
  void didPushNext() {
    if (_isLoading) return;
    if (_videoPlayerController.value.isInitialized &&
        _videoPlayerController.value.isPlaying) {
      _resumeAfterReturn = true;
      _videoPlayerController.pause();
    }
  }

  /// Returned to the player — resume the visible page from where it paused.
  @override
  void didPopNext() {
    if (_isLoading) return;
    if (_resumeAfterReturn &&
        widget.isActive &&
        _autoplayVideos &&
        _videoPlayerController.value.isInitialized) {
      _videoPlayerController.play();
    }
    _resumeAfterReturn = false;
  }

  Future<void> _loadVideoData() async {
    try {
      if (_isChallengeSubmission) {
        // For challenge submissions, author is known
        setState(() {
          _videoAuthorId = widget.submissionUserId;
        });
        if (_videoAuthorId != null && _videoAuthorId!.isNotEmpty) {
          final ud = await _sb
              .from('profiles')
              .select('display_name, avatar_url, email, position')
              .eq('id', _videoAuthorId!)
              .maybeSingle();
          if (ud != null) {
            setState(() {
              _videoAuthorName = ud['display_name'] ??
                  ud['email']?.toString().split('@').first ??
                  tr('il_b512d97e7c');
              _videoAuthorAvatar = (ud['avatar_url'] ?? '').toString();
              _authorPosition = ud['position']?.toString();
            });
          }
        }
        await _computeChallengeSubmissionAverage();
      } else {
        // Load likes/author from videos collection
        final data = await _sb
            .from('videos')
            .select('user_id, category')
            .eq('id', widget.videoId)
            .maybeSingle();
        if (data != null) {
          final likes = await _sb
              .from('video_likes')
              .select('user_id')
              .eq('video_id', widget.videoId);
          setState(() {
            _likesCount = (likes as List<dynamic>).length;
            _videoAuthorId = data['user_id']?.toString();
            _videoCategory = (data['category'] ?? '').toString();
          });
          if (_videoAuthorId != null && _videoAuthorId!.isNotEmpty) {
            final ud = await _sb
                .from('profiles')
                .select('display_name, avatar_url, email, position')
                .eq('id', _videoAuthorId!)
                .maybeSingle();
            if (ud != null) {
              setState(() {
                _videoAuthorName = ud['display_name'] ??
                    ud['email']?.toString().split('@').first ??
                    tr('il_b512d97e7c');
                _videoAuthorAvatar = (ud['avatar_url'] ?? '').toString();
                _authorPosition = ud['position']?.toString();
              });
            }
          }
          await _computeVideoAverage();
          final currentUser = AppAuth.currentUser;
          if (currentUser != null) {
            final likeDoc = await _sb
                .from('video_likes')
                .select('user_id')
                .eq('video_id', widget.videoId)
                .eq('user_id', currentUser.id)
                .maybeSingle();
            setState(() {
              _isLiked = likeDoc != null;
            });

            final voteDoc = await _sb
                .from('video_ratings')
                .select('overall_rating')
                .eq('video_id', widget.videoId)
                .eq('rated_by', currentUser.id)
                .maybeSingle();
            if (voteDoc != null) {
              final overall = ((voteDoc['overall_rating'] as num?) ?? 0).toDouble();
              setState(() {
                _hasVoted = true;
                _technical = overall;
                _creativity = overall;
                _difficulty = overall;
                _quality = overall;
              });
            }
          }
          // Seed the centralized store so this video's like/vote state stays
          // consistent with the feed/grid and updates propagate both ways.
          final store = sl<InteractionStore>();
          store.seedLike(widget.videoId,
              likeCount: _likesCount, likedByMe: _isLiked);
          store.seedRating(widget.videoId,
              ratingAvg: _videoAverageRating ?? 0.0,
              voteCount: _videoVoteCount ?? 0,
              votedByMe: _hasVoted);
        }
        // Comments only for general (non-challenge) videos
        _loadComments();
      }
    } catch (e) {
      print('Error loading video data: $e');
    }
    _openRatingIfNeeded();
  }

  void _openRatingIfNeeded() {
    if (!_pendingRatingPrompt || _isChallengeSubmission || _hasVoted) {
      _pendingRatingPrompt = false;
      return;
    }
    _pendingRatingPrompt = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showVotingBottomSheet();
      }
    });
  }

  Future<void> _computeVideoAverage() async {
    try {
      final votes = await _sb
          .from('video_ratings')
          .select('overall_rating')
          .eq('video_id', widget.videoId);
      final rows = votes as List<dynamic>;
      if (rows.isEmpty) {
        setState(() {
          _videoAverageRating = 0.0;
          _videoVoteCount = 0;
        });
        sl<InteractionStore>()
            .mergeContent(widget.videoId, ratingAvg: 0.0, voteCount: 0);
        return;
      }
      double sum = 0.0;
      for (final d in rows) {
        final m = d as Map<String, dynamic>;
        final r = (m['overall_rating'] ?? 0.0) as num;
        sum += r.toDouble();
      }
      final avg = double.parse((sum / rows.length).toStringAsFixed(2));
      setState(() {
        _videoVoteCount = rows.length;
        _videoAverageRating = avg;
      });
      // Authoritative rating aggregate → store, so feed/grid badges update.
      sl<InteractionStore>()
          .mergeContent(widget.videoId, ratingAvg: avg, voteCount: rows.length);
    } catch (_) {}
  }

  Future<void> _computeChallengeSubmissionAverage() async {
    if (!_isChallengeSubmission) return;
    try {
      final submission = await _sb
          .from('challenge_submissions')
          .select('id')
          .eq('challenge_id', widget.challengeId!)
          .eq('user_id', widget.submissionUserId!)
          .maybeSingle();
      if (submission == null) {
        if (mounted) {
          setState(() {
            _videoAverageRating = 0.0;
            _videoVoteCount = 0;
          });
        }
        return;
      }
      final submissionId = submission['id'].toString();
      final votes = await _sb
          .from('challenge_submission_ratings')
          .select('overall_rating')
          .eq('challenge_submission_id', submissionId);
      final rows = votes as List<dynamic>;
      if (rows.isEmpty) {
        if (mounted) {
          setState(() {
            _videoAverageRating = 0.0;
            _videoVoteCount = 0;
          });
        }
        return;
      }
      double sum = 0.0;
      for (final d in rows) {
        final m = d as Map<String, dynamic>;
        sum += ((m['overall_rating'] ?? 0.0) as num).toDouble();
      }
      if (!mounted) return;
      setState(() {
        _videoVoteCount = rows.length;
        _videoAverageRating = double.parse(
          (sum / rows.length).toStringAsFixed(2),
        );
      });
    } catch (_) {}
  }

  Future<void> _submitVote() async {
    if (!await PremiumGate.ensure(context)) return;
    if (_isChallengeSubmission) {
      return _submitChallengeVote();
    }
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    if (_hasVoted) return;
    if (_videoAuthorId != null && _videoAuthorId == currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_11bedab9bb'))),
      );
      return;
    }

    setState(() {
      _isSubmittingVote = true;
    });

    try {
      // Voting via RatingsRepository
      final criteria = {
        'technical': _technical,
        'creativity': _creativity,
        'difficulty': _difficulty,
        'quality': _quality,
      };

      final success = await sl<RatingsRepository>().rateVideo(
        videoId: widget.videoId,
        ratedBy: currentUser.id,
        criteria: criteria,
      );

      if (success) {
        await _computeVideoAverage();
        // Mark this user as having voted in the shared store (rail + other
        // screens reflect it instantly; the author's overall RatingDisplay
        // refreshes via RatingService → UserRatingStore).
        sl<InteractionStore>().mergeContent(widget.videoId, votedByMe: true);
        if (!mounted) return;
        setState(() {
          _hasVoted = true;
        });

        // Show vote success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_7ffa23afac')),
            backgroundColor: Colors.green,
          ),
        );
        // No extra notifications for the voter
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_9554d71838')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error submitting vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_d351acab39', namedArgs: {'e': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingVote = false;
        });
      }
    }
  }

  Future<void> _submitChallengeVote() async {
    if (!await PremiumGate.ensure(context)) return;
    final currentUser = AppAuth.currentUser;
    if (currentUser == null || !_isChallengeSubmission) return;
    if (_hasVoted) return;
    if (widget.submissionUserId == currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_11bedab9bb'))),
      );
      return;
    }

    setState(() { _isSubmittingVote = true; });
    try {
      // Weighted rating like feed videos
      final weighted = (_technical * 0.4) + (_creativity * 0.3) + (_difficulty * 0.2) + (_quality * 0.1);
      final challengeId = widget.challengeId!;
      final targetUserId = widget.submissionUserId!;

      final submission = await _sb
          .from('challenge_submissions')
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('user_id', targetUserId)
          .maybeSingle();
      if (submission == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_8073f27473')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final submissionId = submission['id'].toString();

      // Avoid duplicate votes
      final voteDoc = await _sb
          .from('challenge_submission_ratings')
          .select('id')
          .eq('challenge_submission_id', submissionId)
          .eq('voter_user_id', currentUser.id)
          .maybeSingle();
      if (voteDoc != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_97003fa042')), backgroundColor: Colors.red),
        );
        return;
      }

      await _sb.from('challenge_submission_ratings').upsert({
        'challenge_submission_id': submissionId,
        'voter_user_id': currentUser.id,
        'overall_rating': weighted,
      });

      await _computeChallengeSubmissionAverage();
      // Reconcile shared store (keyed by submission id) so the challenge
      // details card reflects this vote instantly.
      sl<InteractionStore>().reconcileVote(
        submissionId,
        ratingAvg: _videoAverageRating ?? 0.0,
        voteCount: _videoVoteCount ?? 0,
        votedByMe: true,
      );
      if (!mounted) return;
      setState(() {
        _hasVoted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_c9bfcd4ac3', args: [weighted.toStringAsFixed(2)]),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_a54a4740b5', namedArgs: {'e': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() { _isSubmittingVote = false; });
    }
  }

  Future<void> _loadComments() async {
    try {
      final commentsSnapshot = await _sb
          .from('video_comments')
          .select('id, body, user_id, created_at')
          .eq('video_id', widget.videoId)
          .order('created_at', ascending: false);

      final rows = commentsSnapshot as List<dynamic>;
      final userIds = rows
          .map((r) => (r as Map<String, dynamic>)['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final nameById = <String, String>{};
      final avatarById = <String, String>{};
      if (userIds.isNotEmpty) {
        final users = await _sb
            .from('profiles')
            .select('id, display_name, avatar_url, email')
            .inFilter('id', userIds);
        for (final raw in users as List<dynamic>) {
          final u = raw as Map<String, dynamic>;
          nameById[u['id'].toString()] = (u['display_name'] ??
                  u['email']?.toString().split('@').first ??
                  tr('il_b764cdc0ea'))
              .toString();
          avatarById[u['id'].toString()] = (u['avatar_url'] ?? '').toString();
        }
      }

      final comments = <Map<String, dynamic>>[];
      for (final raw in rows) {
        final data = raw as Map<String, dynamic>;
        final authorId = (data['user_id'] ?? '').toString();
        comments.add({
          'id': data['id'],
          'text': data['body'] ?? '',
          'userId': authorId,
          'authorName': nameById[authorId] ?? tr('il_b764cdc0ea'),
          'authorAvatarUrl': avatarById[authorId] ?? '',
          'createdAt': data['created_at'],
        });
      }
      
      setState(() {
        _comments = comments;
      });
      // Authoritative comment count → store, so the feed/grid chips stay in sync.
      sl<InteractionStore>()
          .reconcileComment(widget.videoId, comments.length);
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _autoplayVideos = (await sl<UserSettingsService>().getSettings()).autoplayVideos;
      // When autoplay is off the video starts paused, so the play affordance
      // should be visible immediately.
      _userPaused = !_autoplayVideos;
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      
      await _videoPlayerController.initialize();
      await _videoPlayerController.setLooping(true);
      // Belt-and-suspenders: some platforms don't honour setLooping reliably,
      // so also restart manually when playback reaches the end.
      _videoPlayerController.addListener(_loopWatcher);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: _autoplayVideos,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
      
      setState(() {
        _isLoading = false;
      });
      // The raw player is rendered directly (not Chewie's widget), so kick off
      // autoplay manually — but only for the page currently in view.
      if (widget.isActive && _autoplayVideos) {
        _videoPlayerController.play();
      }
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLike() async {
    if (!await PremiumGate.ensure(context)) return;
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    final store = sl<InteractionStore>();
    final previous = store.peek(widget.videoId);
    final willLike = !previous.likedByMe;
    // Optimistic: every screen watching this video updates instantly.
    store.applyLikeOptimistic(widget.videoId, likedByMe: willLike);
    try {
      if (willLike) {
        await _sb.from('video_likes').upsert({
          'video_id': widget.videoId,
          'user_id': currentUser.id,
        });
      } else {
        await _sb
            .from('video_likes')
            .delete()
            .eq('video_id', widget.videoId)
            .eq('user_id', currentUser.id);
      }
      final likes = await _sb
          .from('video_likes')
          .select('user_id')
          .eq('video_id', widget.videoId);
      store.reconcileLike(widget.videoId,
          likeCount: (likes as List<dynamic>).length, likedByMe: willLike);
    } catch (e) {
      store.restore(widget.videoId, previous); // rollback
      print('Error toggling like: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (!await PremiumGate.ensure(context)) return;

    // Ensure videoId is non-empty
    if (widget.videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_965c3a3ee5')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return;
      
      // Add comment
      await _sb.from('video_comments').insert({
        'video_id': widget.videoId,
        'user_id': currentUser.id,
        'body': _commentController.text.trim(),
      });
      
      // Clear field and reload comments
      _commentController.clear();
      await _loadComments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_054d693729')),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
      }
      
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  String _formatCommentDate(dynamic timestamp) {
    if (timestamp == null) return tr('il_f81ae5034f');
    
    try {
      final date = asDateTimeOrNull(timestamp);
      if (date == null) return tr('il_f81ae5034f');
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return tr('il_adf8ee5f65', args: ['${difference.inDays}']);
      } else if (difference.inHours > 0) {
        return tr('il_7634d1849f', args: ['${difference.inHours}']);
      } else if (difference.inMinutes > 0) {
        return tr('il_e0b53645d6', args: ['${difference.inMinutes}']);
      } else {
        return tr('il_66f53417d3');
      }
    } catch (e) {
      return tr('il_f81ae5034f');
    }
  }

  void _loopWatcher() {
    final v = _videoPlayerController.value;
    if (!v.isInitialized || v.duration <= Duration.zero) return;
    // Reached the end and stopped — rewind and keep playing, unless the user
    // deliberately paused (then we leave it paused).
    if (!v.isPlaying && v.position >= v.duration && !_userPaused) {
      _videoPlayerController.seekTo(Duration.zero);
      if (widget.isActive) {
        _videoPlayerController.play();
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_loopWatcher);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// Drag-to-rate 0.00–5.00 slider (step 0.01) with a live numeric readout.
  Widget _ratingSlider(double value, ValueChanged<double> onChanged) {
    final clamped = value.clamp(0.0, 5.0);
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: FlapColors.greenBright,
              inactiveTrackColor: const Color(0x14FFFFFF),
              thumbColor: FlapColors.gold,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: clamped,
              min: 0,
              max: 5,
              divisions: 500,
              label: clamped.toStringAsFixed(2),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            clamped.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: FlapText.sora(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FlapColors.gold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _voteCriterionRow(
      IconData icon, String label, double value, ValueChanged<double> onPick) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: FlapColors.greenBright),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
                ),
              ),
            ],
          ),
          _ratingSlider(value, onPick),
        ],
      ),
    );
  }

  /// The challenge "main"/creator clip is pushed with no video record
  /// (`videoId` empty) and no submission author, so it's a preview to watch,
  /// not a social post. In that case strip the like/comment/vote/share rail,
  /// the author caption, and the legibility scrims so only the video shows.
  bool get _chromeless =>
      widget.videoId.isEmpty &&
      (widget.submissionUserId == null || widget.submissionUserId!.isEmpty);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
              child: _glassIconButton(Icons.chevron_left, _popBack),
            ),
          ),
        ),
        body: _buildPlayerSkeleton(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                tr('il_8073f27473'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
            child: _glassIconButton(Icons.chevron_left, _popBack),
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
      body: _chewieController != null
          ? Stack(
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
                        height: _videoPlayerController.value.size.height <= 0
                            ? 16
                            : _videoPlayerController.value.size.height,
                        child: VideoPlayer(_videoPlayerController),
                      ),
                    ),
                  ),
                ),

                // Top + bottom legibility scrims (only needed behind the
                // overlay chrome, so skipped for a chromeless preview).
                if (!_chromeless)
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

                // Center play affordance — shown only when the user paused, so
                // the transient non-playing frame at a loop boundary never
                // flashes the icon.
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
                                color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 38),
                        ),
                      ),
                    );
                  },
                ),

                // Right action rail — Like / Comment / Vote / Share.
                if (!_chromeless)
                  Positioned(
                    right: 12,
                    bottom: 128,
                    child: _buildRail(),
                  ),

                // Bottom creator caption (the author / user section).
                if (!_chromeless)
                  Positioned(
                    left: 16,
                    right: 84,
                    bottom: 28,
                    child: SafeArea(
                      top: false,
                      child: _buildPlayerCaption(),
                    ),
                  ),
              ],
            )
          : _buildPlayerSkeleton(),
    );
  }

  Widget _buildPlayerSkeleton() {
    return FlapShimmer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0E1310)),
          // Right action rail placeholders.
          Positioned(
            right: 14,
            bottom: 128,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: i == 3 ? 0 : 18),
                  child: Column(
                    children: const [
                      FlapSkeletonBox(width: 48, height: 48, radius: 24),
                      SizedBox(height: 6),
                      FlapSkeletonBox(width: 22, height: 8, radius: 4),
                    ],
                  ),
                );
              }),
            ),
          ),
          // Bottom caption placeholders.
          Positioned(
            left: 16,
            right: 84,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      FlapSkeletonBox(width: 40, height: 40, radius: 20),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FlapSkeletonBox(width: 120, height: 12, radius: 5),
                          SizedBox(height: 6),
                          FlapSkeletonBox(width: 80, height: 10, radius: 5),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  FlapSkeletonBox(width: double.infinity, height: 13, radius: 5),
                  SizedBox(height: 6),
                  FlapSkeletonBox(width: 160, height: 13, radius: 5),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      FlapSkeletonBox(width: 70, height: 24, radius: 8),
                      SizedBox(width: 7),
                      FlapSkeletonBox(width: 58, height: 24, radius: 8),
                    ],
                  ),
                ],
              ),
            ),
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

  void _popBack() {
    Navigator.pop(context, {
      'ratingUpdated': _hasVoted,
      'videoId': widget.videoId,
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
    return ValueListenableBuilder<ContentInteraction>(
      valueListenable: sl<InteractionStore>().watchVideo(widget.videoId),
      builder: (context, ci, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _railButton(
            icon: ci.likedByMe ? Icons.favorite : Icons.favorite_border,
            label: '${ci.likeCount}',
            onTap: _toggleLike,
            active: ci.likedByMe,
            activeColor: const Color(0xFFFF6B7D),
          ),
          const SizedBox(height: 18),
          _railButton(
            icon: Icons.mode_comment_outlined,
            label: '${ci.commentCount}',
            onTap: _showCommentsBottomSheet,
          ),
          if (!_isChallengeSubmission) ...[
            const SizedBox(height: 18),
            _railButton(
              icon: Icons.star_rounded,
              label: ci.votedByMe ? tr('voted') : tr('vote'),
              onTap: _showVotingBottomSheet,
              active: ci.votedByMe,
              activeColor: FlapColors.gold,
            ),
          ],
          const SizedBox(height: 18),
          _railButton(
            icon: Icons.reply_outlined,
            label: tr('share'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('il_28a4a65f94'))),
              );
            },
          ),
        ],
      ),
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
    final name = _videoAuthorName ?? widget.authorName;
    final ratingText = (_videoAverageRating != null && _videoAverageRating! > 0)
        ? _videoAverageRating!.toStringAsFixed(2)
        : null;

    // Subtitle: position · N ratings (real data only).
    final pos = positionLabelForDisplay(_authorPosition).trim();
    final voteCount = _videoVoteCount ?? 0;
    final subParts = <String>[
      if (pos.isNotEmpty) pos,
      if (voteCount > 0)
        tr('video_ratings_count', namedArgs: {'count': '$voteCount'}),
    ];
    final subtitle = subParts.join(' · ');

    // Category + rating chips.
    final catLabel = (_videoCategory.isNotEmpty && _videoCategory != 'other')
        ? videoCategoryLabel(_videoCategory)
        : null;
    final chips = <Widget>[
      if (catLabel != null) _captionChip('#$catLabel'),
      if (ratingText != null)
        _captionChip('$ratingText ${tr('video_avg')}',
            icon: Icons.star_rounded, iconColor: const Color(0xFFE7C25A)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_videoAuthorId != null) {
              context.router.push(
                PlayerProfileRoute(
                  playerId: _videoAuthorId!,
                  playerName: name,
                ),
              );
            }
          },
          child: Row(
            children: [
              _creatorAvatar(_videoAuthorAvatar, name),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FlapText.sora(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFBCC4BE)),
                        ),
                      ),
                  ],
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
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: chips),
        ],
      ],
    );
  }

  Widget _captionChip(String text, {IconData? icon, Color? iconColor}) {
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
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor ?? const Color(0xFFCDD4CE)),
            const SizedBox(width: 4),
          ],
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
        image: hasImg
            ? DecorationImage(
                image: NetworkImage(avatarUrl), fit: BoxFit.cover)
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

  // ----------------------------------------------------------- sheet chrome

  Widget _sheetGrip() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _sheetCloseButton(VoidCallback onTap) {
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
        child: const Icon(Icons.close, size: 17, color: FlapColors.muted),
      ),
    );
  }

  Widget _commentAvatar(String? url, String name) {
    final hasImg = url != null && url.isNotEmpty;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FlapColors.green,
        image: hasImg
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImg
          ? null
          : Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            ),
    );
  }

  Widget _commentRow(Map<String, dynamic> c) {
    final name = (c['authorName'] ?? tr('il_b764cdc0ea')).toString();
    final url = (c['authorAvatarUrl'] ?? '').toString();
    final text = (c['text'] ?? '').toString();
    final time = _formatCommentDate(c['createdAt']);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _commentAvatar(url.isEmpty ? null : url, name),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    time,
                    style: FlapText.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: FlapColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: FlapText.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC8CFC9))
                    .copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rateBigSlider(double current, ValueChanged<double> onChanged) {
    final clamped = current.clamp(0.0, 5.0);
    return Column(
      children: [
        Text(
          clamped.toStringAsFixed(2),
          style: FlapText.sora(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: FlapColors.gold,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: FlapColors.greenBright,
            inactiveTrackColor: const Color(0x14FFFFFF),
            thumbColor: FlapColors.gold,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: clamped,
            min: 0,
            max: 5,
            divisions: 500,
            label: clamped.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------- comments sheet

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FlapColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.74,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) => DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: FlapColors.borderStrong)),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Center(child: _sheetGrip()),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
                    child: Row(
                      children: [
                        Text(
                          '${tr('comments')} · ${_comments.length}',
                          style: FlapText.sora(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _sheetCloseButton(() => Navigator.pop(sheetContext)),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: _comments.isEmpty
                        ? Center(
                            child: Text(
                              tr('il_6b25808365'),
                              style: FlapText.sora(
                                  fontSize: 13.5, color: FlapColors.muted),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 17),
                            itemBuilder: (context, index) =>
                                _commentRow(_comments[index]),
                          ),
                  ),
                  // Compose
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: FlapColors.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: FlapText.sora(fontSize: 14),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) async {
                                await _addComment();
                                setSheet(() {});
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: tr('il_23c5f33170'),
                                hintStyle: FlapText.sora(
                                    fontSize: 14, color: FlapColors.muted),
                                filled: true,
                                fillColor: FlapColors.surface2,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 13),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () async {
                              await _addComment();
                              setSheet(() {});
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: FlapColors.primaryButton,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.arrow_upward_rounded,
                                  color: FlapColors.onGreen, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- rate sheet

  void _showVotingBottomSheet() {
    if (_hasVoted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_56da4f1078'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: FlapColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: FlapColors.borderStrong)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _sheetGrip()),
                    const SizedBox(height: 6),
                    // Header
                    Row(
                      children: [
                        Text(
                          _isChallengeSubmission
                              ? tr('il_8f17154dba')
                              : tr('il_f059de72eb'),
                          style: FlapText.sora(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _sheetCloseButton(() => Navigator.pop(sheetContext)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('video_rate_hint'),
                      textAlign: TextAlign.center,
                      style: FlapText.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: FlapColors.muted),
                    ),
                    const SizedBox(height: 16),
                    // Mode segment
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FlapColors.border),
                      ),
                      child: Row(
                        children: [
                          _voteModeTab(
                            label: tr('il_3fee95da5a'),
                            selected: !_isAdvancedVoting,
                            onTap: () =>
                                setModalState(() => _isAdvancedVoting = false),
                          ),
                          const SizedBox(width: 4),
                          _voteModeTab(
                            label: tr('il_9f088dbebd'),
                            selected: _isAdvancedVoting,
                            onTap: () =>
                                setModalState(() => _isAdvancedVoting = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Body
                    if (_isAdvancedVoting) ...[
                      _voteCriterionRow(
                          Icons.sports_soccer, tr('il_e851504f43'), _technical,
                          (v) => setModalState(() => _technical = v)),
                      _voteCriterionRow(Icons.auto_awesome,
                          tr('il_1c9fe98ba9'), _creativity,
                          (v) => setModalState(() => _creativity = v)),
                      _voteCriterionRow(Icons.local_fire_department,
                          tr('il_be44133ed5'), _difficulty,
                          (v) => setModalState(() => _difficulty = v)),
                      _voteCriterionRow(Icons.workspace_premium,
                          tr('il_b8c237eb0d'), _quality,
                          (v) => setModalState(() => _quality = v)),
                    ] else ...[
                      _rateBigSlider(_technical, (v) {
                        setModalState(() {
                          _technical = v;
                          _creativity = v;
                          _difficulty = v;
                          _quality = v;
                        });
                      }),
                    ],
                    const SizedBox(height: 22),
                    // Submit
                    GestureDetector(
                      onTap: _isSubmittingVote
                          ? null
                          : () {
                              _submitVote();
                              Navigator.pop(sheetContext);
                            },
                      child: Opacity(
                        opacity: _isSubmittingVote ? 0.5 : 1,
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: FlapColors.primaryButton,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            _isSubmittingVote
                                ? tr('il_64115d5b9c')
                                : tr('il_cd5588db6f'),
                            style: FlapText.sora(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: FlapColors.onGreen),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _voteModeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? FlapColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: FlapText.sora(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? FlapColors.text : FlapColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
