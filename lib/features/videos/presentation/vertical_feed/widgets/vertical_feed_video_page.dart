import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/navigation/flap_navigation.dart';
import 'package:flap_app/core/navigation/flap_route_observer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/videos/domain/entities/library_video.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/double_tap_heart_overlay.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/feed_video_comments_sheet.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/feed_bottom_caption_block.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/feed_dimming_gradients.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/feed_right_actions_column.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/feed_video_vote_sheet.dart';
import 'package:flap_app/utils/i18n.dart';

String _feedUsername(LibraryVideo v) {
  final n = v.authorName.trim();
  if (n.isEmpty) return '@user';
  return n.startsWith('@') ? n : '@$n';
}

String _feedCaption(LibraryVideo v) {
  final t = v.title.trim();
  final d = v.description.trim();
  if (d.isEmpty) return t;
  if (t.isEmpty) return d;
  return '$t\n$d';
}

/// In-memory author avatars (userId → URL, empty string = loaded, no URL).
final Map<String, String> _authorAvatarByUserId = <String, String>{};

class _HeartBurst {
  _HeartBurst({required this.id, required this.position});
  final int id;
  final Offset position;
}

/// One full-screen page: video + gradients + overlays + lifecycle-safe player.
class VerticalFeedVideoPage extends StatefulWidget {
  const VerticalFeedVideoPage({
    super.key,
    required this.video,
    required this.isActive,
    required this.shouldHoldPlayer,
    required this.bottomOverlayPadding,
  });

  final LibraryVideo video;
  final bool isActive;
  final bool shouldHoldPlayer;
  final double bottomOverlayPadding;

  @override
  State<VerticalFeedVideoPage> createState() => _VerticalFeedVideoPageState();
}

