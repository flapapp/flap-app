import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../../../../router/app_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../profile/data/services/user_settings_service.dart';
import '../../../../widgets/rating_display.dart';
import '../../../../widgets/user_chip.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import '../../../../core/supabase/supabase_date.dart';

@RoutePage()
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String authorName;
  final String videoId;
  final String? challengeId; // якщо це відео з челенджу
  final String? submissionUserId; // автор submission для голосування
  final bool autoOpenRating;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.videoId,
    this.challengeId,
    this.submissionUserId,
    this.autoOpenRating = false,
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  
  // Лайки та коментарі
  bool _isLiked = false;
  int _likesCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  // Голосування за відео (0.00 - 5.00 з кроком 0.01)
  double _technical = 2.50;
  double _creativity = 2.50;
  double _difficulty = 2.50;
  double _quality = 2.50;
  bool _hasVoted = false;
  bool _isSubmittingVote = false;
  bool _isAdvancedVoting = false; // Простий (false) або Розширений (true)
  String? _videoAuthorId;
  String? _videoAuthorName;
  String? _videoAuthorAvatar;
  bool get _isChallengeSubmission => widget.challengeId != null && widget.submissionUserId != null;
  double? _videoAverageRating;
  int? _videoVoteCount;
  bool _pendingRatingPrompt = false;
  bool _autoplayVideos = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoData();
    _pendingRatingPrompt = widget.autoOpenRating;
  }

  Future<void> _loadVideoData() async {
    try {
      if (_isChallengeSubmission) {
        // Для submission з челенджу — автор відомий
        setState(() {
          _videoAuthorId = widget.submissionUserId;
        });
        if (_videoAuthorId != null && _videoAuthorId!.isNotEmpty) {
          final ud = await _sb
              .from('profiles')
              .select('display_name, avatar_url, email')
              .eq('id', _videoAuthorId!)
              .maybeSingle();
          if (ud != null) {
            setState(() {
              _videoAuthorName = ud['display_name'] ??
                  ud['email']?.toString().split('@').first ??
                  tr('il_b512d97e7c');
              _videoAuthorAvatar = (ud['avatar_url'] ?? '').toString();
            });
          }
        }
      } else {
        // Завантажуємо дані про лайки/автора з колекції videos
        final data = await _sb
            .from('videos')
            .select('user_id')
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
          });
          if (_videoAuthorId != null && _videoAuthorId!.isNotEmpty) {
            final ud = await _sb
                .from('profiles')
                .select('display_name, avatar_url, email')
                .eq('id', _videoAuthorId!)
                .maybeSingle();
            if (ud != null) {
              setState(() {
                _videoAuthorName = ud['display_name'] ??
                    ud['email']?.toString().split('@').first ??
                    tr('il_b512d97e7c');
                _videoAuthorAvatar = (ud['avatar_url'] ?? '').toString();
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
        }
        // Коментарі актуальні лише для загальних відео
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
        return;
      }
      double sum = 0.0;
      for (final d in rows) {
        final m = d as Map<String, dynamic>;
        final r = (m['overall_rating'] ?? 0.0) as num;
        sum += r.toDouble();
      }
      setState(() {
        _videoVoteCount = rows.length;
        _videoAverageRating = double.parse((sum / _videoVoteCount!).toStringAsFixed(2));
      });
    } catch (_) {}
  }

  Future<void> _submitVote() async {
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
      // Голосування через RatingsRepository
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
        setState(() {
          _hasVoted = true;
        });
        
        // Показуємо сповіщення про успішне голосування
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_7ffa23afac')),
            backgroundColor: Colors.green,
          ),
        );
        // Ніяких додаткових сповіщень для того, хто голосує
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
          content: Text(tr('il_d351acab39')),
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
      // Зважений рейтинг як у відео
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
          SnackBar(content: Text(tr('il_a54a4740b5')), backgroundColor: Colors.red),
        );
        return;
      }
      final submissionId = submission['id'].toString();

      // Уникнути дублю голосів
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

      setState(() { _hasVoted = true; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_c9bfcd4ac3'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
  content: Text(tr('il_a54a4740b5')),
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
      if (userIds.isNotEmpty) {
        final users = await _sb
            .from('profiles')
            .select('id, display_name, email')
            .inFilter('id', userIds);
        for (final raw in users as List<dynamic>) {
          final u = raw as Map<String, dynamic>;
          nameById[u['id'].toString()] = (u['display_name'] ??
                  u['email']?.toString().split('@').first ??
                  tr('il_b764cdc0ea'))
              .toString();
        }
      }

      final comments = <Map<String, dynamic>>[];
      for (final raw in rows) {
        final data = raw as Map<String, dynamic>;
        final authorId = (data['user_id'] ?? '').toString();
        comments.add({
          'id': data['id'],
          'text': data['body'] ?? '',
          'authorName': nameById[authorId] ?? tr('il_b764cdc0ea'),
          'createdAt': data['created_at'],
        });
      }
      
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _autoplayVideos = await UserSettingsService().isAutoplayEnabled();
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      
      await _videoPlayerController.initialize();
      
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
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLike() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return;

      if (_isLiked) {
        // Видаляємо лайк
        await _sb
            .from('video_likes')
            .delete()
            .eq('video_id', widget.videoId)
            .eq('user_id', currentUser.id);
        setState(() {
          _isLiked = false;
          _likesCount = (_likesCount - 1).clamp(0, 1 << 30);
        });
      } else {
        // Додаємо лайк
        await _sb.from('video_likes').upsert({
          'video_id': widget.videoId,
          'user_id': currentUser.id,
        });
        setState(() {
          _isLiked = true;
          _likesCount++;
        });
      }
      final likes = await _sb
          .from('video_likes')
          .select('user_id')
          .eq('video_id', widget.videoId);
      if (mounted) {
        setState(() => _likesCount = (likes as List<dynamic>).length);
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    // Перевірка чи videoId не порожній
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
      
      // Додаємо коментар
      await _sb.from('video_comments').insert({
        'video_id': widget.videoId,
        'user_id': currentUser.id,
        'body': _commentController.text.trim(),
      });
      
      // Очищаємо поле та перезавантажуємо коментарі
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
        return tr('il_adf8ee5f65');
      } else if (difference.inHours > 0) {
        return tr('il_7634d1849f');
      } else if (difference.inMinutes > 0) {
        return tr('il_e0b53645d6');
      } else {
        return tr('il_66f53417d3');
      }
    } catch (e) {
      return tr('il_f81ae5034f');
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged, {bool enabled = true}) {
    final slider = Slider(
      value: value.clamp(0.0, 5.0),
      min: 0.0,
      max: 5.0,
      divisions: 500, // крок ~0.01
      label: value.toStringAsFixed(2),
      onChanged: enabled ? onChanged : null,
      activeColor: const Color(0xFF4caf50),
      inactiveColor: Colors.white24,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white, fontFeatures: []),
              ),
            )
          ],
        ),
        SliderTheme(
          data: const SliderThemeData(thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8)),
          child: slider,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, {
            'ratingUpdated': _hasVoted,
            'videoId': widget.videoId,
          }),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_videoAverageRating != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700)),
                  const SizedBox(width: 4),
                  Text(
                    _videoAverageRating!.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _chewieController != null
          ? SingleChildScrollView(
              child: Column(
                children: [
                  // Video player with fixed aspect ratio
                  AspectRatio(
                    aspectRatio: 9 / 16, // Фіксоване співвідношення для всіх відео
                    child: Chewie(controller: _chewieController!),
                  ),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.08)),
                        bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildActionChip(
                          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                          label: '$_likesCount',
                          color: _isLiked ? Colors.red : Colors.white70,
                          onTap: _toggleLike,
                        ),
                        _buildActionChip(
                          icon: Icons.comment_outlined,
                          label: '${_comments.length}',
                          color: Colors.white70,
                          onTap: () => _showCommentsBottomSheet(),
                        ),
                        if (!_isChallengeSubmission)
                          _buildActionChip(
                            icon: Icons.how_to_vote,
                            label: _hasVoted ? tr('voted') : tr('vote'),
                            color: _hasVoted ? Colors.green : Colors.white70,
                            onTap: () => _showVotingBottomSheet(),
                          ),
                        _buildActionChip(
                          icon: Icons.share_outlined,
                          label: tr('share'),
                          color: Colors.white70,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('il_28a4a65f94'))),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Content below video
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and author
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_videoAuthorId != null)
                          Row(
                            children: [
                              Expanded(
                                child: UserChip(
                                  userId: _videoAuthorId!,
                                  name: _videoAuthorName ?? widget.authorName,
                                  avatarUrl: _videoAuthorAvatar,
                                  showName: true,
                                  onTap: () {
                                    context.router.push(
                                      PlayerProfileRoute(
                                        playerId: _videoAuthorId!,
                                        playerName: _videoAuthorName ?? widget.authorName,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              CompactRatingDisplay(userId: _videoAuthorId!, size: 16),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white54,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr('il_355f79f29d'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Comment input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: tr('il_23c5f33170'),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _addComment();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.send, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF4caf50),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Comments list
            Expanded(
              child: _comments.isEmpty
                  ? Center(
                      child: Text(
                        tr('il_6b25808365'),
                        style: const TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    comment['authorName'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatCommentDate(comment['createdAt']),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                comment['text'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVotingBottomSheet() {
    if (_hasVoted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_56da4f1078'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Title with yellow stripe
                Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.how_to_vote, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          _isChallengeSubmission ? tr('il_8f17154dba') : tr('il_f059de72eb'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Вибір режиму голосування
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => _isAdvancedVoting = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isAdvancedVoting ? const Color(0xFF4caf50) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tr('il_3fee95da5a'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isAdvancedVoting ? Colors.white : Colors.white54,
                                fontWeight: !_isAdvancedVoting ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => _isAdvancedVoting = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isAdvancedVoting ? const Color(0xFF4caf50) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tr('il_9f088dbebd'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isAdvancedVoting ? Colors.white : Colors.white54,
                                fontWeight: _isAdvancedVoting ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Rating sliders
                if (_isAdvancedVoting) ...[
                  _buildSliderRow(tr('il_e851504f43'), _technical, (v) => setModalState(() => _technical = v)),
                  const SizedBox(height: 16),
                  _buildSliderRow(tr('il_1c9fe98ba9'), _creativity, (v) => setModalState(() => _creativity = v)),
                  const SizedBox(height: 16),
                  _buildSliderRow(tr('il_be44133ed5'), _difficulty, (v) => setModalState(() => _difficulty = v)),
                  const SizedBox(height: 16),
                  _buildSliderRow(tr('il_b8c237eb0d'), _quality, (v) => setModalState(() => _quality = v)),
                ] else ...[
                  _buildSliderRow(tr('il_ee62b83057'), _technical, (v) => setModalState(() {
                    _technical = v;
                    _creativity = v;
                    _difficulty = v;
                    _quality = v;
                  })),
                ],
                const SizedBox(height: 24),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmittingVote ? null : () {
                      _submitVote();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4caf50),
                      disabledBackgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isSubmittingVote ? tr('il_64115d5b9c') : tr('il_cd5588db6f'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}