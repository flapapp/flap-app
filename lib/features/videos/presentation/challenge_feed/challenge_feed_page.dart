import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:flap_app/core/media/cached_video_controller.dart';
import 'package:flap_app/core/media/flap_cached_image.dart';
import 'package:flap_app/core/navigation/flap_navigation.dart';
import 'package:flap_app/core/navigation/flap_route_observer.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_details_bottom_sheet.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_join_flow.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_right_actions_column.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/feed_bottom_caption_block.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/feed_dimming_gradients.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';

String _hostLine(Challenge c) {
  final n = c.creatorName.trim();
  if (n.isEmpty) return '@host';
  return n.startsWith('@') ? n : '@$n';
}

String _caption(Challenge c) {
  final t = c.title.trim();
  final d = c.description.trim();
  if (d.isEmpty) return t;
  if (t.isEmpty) return d;
  return '$t\n$d';
}

/// One full-screen challenge page (mirrors vertical video feed layout).
class ChallengeFeedPage extends StatefulWidget {
  const ChallengeFeedPage({
    super.key,
    required this.challenge,
    required this.isActive,
    required this.shouldHoldPlayer,
    required this.bottomOverlayPadding,
  });

  final Challenge challenge;
  final bool isActive;
  final bool shouldHoldPlayer;
  final double bottomOverlayPadding;

  @override
  State<ChallengeFeedPage> createState() => _ChallengeFeedPageState();
}

class _ChallengeFeedPageState extends State<ChallengeFeedPage>
    with RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initFailed = false;
  bool _showPlayIcon = false;
  bool _wasBuffering = false;

  bool _routeObserverRegistered = false;
  TabsRouter? _tabsRouter;
  bool _userPausedManually = false;
  bool _pausedByAppBackground = false;

  String? _authorAvatarUrl;
  int _avatarLoadGen = 0;

  bool get _joinEnabled {
    final now = DateTime.now();
    final done = widget.challenge.status == ChallengeStatus.completed ||
        now.isAfter(widget.challenge.votingDeadline) ||
        now.isAfter(widget.challenge.endDate);
    return !done;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.shouldHoldPlayer) {
      unawaited(_initPlayer());
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
  void didPushNext() => _syncPlayback();

  @override
  void didPopNext() => _syncPlayback();

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
    } catch (_) {}
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return true;
  }

  @override
  void didUpdateWidget(covariant ChallengeFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shouldHoldPlayer && !widget.shouldHoldPlayer) {
      _disposePlayer();
    } else if (!oldWidget.shouldHoldPlayer && widget.shouldHoldPlayer) {
      unawaited(_initPlayer());
    } else if (oldWidget.challenge.id != widget.challenge.id ||
        oldWidget.challenge.creatorVideoUrl != widget.challenge.creatorVideoUrl) {
      _disposePlayer();
      if (widget.shouldHoldPlayer) {
        unawaited(_initPlayer());
      }
    }
    if (oldWidget.challenge.creatorId != widget.challenge.creatorId) {
      setState(() => _authorAvatarUrl = null);
      _resolveAuthorAvatar();
    } else if (oldWidget.challenge.id != widget.challenge.id) {
      _resolveAuthorAvatar();
    }
    _syncPlayback();
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
    _disposePlayer();
    super.dispose();
  }

  void _resolveAuthorAvatar() {
    final userId = widget.challenge.creatorId.trim();
    if (userId.isEmpty) {
      if (mounted) setState(() => _authorAvatarUrl = '');
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
      setState(() => _authorAvatarUrl = url);
    } catch (_) {
      if (!mounted || gen != _avatarLoadGen) return;
      setState(() => _authorAvatarUrl = '');
    }
  }

  Future<void> _initPlayer() async {
    final raw = widget.challenge.creatorVideoUrl?.trim() ?? '';
    if (raw.isEmpty) {
      if (mounted) setState(() => _initFailed = false);
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (mounted) setState(() => _initFailed = true);
      return;
    }
    if (_controller != null) return;
    _initFailed = false;
    final c = await createCachedVideoController(uri);
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
      setState(() => _controller = c);
      _syncPlayback();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _initFailed = true);
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

  Future<void> _share() async {
    final cap = _caption(widget.challenge);
    final url = widget.challenge.creatorVideoUrl?.trim() ?? '';
    await Share.share('$cap${url.isNotEmpty ? '\n$url' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    final host = _hostLine(widget.challenge);
    final cap = _caption(widget.challenge);
    final thumb = widget.challenge.creatorThumbnailUrl?.trim() ?? '';
    final hasVideo = (widget.challenge.creatorVideoUrl?.trim().isNotEmpty ?? false) &&
        _controller != null &&
        _controller!.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: _buildMediaLayer(thumb, hasVideo)),
        const FeedDimmingGradients(),
        if (_showPlayIcon && hasVideo)
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
            onTap: hasVideo ? _togglePlayPause : null,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FeedBottomCaptionBlock(
            username: host,
            description: cap,
            bottomPadding: widget.bottomOverlayPadding,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: ChallengeRightActionsColumn(
            avatarUrl: _authorAvatarUrl ?? '',
            username: host,
            joinEnabled: _joinEnabled,
            onInfo: () => unawaited(
              showChallengeDetailsBottomSheet(context, challenge: widget.challenge),
            ),
            onJoin: () => showChallengeJoinDialog(context, widget.challenge),
            onShare: () => unawaited(_share()),
            bottomPadding: widget.bottomOverlayPadding,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaLayer(String thumb, bool hasVideo) {
    final url = widget.challenge.creatorVideoUrl?.trim() ?? '';
    if (_initFailed && url.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            I18n.inline('Не вдалося відтворити відео', 'Could not play video'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (url.isNotEmpty && !hasVideo && !_initFailed) {
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
    if (hasVideo) {
      final c = _controller!;
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    }
    if (thumb.isNotEmpty) {
      return FlapCachedImage(
        imageUrl: thumb,
        fit: BoxFit.cover,
        memCacheWidth: 720,
        errorWidget: (_, __, ___) => _placeholderLayer(),
      );
    }
    return _placeholderLayer();
  }

  Widget _placeholderLayer() {
    return ColoredBox(
      color: const Color(0xFF12151c),
      child: Center(
        child: Icon(
          Icons.emoji_events_rounded,
          size: 88,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