class _VerticalFeedVideoPageState extends State<VerticalFeedVideoPage>
    with TickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initFailed = false;
  bool _showPlayIcon = false;
  bool _wasBuffering = false;

  bool _routeObserverRegistered = false;
  TabsRouter? _tabsRouter;
  bool _userPausedManually = false;
  bool _pausedByAppBackground = false;

  late int _likeCount;
  late int _commentCount;
  bool _liked = false;
  StreamSubscription<bool>? _likedSub;
  StreamSubscription<double>? _liveRatingSub;

  /// Whether the signed-in user has submitted a star vote (`null` = still loading).
  bool? _userHasVoted;
  late double _displayAvgRating;
  late int _displayVoteCount;

  bool _loggedView = false;
  int _heartGen = 0;
  final List<_HeartBurst> _hearts = [];

  /// Author profile photo URL; `null` until first resolve for this [widget.video.userId].
  String? _authorAvatarUrl;
  int _avatarLoadGen = 0;

  late final AnimationController _likePop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _likeScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)),
      weight: 55,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.22, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 45,
    ),
  ]).animate(_likePop);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likeCount = widget.video.likes;
    _commentCount = widget.video.commentsCount;
    _displayAvgRating = widget.video.rating;
    _displayVoteCount = widget.video.voteCount;
    _subscribeLikedStream();
    _subscribeLiveVoteAggregate();
    unawaited(_refreshUserVoteFlag());
    if (widget.shouldHoldPlayer) {
      _initPlayer();
    }
    if (widget.isActive) {
      _scheduleViewIncrement();
    }
    _resolveAuthorAvatar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeObserverRegistered) {
      final route = ModalRoute.of(context);
      if (route != null) {
        flapRouteObserver.subscribe(this, route);
        _routeObserverRegistered = true;
      }
    }
    TabsRouter? next;
    try {
      next = AutoTabsRouter.of(context, watch: false);
    } catch (_) {
      next = null;
    }
    if (!identical(next, _tabsRouter)) {
      _tabsRouter?.removeListener(_onTabsRouterChanged);
      _tabsRouter = next;
      _tabsRouter?.addListener(_onTabsRouterChanged);
    }
  }

  void _onTabsRouterChanged() {
    if (!mounted) return;
    _syncPlayback();
  }

  @override
  void didPushNext() {
    _syncPlayback();
  }

  @override
  void didPopNext() {
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.paused) {
      if (c != null && c.value.isInitialized && c.value.isPlaying) {
        _pausedByAppBackground = true;
        unawaited(c.pause());
      }
    } else if (state == AppLifecycleState.resumed && _pausedByAppBackground) {
      _pausedByAppBackground = false;
      _syncPlayback();
    }
  }

  bool _playbackContextAllowsPlay() {
    try {
      if (AutoTabsRouter.of(context, watch: false).activeIndex != FlapMainTab.home) {
        return false;
      }
    } catch (_) {
      // Feed may be used outside the main shell (e.g. embedded); only apply route visibility.
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return true;
  }

  @override
  void didUpdateWidget(covariant VerticalFeedVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _likedSub?.cancel();
      _likeCount = widget.video.likes;
      _commentCount = widget.video.commentsCount;
      _subscribeLikedStream();
      _loggedView = false;
      _displayAvgRating = widget.video.rating;
      _displayVoteCount = widget.video.voteCount;
      _subscribeLiveVoteAggregate();
      unawaited(_refreshUserVoteFlag());
    } else if (oldWidget.video.likes != widget.video.likes) {
      _likeCount = widget.video.likes;
    } else if (oldWidget.video.commentsCount != widget.video.commentsCount) {
      _commentCount = widget.video.commentsCount;
    } else if (oldWidget.video.rating != widget.video.rating ||
        oldWidget.video.voteCount != widget.video.voteCount) {
      _displayAvgRating = widget.video.rating;
      _displayVoteCount = widget.video.voteCount;
    }

    if (oldWidget.shouldHoldPlayer && !widget.shouldHoldPlayer) {
      _disposePlayer();
    } else if (!oldWidget.shouldHoldPlayer && widget.shouldHoldPlayer) {
      _initPlayer();
    } else if (oldWidget.video.videoUrl != widget.video.videoUrl) {
      _disposePlayer();
      if (widget.shouldHoldPlayer) {
        _initPlayer();
      }
    }

    if (!widget.isActive) {
      _loggedView = false;
    } else if (!oldWidget.isActive || !_loggedView) {
      _scheduleViewIncrement();
    }

    _syncPlayback();

    if (oldWidget.video.userId != widget.video.userId) {
      setState(() => _authorAvatarUrl = null);
      _resolveAuthorAvatar();
    } else if (oldWidget.video.id != widget.video.id) {
      _resolveAuthorAvatar();
    }
  }

  void _resolveAuthorAvatar() {
    final userId = widget.video.userId.trim();
    if (userId.isEmpty) {
      if (mounted) setState(() => _authorAvatarUrl = '');
      return;
    }
    if (_authorAvatarByUserId.containsKey(userId)) {
      final cached = _authorAvatarByUserId[userId]!;
      if (_authorAvatarUrl != cached) {
        setState(() => _authorAvatarUrl = cached);
      }
      return;
    }
    final gen = ++_avatarLoadGen;
    unawaited(_fetchAuthorAvatar(userId, gen));
  }

  Future<void> _fetchAuthorAvatar(String userId, int gen) async {
    if (!mounted || gen != _avatarLoadGen) return;
    final profileRepo = context.read<ProfileRepository>();
    try {
      final data = await profileRepo.fetchLegacyUserMap(userId);
      if (!mounted || gen != _avatarLoadGen) return;
      final url = (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString().trim();
      _authorAvatarByUserId[userId] = url;
      setState(() => _authorAvatarUrl = url);
    } catch (_) {
      if (!mounted || gen != _avatarLoadGen) return;
      _authorAvatarByUserId[userId] = '';
      setState(() => _authorAvatarUrl = '');
    }
  }

  void _subscribeLiveVoteAggregate() {
    _liveRatingSub?.cancel();
    _liveRatingSub = context
        .read<VideosRepository>()
        .watchLiveAverageVoteRating(widget.video.id)
        .listen((avg) {
      if (mounted) setState(() => _displayAvgRating = avg);
    });
  }

  Future<void> _refreshUserVoteFlag() async {
    final uid = AppAuthContext.userId;
    if (uid == null) {
      if (mounted) setState(() => _userHasVoted = false);
      return;
    }
    try {
      final v = await context.read<VideosRepository>().userHasVote(
            videoId: widget.video.id,
            userId: uid,
          );
      if (mounted) setState(() => _userHasVoted = v);
    } catch (_) {
      if (mounted) setState(() => _userHasVoted = false);
    }
  }

  Future<void> _reloadVideoAggregates() async {
    try {
      final row =
          await context.read<VideosRepository>().fetchVideo(widget.video.id);
      if (!mounted || row == null) return;
      setState(() {
        _displayAvgRating = row.rating;
        _displayVoteCount = row.voteCount;
      });
    } catch (_) {}
  }

  Future<void> _openVoteSheet() async {
    await showFeedVideoVoteSheet(
      context,
      video: widget.video,
      onVoteSubmitted: () {
        if (!mounted) return;
        setState(() => _userHasVoted = true);
        unawaited(_refreshUserVoteFlag());
        unawaited(_reloadVideoAggregates());
      },
    );
  }

  @override
  void dispose() {
    _tabsRouter?.removeListener(_onTabsRouterChanged);
    _tabsRouter = null;
    if (_routeObserverRegistered) {
      flapRouteObserver.unsubscribe(this);
      _routeObserverRegistered = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    _likedSub?.cancel();
    _liveRatingSub?.cancel();
    _disposePlayer();
    _likePop.dispose();
    super.dispose();
  }

  void _subscribeLikedStream() {
    _likedSub?.cancel();
    final uid = AppAuthContext.userId;
    if (uid == null) {
      _liked = false;
      return;
    }
    _likedSub = context
        .read<VideosRepository>()
        .watchUserLikesVideo(videoId: widget.video.id, userId: uid)
        .listen((v) {
      if (mounted) setState(() => _liked = v);
    });
  }

  void _scheduleViewIncrement() {
    if (_loggedView || !widget.isActive) return;
    _loggedView = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.isActive) return;
      try {
        await context.read<VideosRepository>().incrementViews(widget.video.id);
      } catch (_) {}
    });
  }

  Future<void> _initPlayer() async {
    if (_controller != null) return;
    _initFailed = false;
    final uri = Uri.tryParse(widget.video.videoUrl.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (mounted) setState(() => _initFailed = true);
      return;
    }
    final c = VideoPlayerController.networkUrl(uri);
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      if (_controller != null) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      c.addListener(_onVideoTick);
      setState(() {
        _controller = c;
      });
      _syncPlayback();
    } catch (_) {
      await c.dispose();
      if (mounted) {
        setState(() {
          _initFailed = true;
        });
      }
    }
  }

  void _disposePlayer() {
    final c = _controller;
    _controller = null;
    c?.removeListener(_onVideoTick);
    c?.dispose();
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final buf = c.value.isBuffering;
    if (buf != _wasBuffering) {
      _wasBuffering = buf;
      if (mounted) setState(() {});
    }
  }

  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (!widget.isActive) {
      unawaited(c.pause());
      return;
    }
    if (!_playbackContextAllowsPlay()) {
      unawaited(c.pause());
      return;
    }
    if (_userPausedManually) {
      unawaited(c.pause());
      return;
    }
    unawaited(c.play());
    if (_showPlayIcon && mounted) {
      setState(() => _showPlayIcon = false);
    }
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
      if (!mounted) return;
      setState(() {
        _showPlayIcon = true;
        _userPausedManually = true;
      });
    } else {
      await c.play();
      if (!mounted) return;
      setState(() {
        _showPlayIcon = false;
        _userPausedManually = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final user = AppAuthContext.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Увійдіть, щоб ставити лайки', 'Sign in to like videos')),
        ),
      );
      return;
    }
    final repo = context.read<VideosRepository>();
    final before = _liked;
    try {
      await repo.toggleLike(
        videoId: widget.video.id,
        userId: user.id,
        currentlyLiked: before,
      );
      if (!mounted) return;
      setState(() {
        _liked = !before;
        _likeCount += _liked ? 1 : -1;
      });
      _likePop.forward(from: 0);
      if (mounted && _liked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              I18n.inline(
                'Лайк збережено — разом із оцінками він формує рейтинг відео',
                'Like saved — together with ratings it shapes this video’s score',
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Не вдалося оновити лайк', 'Could not update like')),
        ),
      );
    }
  }

  Future<void> _likeFromDoubleTap() async {
    final user = AppAuthContext.currentUser;
    if (user == null || _liked) return;
    final repo = context.read<VideosRepository>();
    try {
      await repo.toggleLike(
        videoId: widget.video.id,
        userId: user.id,
        currentlyLiked: false,
      );
      if (!mounted) return;
      setState(() {
        _liked = true;
        _likeCount += 1;
      });
    } catch (_) {}
  }

  void _handleDoubleTapDown(TapDownDetails d) {
    setState(() {
      _hearts.add(_HeartBurst(id: _heartGen++, position: d.localPosition));
    });
    if (!_liked) {
      unawaited(_likeFromDoubleTap());
    }
    _likePop.forward(from: 0);
  }

  void _removeHeart(int id) {
    if (!mounted) return;
    setState(() {
      _hearts.removeWhere((e) => e.id == id);
    });
  }

  Future<void> _share() async {
    final u = _feedUsername(widget.video);
    final cap = _feedCaption(widget.video);
    await Share.share('$u — FLAP\n$cap\n${widget.video.videoUrl}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          I18n.inline(
            'Дякуємо за поширення — коментарі та оцінки теж підтримують автора',
            'Thanks for sharing — comments and ratings support the creator too',
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openCommentsSheet() async {
    await showFeedVideoCommentsSheet(
      context,
      videoId: widget.video.id,
      onCommentCountUpdated: (total) {
        if (mounted) setState(() => _commentCount = total);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = _feedUsername(widget.video);
    final caption = _feedCaption(widget.video);
    final avatar = _authorAvatarUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: _buildVideoLayer()),
        const FeedDimmingGradients(),
        if (_showPlayIcon)
          const IgnorePointer(
            child: Center(
              child: Icon(Icons.play_circle_fill, size: 88, color: Colors.white54),
            ),
          ),
        if (_controller != null &&
            _controller!.value.isInitialized &&
            (_controller!.value.isBuffering && widget.isActive))
          const IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _togglePlayPause,
            onDoubleTapDown: _handleDoubleTapDown,
          ),
        ),
        for (final h in _hearts)
          DoubleTapHeartOverlay(
            key: ValueKey('heart-${h.id}'),
            position: h.position,
            onAnimationEnd: () => _removeHeart(h.id),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FeedBottomCaptionBlock(
            username: username,
            description: caption,
            bottomPadding: widget.bottomOverlayPadding,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: _likePop,
            builder: (context, _) {
              return FeedRightActionsColumn(
                avatarUrl: avatar,
                username: username,
                likeCount: _likeCount,
                commentCount: _commentCount,
                isLiked: _liked,
                onLike: () => unawaited(_toggleLike()),
                onVote: () => unawaited(_openVoteSheet()),
                averageRating: _displayAvgRating,
                voteCount: _displayVoteCount,
                hasVoted: _userHasVoted == true,
                onComment: () => unawaited(_openCommentsSheet()),
                onShare: () => unawaited(_share()),
                bottomPadding: widget.bottomOverlayPadding,
                likeScale: _likeScale.value,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoLayer() {
    if (_initFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            I18n.inline(
              'Не вдалося відтворити відео',
              'Could not play video',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white54,
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}

