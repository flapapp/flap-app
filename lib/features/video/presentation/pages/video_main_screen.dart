import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../../../../router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import '../../../../core/supabase/supabase_date.dart';
import '../../../../constants/video_categories.dart';
import '../../../challenges/data/models/challenge.dart';
import '../../../challenges/domain/repositories/challenges_repository.dart';
import '../../../challenges/presentation/cubit/challenges_list_cubit.dart';
import '../../../challenges/presentation/cubit/challenges_list_state.dart';
import '../../../../widgets/rating_display.dart';
import '../../../../widgets/video_preview_box.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../widgets/scroll_aware_fab.dart';
import '../../../../core/interactions/interaction_store.dart';
import '../../../notifications/domain/repositories/notifications_repository.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/city_localization.dart';
import '../../../../core/supabase/public_video_feed.dart';
import '../video_feed_sync.dart';

/// Matches [text] against comma-separated legacy variants from [translationKey].
bool _textMatchesCsvVariants(String text, String translationKey) {
  final t = text.trim();
  if (t.isEmpty) return false;
  final csv = tr(translationKey);
  if (csv == translationKey) return false;
  for (final part in csv.split(',')) {
    final p = part.trim();
    if (p.isNotEmpty && p == t) return true;
  }
  return false;
}

@RoutePage()
class VideoMainScreen extends StatefulWidget {
  /// When set, mirrors legacy `arguments: {'myContent': 'videos'|'challenges'}`.
  final String? myContent;

  const VideoMainScreen({super.key, this.myContent});

  @override
  _VideoMainScreenState createState() => _VideoMainScreenState();
}

class _VideoMainScreenState extends State<VideoMainScreen>
    with ScrollAwareFabMixin {
  StreamSubscription<void>? _videoFeedSyncSub;

  final SupabaseClient _sb = Supabase.instance.client;
  NotificationsRepository get _notificationsRepo => sl<NotificationsRepository>();

  RatingsRepository get _ratingRepo => sl<RatingsRepository>();
  String _selectedCity = '';
  final TextEditingController _cityFilterController = TextEditingController();
  String _selectedCategory = '';
  String _selectedRating = '';
  String _selectedSort = 'newest';
  String _selectedTab = 'all'; // all, challenges, trending
  /// Trending tab defaults to views until the user picks another sort.
  bool _trendingUsesViewsSort = true;
  bool _showOnlyMyVideos = false;
  bool _showOnlyMyChallenges = false;
  late final ChallengesListCubit _challengesListCubit;
  String _currentUserCity = '';
  final Map<String, double> _videoRatingCache = {};
  // Most recent feed docs — passed to the player for TikTok-style vertical paging.
  List<Map<String, dynamic>> _currentFeedDocs = const [];
  final Set<String> _videoRatingLoading = {};
  final Map<String, int> _commentCountCache = {};
  final Set<String> _commentCountLoading = {};
  final Map<String, int> _likeCountCache = {};
  final Map<String, bool> _likedByMeCache = {};
  final Set<String> _likeStateLoading = {};
  final Set<String> _likeToggleLoading = {};
  final Map<String, _CachedUserProfile> _userProfileCache = {};
  final Set<String> _loadingUserProfiles = {};
  final Map<String, String?> _challengeCreatorThumbCache = {};
  final Set<String> _challengeCreatorThumbLoading = {};
  int _myVideosRefreshToken = 0;
  String? _cachedAllListKey;
  Future<List<Map<String, dynamic>>>? _cachedAllListFuture;
  String? _cachedTrendingListKey;
  Future<List<Map<String, dynamic>>>? _cachedTrendingListFuture;
  String? _cachedMyListKey;
  Future<List<Map<String, dynamic>>>? _cachedMyListFuture;
  bool _didInitFromRouteArgs = false;

  /// Invalidates memoized feed futures so [FutureBuilder]s refetch after upload/delete.
  void _invalidateVideoFeedCaches() {
    if (!mounted) return;
    setState(() {
      _myVideosRefreshToken++;
      _cachedAllListKey = null;
      _cachedAllListFuture = null;
      _cachedTrendingListKey = null;
      _cachedTrendingListFuture = null;
      _cachedMyListKey = null;
      _cachedMyListFuture = null;
    });
  }

  void _applyVideoFilterChange(VoidCallback update) {
    if (!mounted) return;
    setState(() {
      update();
      _cachedAllListKey = null;
      _cachedAllListFuture = null;
      _cachedTrendingListKey = null;
      _cachedTrendingListFuture = null;
    });
  }

  List<String> get _cities => [
    tr('all_cities'),
    tr('kyiv'),
    tr('lviv'),
    tr('odesa'),
    tr('kharkiv'),
    tr('dnipro'),
  ];

  List<String> get _ratings => [
    tr('il_a90e7e92a6'),
    '4.0+',
    '4.5+',
  ];

  static const List<String> _sortModes = <String>[
    'newest',
    'my_city',
    'rating_asc',
    'rating_desc',
  ];

  String _sortLabel(String mode) {
    switch (mode) {
      case 'my_city':
        return tr('il_fd59d53cdc');
      case 'rating_asc':
        return tr('il_fc19488e61');
      case 'rating_desc':
        return tr('il_dde723aee1');
      case 'newest':
      default:
        return tr('il_ffb6f5764b');
    }
  }

  String _selectedCategoryLabel() {
    if (_selectedCategory.isEmpty) {
      return tr('il_9d5097a837');
    }
    return videoCategoryById(_selectedCategory)?.label() ??
        videoCategoryLabel(_selectedCategory);
  }

  void _prefetchChallengeCreatorThumbnail(String challengeId, String creatorId) async {
    if (challengeId.isEmpty || creatorId.isEmpty) return;
    if (_challengeCreatorThumbCache.containsKey(challengeId) ||
        _challengeCreatorThumbLoading.contains(challengeId)) {
      return;
    }
    _challengeCreatorThumbLoading.add(challengeId);
    try {
      String? thumbUrl;
      final ch = await _sb
          .from('challenges')
          .select('video_thumbnail_url')
          .eq('id', challengeId)
          .maybeSingle();
      thumbUrl = (ch?['video_thumbnail_url'] ?? '').toString().trim();
      if (thumbUrl.isEmpty) {
        final directData = await _sb
            .from('challenge_submissions')
            .select('thumbnail_url')
            .eq('challenge_id', challengeId)
            .eq('user_id', creatorId)
            .maybeSingle();
        thumbUrl = (directData?['thumbnail_url'] ?? '').toString().trim();
      }

      if (thumbUrl.isEmpty) {
        final fallback = await _sb
            .from('challenge_submissions')
            .select('thumbnail_url')
            .eq('challenge_id', challengeId)
            .limit(1);
        final rows = fallback as List<dynamic>;
        if (rows.isNotEmpty) {
          thumbUrl = (((rows.first as Map<String, dynamic>)['thumbnail_url']) ?? '')
              .toString()
              .trim();
        }
      }

      _challengeCreatorThumbCache[challengeId] =
          thumbUrl.isEmpty ? null : thumbUrl;
      if (mounted) setState(() {});
    } catch (_) {
      _challengeCreatorThumbCache[challengeId] = null;
    } finally {
      _challengeCreatorThumbLoading.remove(challengeId);
    }
  }

  void _loadChallengesList() {
    final onlyMine = _showOnlyMyChallenges ? AppAuth.currentUserId : null;
    unawaited(
      _challengesListCubit.load(onlyCreatorUserId: onlyMine, limit: 20),
    );
  }

  Future<void> _settleDueChallengesThenLoad() async {
    try {
      await sl<ChallengesRepository>().checkAndFinishChallenges();
    } catch (_) {
      // Best-effort; the cron sweep is the authoritative path.
    }
    if (mounted) _loadChallengesList();
  }

  @override
  void initState() {
    super.initState();
    _challengesListCubit = ChallengesListCubit(sl<ChallengesRepository>());
    // Settle any challenge whose voting window has closed, then load the list
    // so freshly-completed challenges show their final state. A pg_cron job
    // does the same server-side every minute; this is just an immediacy nudge.
    _settleDueChallengesThenLoad();
    _videoFeedSyncSub = sl<VideoFeedSync>().onMutated.listen((_) {
      if (mounted) {
        _invalidateVideoFeedCaches();
        _loadChallengesList();
      }
    });
    _cityFilterController.text = '';
    _loadCurrentUserCity();
  }

  @override
  void dispose() {
    _videoFeedSyncSub?.cancel();
    _challengesListCubit.close();
    _cityFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserCity() async {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    try {
      final row = await _sb
          .from('profiles')
          .select('city')
          .eq('id', uid)
          .maybeSingle();
      final city = (row?['city'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _currentUserCity = city;
      });
    } catch (_) {}
  }

  String _resolveVideoCategoryCode(Map<String, dynamic> data) {
    return normalizeVideoCategoryValue(
      (data['category'] ?? data['category_code'] ?? '').toString().trim(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitFromRouteArgs) return;
    _didInitFromRouteArgs = true;

    String? myContent = widget.myContent;
    if (myContent == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['myContent'] is String) {
        myContent = args['myContent'] as String;
      }
    }
    if (myContent == 'videos' || myContent == 'challenges') {
      _showOnlyMyVideos = myContent == 'videos';
      _showOnlyMyChallenges = myContent == 'challenges';
      _selectedTab = _showOnlyMyChallenges ? 'challenges' : 'all';
      _loadChallengesList();
    }
  }

  @override
Widget build(BuildContext context) {
  // Subscribe to the active locale so this screen re-localizes instantly when
  // the language is switched. `tr()` does not register a dependency on the
  // locale, and this screen lives in the always-alive tab-shell IndexedStack.
  context.locale;
  return BlocProvider.value(
    value: _challengesListCubit,
    child: Scaffold(
    backgroundColor: const Color(0xFF0E1310), // Dark background (HTML MVP style)
    appBar: AppBar(
      backgroundColor: const Color(0xFF0E1310).withValues(alpha: 0.95),
      elevation: 0,
      titleSpacing: 4,
      centerTitle: false,
      title: Text(
        tr('videos'),
        style: FlapText.sora(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      actions: [
        // Upload
        // _appBarGlassButton(
        //   tooltip: tr('upload_video'),
        //   onTap: () async {
        //     await context.router.push(VideoUploadRoute());
        //     if (!mounted) return;
        //     _invalidateVideoFeedCaches();
        //   },
        //   child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        // ),

        // Filters
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _appBarGlassButton(
            tooltip: tr('video_filters_title'),
            onTap: _showVideoFiltersSheet,
            child: const Icon(Icons.tune_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ],
    ),
    body: scrollAwareBody(SafeArea(
      child: Column(
        children: [
          // Tabs
          if (!_showOnlyMyVideos && !_showOnlyMyChallenges)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _buildTab(tr('all'), 'all'),
                  _buildTab(tr('challenges'), 'challenges'),
                  _buildTab(tr('il_5e1a0ebc93'), 'trending'),
                ],
              ),
            ),

          // Category chips (videos and trends only)
          if (_selectedTab != 'challenges' &&
              !_showOnlyMyVideos &&
              !_showOnlyMyChallenges)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: _buildVideoCategoryChips(),
            ),

          // Content based on selected tab
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCurrentTab,
              color: FlapColors.greenBright,
              backgroundColor: FlapColors.card,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    )),
    floatingActionButton: scrollAwareFab(FlapCreateFab(
      tooltip: tr('il_4759498ac2'),
      onTap: _showVideoCreateSheet,
    )),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    ),
  );
}

  void _showVideoCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10160F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: Colors.white),
              title: Text(tr('upload_video'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await context.router.push(VideoUploadRoute());
                _invalidateVideoFeedCaches();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined,
                  color: Colors.white),
              title: Text(tr('create_challenge'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                context.router.push(const ChallengeCreateRoute());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoChip(
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: chip,
    );
  }

  Color _videoCategoryColor(String category) => videoCategoryColor(category);

  bool _isUnknownLabel(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.isEmpty) return true;
    for (final token in tr('unknown_label_aliases').split(',')) {
      final t = token.trim().toLowerCase();
      if (t.isNotEmpty && normalized == t) return true;
    }
    return normalized == tr('unknown').toLowerCase() ||
        normalized == tr('unknown_city').toLowerCase();
  }

  Color _challengeTypeColor(String type) {
    switch (parseChallengeType(type)) {
      case ChallengeType.goal:
        return const Color(0xFFFF7043);
      case ChallengeType.shotPower:
        return const Color(0xFFD84315);
      case ChallengeType.pass:
        return const Color(0xFF66BB6A);
      case ChallengeType.longPass:
        return const Color(0xFF26C6DA);
      case ChallengeType.dribbling:
        return const Color(0xFFAB47BC);
      case ChallengeType.tackle:
        return const Color(0xFF8D6E63);
      case ChallengeType.defending:
        return const Color(0xFF607D8B);
      case ChallengeType.penalty:
        return const Color(0xFFFFC107);
      case ChallengeType.save:
        return const Color(0xFF42A5F5);
      case ChallengeType.wall:
        return const Color(0xFF455A64);
      case ChallengeType.strategy:
        return const Color(0xFF26A69A);
      case ChallengeType.trick:
        return const Color(0xFFFFCA28);
      case ChallengeType.other:
        return const Color(0xFF78909C);
    }
  }

  Widget _buildRatingBadge(String? ratingText) {
    final hasRating = ratingText != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
          const SizedBox(width: 4),
          Text(
            ratingText ?? tr('il_936f84ca44'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: hasRating ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _prefetchVideoRating(String videoId) async {
    if (_videoRatingCache.containsKey(videoId) ||
        _videoRatingLoading.contains(videoId)) {
      return;
    }
    _videoRatingLoading.add(videoId);
    try {
      final votesSnap = await _sb
          .from('video_ratings')
          .select('overall_rating')
          .eq('video_id', videoId);
      final rows = votesSnap as List<dynamic>;
      double sum = 0.0;
      for (final raw in rows) {
        final data = raw as Map<String, dynamic>;
        sum += ((data['overall_rating'] ?? 0.0) as num).toDouble();
      }
      final avg = rows.isEmpty
          ? 0.0
          : double.parse((sum / rows.length).toStringAsFixed(2));
      if (mounted) {
        setState(() {
          _videoRatingCache[videoId] = avg;
        });
      }
      sl<InteractionStore>()
          .mergeContent(videoId, ratingAvg: avg, voteCount: rows.length);
    } catch (_) {
      // ignore
    } finally {
      _videoRatingLoading.remove(videoId);
    }
  }

  void _prefetchCommentCount(String videoId) async {
    if (_commentCountCache.containsKey(videoId) ||
        _commentCountLoading.contains(videoId)) {
      return;
    }
    _commentCountLoading.add(videoId);
    try {
      final rows = await _sb
          .from('video_comments')
          .select('id')
          .eq('video_id', videoId);
      final count = (rows as List<dynamic>).length;
      if (mounted) {
        setState(() {
          _commentCountCache[videoId] = count;
        });
      }
      sl<InteractionStore>().mergeContent(videoId, commentCount: count);
    } catch (_) {
      // ignore
    } finally {
      _commentCountLoading.remove(videoId);
    }
  }

  void _prefetchLikeState(String videoId) async {
    final uid = AppAuth.currentUserId;
    if (uid == null ||
        _likedByMeCache.containsKey(videoId) ||
        _likeStateLoading.contains(videoId) ||
        _likeToggleLoading.contains(videoId)) {
      return;
    }
    _likeStateLoading.add(videoId);
    try {
      // Fetch all likers so we can seed both the count and the per-user state.
      final rows = await _sb
          .from('video_likes')
          .select('user_id')
          .eq('video_id', videoId);
      final likers = rows as List<dynamic>;
      final likeCount = likers.length;
      final likedByMe =
          likers.any((r) => (r as Map<String, dynamic>)['user_id'] == uid);
      if (mounted) {
        setState(() {
          _likedByMeCache[videoId] = likedByMe;
          _likeCountCache[videoId] = likeCount;
        });
      }
      sl<InteractionStore>()
          .mergeContent(videoId, likeCount: likeCount, likedByMe: likedByMe);
    } catch (_) {
      // ignore transient errors; keep feed usable
    } finally {
      _likeStateLoading.remove(videoId);
    }
  }

  void _prefetchUserProfile(String userId) async {
    if (userId.isEmpty ||
        _userProfileCache.containsKey(userId) ||
        _loadingUserProfiles.contains(userId)) {
      return;
    }
    _loadingUserProfiles.add(userId);
    try {
      final data = await _sb
              .from('profiles')
              .select('display_name,first_name,last_name,avatar_url,city,email')
              .eq('id', userId)
              .maybeSingle() ??
          const <String, dynamic>{};
      final resolvedName = (data['display_name'] ??
              '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim() ??
              data['email']?.toString().split('@').first)
          .toString()
          .trim();
      final avatar = (data['avatar_url'] ?? '').toString();
      final profileCity = (data['city'] ?? '').toString();
      if (mounted) {
        setState(() {
          _userProfileCache[userId] = _CachedUserProfile(
            name: resolvedName.isNotEmpty
                ? resolvedName
                : tr('il_b512d97e7c'),
            avatarUrl: avatar,
            city: profileCity,
          );
        });
      }
    } catch (_) {
      // ignore
    } finally {
      _loadingUserProfiles.remove(userId);
    }
  }

  Future<void> _showRateVideoSheet({
    required String videoId,
    required String videoTitle,
  }) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_4afcf6b419')),
        ),
      );
      return;
    }

    try {
      final videoRow = await _sb
          .from('videos')
          .select('user_id')
          .eq('id', videoId)
          .maybeSingle();
      final ownerId = videoRow?['user_id']?.toString();
      if (ownerId != null && ownerId == currentUser.id) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_11bedab9bb'))),
        );
        return;
      }
    } catch (_) {}

    try {
      final existingVote = await _sb
          .from('video_ratings')
          .select('id')
          .eq('video_id', videoId)
          .eq('rated_by', currentUser.id)
          .maybeSingle();
      if (existingVote != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_908b4d0670')),
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;

    double overall = 3.0;
    double technical = 3.0;
    double creativity = 3.0;
    double difficulty = 3.0;
    double quality = 3.0;
    bool advanced = false;
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10160F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Widget sliderTile(
            String label,
            double value,
            ValueChanged<double> onChanged,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: value,
                  min: 0,
                  max: 5,
                  divisions: 500,
                  label: value.toStringAsFixed(2),
                  activeColor: const Color(0xFFFFC107),
                  onChanged: onChanged,
                ),
              ],
            );
          }

          Future<void> submitVote() async {
            if (submitting) return;
            setModalState(() => submitting = true);
            final criteria = advanced
                ? <String, double>{
                    'technical': technical,
                    'creativity': creativity,
                    'difficulty': difficulty,
                    'quality': quality,
                  }
                : <String, double>{
                    'technical': overall,
                    'creativity': overall,
                    'difficulty': overall,
                    'quality': overall,
                  };
            try {
              final success = await _ratingRepo.rateVideo(
                videoId: videoId,
                ratedBy: currentUser.id,
                criteria: criteria,
              );
              if (!mounted) return;
              if (success) {
                Navigator.pop(sheetContext);
                setState(() {
                  _videoRatingCache.remove(videoId);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('il_1a564b1a48')),
                  ),
                );
                _prefetchVideoRating(videoId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('il_45561ed8d8')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            } finally {
              if (mounted) {
                setModalState(() => submitting = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    tr('il_f059de72eb'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    videoTitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => advanced = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !advanced
                                    ? const Color(0xFF4caf50)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tr('il_3fee95da5a'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !advanced
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: !advanced
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => advanced = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: advanced
                                    ? const Color(0xFF4caf50)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tr('il_9f088dbebd'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: advanced
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: advanced
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (advanced) ...[
                    sliderTile(tr('il_e851504f43'), technical,
                        (v) => setModalState(() => technical = v)),
                    sliderTile(
                        tr('il_1c9fe98ba9'),
                        creativity,
                        (v) => setModalState(() => creativity = v)),
                    sliderTile(
                        tr('il_be44133ed5'),
                        difficulty,
                        (v) => setModalState(() => difficulty = v)),
                    sliderTile(
                        tr('il_b8c237eb0d'),
                        quality,
                        (v) => setModalState(() => quality = v)),
                  ] else ...[
                    sliderTile(
                      tr('il_ee62b83057'),
                      overall,
                      (v) => setModalState(() => overall = v),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: submitting ? null : submitVote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        disabledBackgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        submitting
                            ? tr('il_64115d5b9c')
                            : tr('il_32944f26fb'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoCategoryChips() {
    final entries = <MapEntry<String, String>>[
      MapEntry('', tr('il_9d5097a837')), // All
      ...kVideoCategories.map((c) => MapEntry(c.id, c.label())),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final e = entries[index];
          final selected = _selectedCategory == e.key;
          return GestureDetector(
            onTap: () => _applyVideoFilterChange(() {
              _selectedCategory = selected ? '' : e.key;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? FlapColors.green.withValues(alpha: 0.16)
                    : FlapColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected
                      ? FlapColors.green.withValues(alpha: 0.5)
                      : FlapColors.border,
                ),
              ),
              child: Text(
                e.value,
                style: FlapText.sora(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? FlapColors.greenBright : FlapColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _appBarGlassButton({
    required Widget child,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    Widget btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: FlapColors.border),
        ),
        child: child,
      ),
    );
    if (tooltip != null) {
      btn = Tooltip(message: tooltip, child: btn);
    }
    return Padding(padding: const EdgeInsets.only(left: 8), child: btn);
  }

  Widget _buildTab(String title, String tab) {
    final isActive = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
      onTap: () {
        if (_selectedTab == tab) return;
        setState(() {
          _selectedTab = tab;
          if (tab == 'trending') {
            _trendingUsesViewsSort = true;
            _cachedTrendingListKey = null;
            _cachedTrendingListFuture = null;
          }
        });
      },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            color: isActive ? FlapColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
        ),
        child: Text(
          title,
            textAlign: TextAlign.center,
          style: FlapText.sora(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? FlapColors.text : FlapColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    List<String> items,
    String selectedValue,
    Function(String) onChanged,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: FlapColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlapColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          dropdownColor: FlapColors.card,
          iconEnabledColor: FlapColors.muted,
          borderRadius: BorderRadius.circular(12),
          style: FlapText.sora(fontSize: 13.5, color: FlapColors.text),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: FlapColors.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown({VoidCallback? afterChange}) {
    return Container(
      decoration: BoxDecoration(
        color: FlapColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlapColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSort,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          dropdownColor: FlapColors.card,
          iconEnabledColor: FlapColors.muted,
          borderRadius: BorderRadius.circular(12),
          style: FlapText.sora(fontSize: 13.5, color: FlapColors.text),
          items: _sortModes
              .map(
                (mode) => DropdownMenuItem<String>(
                  value: mode,
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert_rounded,
                          size: 16, color: FlapColors.muted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_sortLabel(mode))),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (String? mode) {
            if (mode == null) return;
            _applyVideoFilterChange(() {
              _selectedSort = mode;
              if (_selectedTab == 'trending') {
                _trendingUsesViewsSort = false;
              }
            });
            afterChange?.call();
          },
        ),
      ),
    );
  }

  void _showVideoFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FlapColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          tr('video_filters_title'),
                          style: FlapText.sora(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            _applyVideoFilterChange(() {
                              _selectedCity = '';
                              _cityFilterController.text = '';
                              _selectedRating = '';
                              _selectedSort = _sortModes.first;
                            });
                            setSheet(() {});
                          },
                          child: Text(
                            tr('video_filters_reset'),
                            style: FlapText.sora(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: FlapColors.greenBright),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _filterFieldLabel(tr('video_filter_city')),
                    CityAutocompleteField(
                      controller: _cityFilterController,
                      label: '',
                      hint: tr('il_ada640060a'),
                      includeAllOption: true,
                      requiredField: false,
                      style:
                          FlapText.sora(fontSize: 13.5, color: FlapColors.text),
                      labelStyle:
                          FlapText.sora(fontSize: 13, color: FlapColors.muted),
                      filled: true,
                      fillColor: FlapColors.surface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlapColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlapColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlapColors.green),
                      ),
                      prefixIcon: const Icon(Icons.location_city,
                          color: FlapColors.muted, size: 18),
                      onSelected: (value) {
                        final v = value.trim();
                        final allValues = <String>{
                          tr('all_cities').toLowerCase(),
                          tr('filter_all_cities_alt').toLowerCase(),
                        };
                        if (v.isEmpty) {
                          _applyVideoFilterChange(() {
                            _selectedCity = '';
                            _cityFilterController.text = '';
                          });
                          setSheet(() {});
                          return;
                        }
                        final isAll = allValues.contains(v.toLowerCase());
                        _applyVideoFilterChange(() {
                          _selectedCity = isAll ? '' : v;
                          _cityFilterController.text = isAll ? '' : v;
                          _cityFilterController.selection =
                              TextSelection.collapsed(
                            offset: _cityFilterController.text.length,
                          );
                        });
                        setSheet(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    _filterFieldLabel(tr('video_filter_rating')),
                    _buildFilterDropdown(
                      _ratings,
                      _selectedRating.isEmpty
                          ? tr('il_a90e7e92a6')
                          : _selectedRating,
                      (value) {
                        _applyVideoFilterChange(() {
                          _selectedRating =
                              value == tr('il_a90e7e92a6') ? '' : value;
                        });
                        setSheet(() {});
                      },
                      Icons.star_rounded,
                    ),
                    const SizedBox(height: 16),
                    _filterFieldLabel(tr('video_filter_sort')),
                    _buildSortDropdown(afterChange: () => setSheet(() {})),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: FlapText.sora(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: FlapColors.muted),
      ),
    );
  }

  String get _videoFeedFilterKey => [
        _showOnlyMyVideos,
        _showOnlyMyChallenges,
        _selectedCategory,
        _selectedCity,
        _selectedRating,
        _selectedSort,
        _currentUserCity,
        _myVideosRefreshToken,
      ].join('|');

  double? _minRatingParam() {
    if (_selectedRating.isEmpty) {
      return null;
    }
    if (_selectedRating == tr('il_a90e7e92a6')) {
      return null;
    }
    final p = double.tryParse(_selectedRating.replaceAll('+', ''));
    if (p == null || p <= 0) {
      return null;
    }
    return p;
  }

  String? _cityKeyForFeed() {
    return videoFeedCityKey(
      _selectedCity,
      allCitiesValue: tr('all_cities'),
    );
  }

  List<String> _categoryCodesForFilter() {
    if (_selectedCategory.isEmpty) {
      return <String>[];
    }
    return <String>[normalizeVideoCategoryValue(_selectedCategory)];
  }

  VideoFeedSort _mapSortForFeed({bool forTrending = false}) {
    if (forTrending && _trendingUsesViewsSort) {
      return VideoFeedSort.viewsDesc;
    }
    switch (_selectedSort) {
      case 'my_city':
        if (_currentUserCity.trim().isEmpty) {
          return VideoFeedSort.newest;
        }
        return VideoFeedSort.myCity;
      case 'rating_asc':
        return VideoFeedSort.ratingAsc;
      case 'rating_desc':
        return VideoFeedSort.ratingDesc;
      case 'newest':
      default:
        return VideoFeedSort.newest;
    }
  }

  VideoFeedParams _defaultFeedParams() {
    return VideoFeedParams(
      onlyUserId: null,
      categoryCodes: _categoryCodesForFilter(),
      minAvgRating: _minRatingParam(),
      cityKey: _cityKeyForFeed(),
      excludeChallengeRelated: true,
      sort: _mapSortForFeed(),
      limit: 400,
    );
  }

  VideoFeedParams _myVideosFeedParams() {
    return VideoFeedParams(
      onlyUserId: AppAuth.currentUserId,
      categoryCodes: _categoryCodesForFilter(),
      minAvgRating: _minRatingParam(),
      cityKey: _cityKeyForFeed(),
      excludeChallengeRelated: true,
      sort: _mapSortForFeed(),
      limit: 400,
    );
  }

  Future<List<Map<String, dynamic>>> _loadFeedForMyList() {
    return getVideosFromDatabase(_sb, _myVideosFeedParams());
  }

  /// Stable future per filter set so [FutureBuilder] is not re-started every frame.
  Future<List<Map<String, dynamic>>> _memoizedAllListFuture() {
    final k = 'all-$_videoFeedFilterKey';
    if (_cachedAllListKey == k && _cachedAllListFuture != null) {
      return _cachedAllListFuture!;
    }
    _cachedAllListKey = k;
    return _cachedAllListFuture = getVideosFromDatabase(
      _sb,
      _defaultFeedParams(),
    );
  }

  VideoFeedParams _trendingFeedParams() {
    return VideoFeedParams(
      onlyUserId: null,
      categoryCodes: _categoryCodesForFilter(),
      minAvgRating: _minRatingParam(),
      cityKey: _cityKeyForFeed(),
      excludeChallengeRelated: true,
      sort: _mapSortForFeed(forTrending: true),
      limit: 400,
    );
  }

  String get _trendingFeedFilterKey => [
        _showOnlyMyVideos,
        _showOnlyMyChallenges,
        _selectedCategory,
        _selectedCity,
        _selectedRating,
        _trendingUsesViewsSort ? 'views' : _selectedSort,
        _currentUserCity,
        _myVideosRefreshToken,
      ].join('|');

  Future<List<Map<String, dynamic>>> _memoizedTrendingListFuture() {
    final k = 'trending-$_trendingFeedFilterKey';
    if (_cachedTrendingListKey == k && _cachedTrendingListFuture != null) {
      return _cachedTrendingListFuture!;
    }
    _cachedTrendingListKey = k;
    return _cachedTrendingListFuture = getVideosFromDatabase(
      _sb,
      _trendingFeedParams(),
    );
  }

  Future<List<Map<String, dynamic>>> _memoizedMyListFuture() {
    final k = 'my-$_videoFeedFilterKey';
    if (_cachedMyListKey == k && _cachedMyListFuture != null) {
      return _cachedMyListFuture!;
    }
    _cachedMyListKey = k;
    return _cachedMyListFuture = _loadFeedForMyList();
  }

  /// Re-fetches the currently visible tab from the server. Returns a future
  /// that completes when the fresh data has loaded so [RefreshIndicator] keeps
  /// its spinner up for the duration. Errors are swallowed so the gesture
  /// always resolves (the tab's own error state renders the failure).
  Future<void> _refreshCurrentTab() async {
    if (!mounted) return;

    // Challenges (both the tab and the "my challenges" entry mode) reload via
    // the cubit, which the BlocBuilder reflects automatically.
    if (_showOnlyMyChallenges || _selectedTab == 'challenges') {
      final onlyMine = _showOnlyMyChallenges ? AppAuth.currentUserId : null;
      await _challengesListCubit.load(onlyCreatorUserId: onlyMine, limit: 20);
      return;
    }

    // Video feeds are FutureBuilder-driven: drop the cached future, build a
    // fresh one, rebuild so the FutureBuilder picks it up, then await it.
    late final Future<List<Map<String, dynamic>>> pending;
    if (_showOnlyMyVideos) {
      _cachedMyListKey = null;
      _cachedMyListFuture = null;
      pending = _memoizedMyListFuture();
    } else if (_selectedTab == 'trending') {
      _cachedTrendingListKey = null;
      _cachedTrendingListFuture = null;
      pending = _memoizedTrendingListFuture();
    } else {
      _cachedAllListKey = null;
      _cachedAllListFuture = null;
      pending = _memoizedAllListFuture();
    }
    setState(() {});
    try {
      await pending;
    } catch (_) {
      // Surfaced by the tab's error state; nothing else to do here.
    }
  }

  /// Makes a non-scrolling state (empty / error message) respond to the
  /// pull-to-refresh gesture — [RefreshIndicator] only fires when it has a
  /// scrollable descendant that can overscroll.
  Widget _pullable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }

  Widget _buildContent() {
  if (_showOnlyMyVideos) {
    return _buildMyVideosList();
  }
  if (_showOnlyMyChallenges) {
    return _buildChallengesList();
  }

  switch (_selectedTab) {
    case 'challenges':
      return _buildChallengesList();
    case 'trending':
      return _buildTrendingVideos();
    default:
      return _buildVideosList();
  }
}

  Widget _buildVideosList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey<String>(
        'vm-feed-$_videoFeedFilterKey',
      ),
      future: _memoizedAllListFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildVideoGridSkeleton();
        }

        if (snapshot.hasError) {
          return _pullable(Center(
            child: Text(
              tr(
                'il_24ffa7c8c5',
                args: [snapshot.error?.toString() ?? ''],
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ));
        }

        final docs = snapshot.data ?? const <Map<String, dynamic>>[];
        _currentFeedDocs = docs; // used as the TikTok-style player playlist
        if (docs.isEmpty) {
          return _pullable(Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  tr('il_7b1fd32345'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('il_9ee4c85bbb'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await context.router.push(VideoUploadRoute());
                    if (!mounted) return;
                    _invalidateVideoFeedCaches();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    tr('upload_video'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ));
        }

        return GridView.builder(
          key: PageStorageKey<String>(
            'videos-grid-$_selectedTab-${_showOnlyMyVideos ? "mine" : "all"}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 9 / 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            return _buildVideoCard(data, (data['id'] ?? '').toString());
          },
        );
      },
    );
  }

  Widget _buildVideoGridSkeleton() {
    return FlapShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 9 / 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const FlapSkeletonBox(
          width: double.infinity,
          height: double.infinity,
          radius: 18,
        ),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> data, String videoId) {
    final rawTitle = (data['title'] ?? '').toString();
    final title = rawTitle.isEmpty ? tr('il_f59ab8d133') : rawTitle;

    final ratingRaw =
        data['rating'] ?? data['averageRating'] ?? data['voteAverage'] ?? 0.0;
    final double rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw.toString()) ?? 0.0;
    final cachedRating = _videoRatingCache[videoId];
    if (cachedRating == null &&
        rating <= 0 &&
        !_videoRatingLoading.contains(videoId)) {
      _prefetchVideoRating(videoId);
    }

    final likes = (data['likes'] ?? 0) as num;
    final cachedLikes = _likeCountCache[videoId];
    // Display values prefer the centralized store (reactive across screens),
    // falling back to the per-screen cache / feed payload until it loads.
    final fallbackRating = cachedRating ?? rating;
    final fallbackLikes = cachedLikes ?? likes.toInt();

    String authorDisplayName = (data['authorName'] ??
            data['displayName'] ??
            data['userName'] ??
            tr('il_b764cdc0ea'))
        .toString();
    final authorId = data['userId'] as String?;
    String? authorAvatar;
    if (authorId != null && authorId.isNotEmpty) {
      final cachedProfile = _userProfileCache[authorId];
      if (cachedProfile != null) {
        authorDisplayName = cachedProfile.name;
        authorAvatar = cachedProfile.avatarUrl;
      } else {
        _prefetchUserProfile(authorId);
      }
    }

    final videoUrl = (data['videoUrl'] ?? '').toString();
    final thumbnailUrl = data['thumbnailUrl']?.toString();
    final durationSeconds =
        data['duration'] is int ? data['duration'] as int : null;
    final durationText =
        durationSeconds != null ? _formatDuration(durationSeconds) : null;
    final trimmedName = authorDisplayName.trim();
    final firstName = trimmedName.isEmpty
        ? authorDisplayName
        : trimmedName.split(RegExp(r'\s+')).first;

    return ValueListenableBuilder<ContentInteraction>(
      valueListenable: sl<InteractionStore>().watchVideo(videoId),
      builder: (context, ci, _) {
        final double displayRating =
            (ci.loaded && ci.ratingAvg > 0) ? ci.ratingAvg : fallbackRating;
        final int displayLikes = ci.loaded ? ci.likeCount : fallbackLikes;
        return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openVideo(
        videoId: videoId,
        videoUrl: videoUrl,
        title: title,
        authorName: authorDisplayName,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlapColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPreviewBox(
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                aspectRatio: 9 / 16,
                borderRadius: 18,
                showPlayIcon: false,
                placeholderColor: const Color(0xFF0D1A15),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF070A08).withValues(alpha: 0.9),
                      ],
                      stops: const [0.34, 1.0],
                    ),
                  ),
                ),
              ),
              if (displayRating > 0)
                Positioned(
                    top: 10, left: 10, child: _vcardRating(displayRating)),
              if (durationText != null)
                Positioned(
                    top: 10, right: 10, child: _vcardDuration(durationText)),
              Positioned(
                left: 11,
                right: 11,
                bottom: 11,
                child:
                    _vcardCaption(title, firstName, authorAvatar, displayLikes),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _vcardRating(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FlapColors.gold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 11, color: FlapColors.onGreen),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(2),
            style: FlapText.sora(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FlapColors.onGreen),
          ),
        ],
      ),
    );
  }

  Widget _vcardDuration(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: FlapText.sora(
            fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }

  Widget _vcardCaption(
      String title, String firstName, String? avatarUrl, int likes) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FlapText.sora(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)
              .copyWith(height: 1.22),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _vcardAvatar(avatarUrl, firstName),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FlapText.sora(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFCDD4CE)),
              ),
            ),
            const Icon(Icons.favorite, size: 12, color: Color(0xFFCDD4CE)),
            const SizedBox(width: 4),
            Text(
              _compactCount(likes),
              style: FlapText.sora(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFCDD4CE)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vcardAvatar(String? avatarUrl, String name) {
    final hasImg = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FlapColors.green,
        image: hasImg
            ? DecorationImage(
                image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImg
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
    );
  }

  String _compactCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _buildChallengeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.black87, size: 14),
          const SizedBox(width: 4),
          Text(
            tr('il_27cf1792f7'),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color background = Colors.white12,
    Color iconColor = Colors.white,
    String? tooltip,
    String? trailing,
  }) {
    final content = Container(
      padding: trailing != null
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            Text(
              trailing!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    final button = InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onPressed,
      child: content,
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }

  Future<void> _openVideo({
    required String videoId,
    required String videoUrl,
    required String title,
    required String authorName,
    bool autoRate = false,
  }) async {
    try {
      await _sb.from('video_views').insert({
        'video_id': videoId,
        'viewer_user_id': AppAuth.currentUserId,
      });
    } catch (_) {}
    if (!mounted) return;
    // Pass the current feed as a playlist so the player supports TikTok-style
    // vertical paging, starting on the tapped video.
    final playlist = List<Map<String, dynamic>>.from(_currentFeedDocs);
    final startIndex =
        playlist.indexWhere((d) => (d['id'] ?? '').toString() == videoId);
    final result = await context.router.push(
      VideoPlayerRoute(
        videoUrl: videoUrl,
        title: title,
        authorName: authorName,
        videoId: videoId,
        autoOpenRating: autoRate,
        playlist: playlist.length > 1 ? playlist : null,
        initialIndex: startIndex < 0 ? 0 : startIndex,
      ),
    );
    if (result is Map && result['ratingUpdated'] == true) {
      setState(() {
        _videoRatingCache.remove(videoId);
      });
      _prefetchVideoRating(videoId);
    }
  }

  Future<void> _openChallenge(String challengeId) async {
    try {
      // Full load from DB: participant list and counts come from
      // `challenge_participants` inside [ChallengeService._loadChallenge],
      // not from denormalized columns on `challenges`.
      final loaded = await sl<ChallengesRepository>().getChallenge(challengeId);
      if (loaded == null) {
        throw Exception(tr('il_a29799fa76'));
      }
      if (!mounted) return;
      context.router.push(ChallengeDetailsRoute(challenge: loaded));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'challenges_open_failed',
              namedArgs: {'error': e.toString()},
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _formatDate(DateTime? timestamp) {
    if (timestamp == null) return tr('il_f81ae5034f');
    
    final now = DateTime.now();
    final date = timestamp;
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
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showProfile(BuildContext context) {
    context.router.push(const ProfileRoute());
  }

  Widget _buildProfileSheet() {
    return const SizedBox.shrink();
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6a1b9a)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // Challenge list — participant count and prize pool are derived from
  // `challenge_participants` / `challenge_submissions`, not from `challenges`
  // (those columns do not exist on the table).
  Widget _buildChallengesList() {
    return BlocBuilder<ChallengesListCubit, ChallengesListState>(
      builder: (context, listState) {
        if (listState.status == ChallengesListStatus.error) {
          return _pullable(Center(
            child: Text(
              tr(
                'il_3a6e650bec',
                args: [listState.errorMessage ?? ''],
              ),
            ),
          ));
        }

        if (listState.isLoading && listState.items.isEmpty) {
          return _buildVideoGridSkeleton();
        }

        final challenges = listState.items;

        if (challenges.isEmpty) {
          return _pullable(Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                    tr('il_535b6a64c4'),
                    style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                    tr('il_bca4d186c2'),
                    style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.router.push(const ChallengeCreateRoute()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    tr('il_a15fecd2a4'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ));
        }

        return ListView.builder(
          key: const PageStorageKey<String>('challenges-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return _buildChallengeCard(
              challenge,
              (challenge['id'] ?? '').toString(),
            );
          },
        );
      },
    );
  }

  // Challenge card — design `.ccard`
  Widget _buildChallengeCard(Map<String, dynamic> challenge, String challengeId) {
    final status = (challenge['status'] ?? 'recruiting').toString();
    final type = (challenge['type'] ?? 'goal').toString();
    final accent = _challengeTypeColor(type);
    final currentParticipants = challenge['currentParticipants'] ?? 0;
    final prizePool = (challenge['prizePool'] ?? 0.0).toDouble();
    final entryFee = challenge['entryFee'] ?? 10;
    final creatorId = (challenge['creatorId'] ?? '').toString();
    String creatorThumbnailUrl =
        (challenge['creatorThumbnailUrl'] ?? challenge['thumbnailUrl'] ?? '')
            .toString();
    if (creatorThumbnailUrl.isEmpty && creatorId.isNotEmpty) {
      final cachedThumb = _challengeCreatorThumbCache[challengeId];
      if (cachedThumb != null && cachedThumb.isNotEmpty) {
        creatorThumbnailUrl = cachedThumb;
      } else if (!_challengeCreatorThumbCache.containsKey(challengeId)) {
        _prefetchChallengeCreatorThumbnail(challengeId, creatorId);
      }
    }
    final votingDeadline = asDateTimeOrNull(challenge['votingDeadline']) ??
        asDateTimeOrNull(challenge['endDate']);
    final isCompleted = status == 'completed' ||
        (votingDeadline != null && DateTime.now().isAfter(votingDeadline));
    final displayStatus = isCompleted ? 'completed' : status;
    final stage = _challengeStageStyle(displayStatus);
    // Countdown to the current phase's deadline (recruiting → submission,
    // submission → voting, voting → end); "Completed" once the challenge ends.
    final timeLeft = isCompleted
        ? tr('challenge_status_completed')
        : challengePhaseCountdownLabel(
            challengePhaseTimeRemainingFromRow(challenge),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _viewChallengeDetails(challengeId, challenge),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FlapColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            SizedBox(
              height: 112,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (creatorThumbnailUrl.isNotEmpty)
                    Image.network(
                      creatorThumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          CustomPaint(painter: _CoverStripePainter(accent)),
                    )
                  else
                    CustomPaint(painter: _CoverStripePainter(accent)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Single indicator: current phase plus, while the challenge
                  // is still running, the countdown to that phase's deadline
                  // (completed challenges just read "Completed").
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _challengeStageChip(
                      stage,
                      timeLabel: isCompleted ? null : timeLeft,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge['title'] ?? tr('il_f59ab8d133'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlapText.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FlapColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    challenge['description'] ?? tr('il_bcd8cc53f4'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FlapText.sora(
                      fontSize: 12.5,
                      color: FlapColors.muted,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      _challengeFootStat(
                        value: prizePool > 0
                            ? '${prizePool.toInt()}'
                            : tr('challenge_prize_tbd'),
                        label: tr('challenge_prize_pool'),
                        valueColor: FlapColors.gold,
                        icon: Icons.monetization_on,
                      ),
                      const SizedBox(width: 16),
                      _challengeFootStat(
                        value: '$entryFee',
                        label: tr('challenge_entry_fee'),
                      ),
                      const SizedBox(width: 16),
                      _challengeFootStat(
                        value: '$currentParticipants',
                        label: tr('challenge_players'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({Color bg, Color fg, IconData icon, String label}) _challengeStageStyle(
      String status) {
    switch (status) {
      case 'recruiting':
        return (
          bg: FlapColors.blue.withValues(alpha: 0.2),
          fg: const Color(0xFF9CC1F0),
          icon: Icons.group_rounded,
          label: _getStatusText('recruiting'),
        );
      case 'voting':
        return (
          bg: FlapColors.green.withValues(alpha: 0.2),
          fg: FlapColors.greenBright,
          icon: Icons.star_rounded,
          label: _getStatusText('voting'),
        );
      case 'completed':
        return (
          bg: Colors.white.withValues(alpha: 0.1),
          fg: const Color(0xFFCDD4CE),
          icon: Icons.emoji_events_rounded,
          label: _getStatusText('completed'),
        );
      default:
        return (
          bg: FlapColors.amber.withValues(alpha: 0.2),
          fg: const Color(0xFFEACA85),
          icon: Icons.bolt_rounded,
          label: _getStatusText(status == 'submission' ? 'submission' : 'active'),
        );
    }
  }

  Widget _challengeStageChip(
      ({Color bg, Color fg, IconData icon, String label}) s,
      {String? timeLabel}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12, color: s.fg),
          const SizedBox(width: 6),
          Text(
            timeLabel == null ? s.label : '${s.label} · $timeLabel',
            style: FlapText.sora(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: s.fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeFootStat({
    required String value,
    required String label,
    Color? valueColor,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: valueColor ?? FlapColors.text),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: FlapText.cond(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: valueColor ?? FlapColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: FlapText.sora(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: FlapColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatarChip({
    required String userId,
    String? name,
    double size = 36,
  }) {
    if (userId.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withOpacity(0.1),
        child: const Icon(Icons.person, color: Colors.white70),
      );
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sb
          .from('profiles')
          .select('display_name, avatar_url, email')
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final resolvedName = (data?['display_name'] ??
                data?['email']?.toString().split('@').first ??
                name ??
                tr('il_64aee8c6cb'))
            .toString();
        final avatarUrl = (data?['avatar_url'] ?? '').toString();
        return PlayerAvatarButton(
          userId: userId,
          displayName: resolvedName,
          avatarUrl: avatarUrl,
          size: size,
        );
      },
    );
  }

  Widget _videoInfoChip({
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    final color =
        highlight ? const Color(0xFFFFD54F) : Colors.white.withOpacity(0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? color.withOpacity(0.25)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? color.withOpacity(0.6) : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'recruiting':
        return tr('challenge_status_recruiting');
      case 'submission':
        return tr('challenge_status_submission');
      case 'voting':
        return tr('challenge_status_voting');
      case 'completed':
        return tr('challenge_status_completed');
      default:
        return tr('challenge_status_active');
    }
  }

  // My videos
  Widget _buildMyVideosList() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey<String>(
        'my-videos-feed-$_videoFeedFilterKey',
      ),
      future: _memoizedMyListFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildVideoGridSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr(
                'il_3a6e650bec',
                args: [snapshot.error?.toString() ?? ''],
              ),
            ),
          );
        }

        final videos = snapshot.data ?? const <Map<String, dynamic>>[];

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  tr('il_d08de13219'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('il_6aefcf68aa'),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await context.router.push(VideoUploadRoute());
                    if (!mounted) return;
                    _invalidateVideoFeedCaches();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    tr('il_ea79e83338'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          key: const PageStorageKey<String>('my-videos-list'),
          padding: const EdgeInsets.all(20),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final videoId = (video['id'] ?? '').toString();
            return Dismissible(
              key: ValueKey('my-video-$videoId'),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              confirmDismiss: (_) => _confirmDeleteVideo(videoId),
              onDismissed: (_) => _deleteVideo(videoId, video),
              child: _buildVideoCard(video, videoId),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteVideo(String videoId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          tr('il_403e9a5101'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          tr('il_3d6a452672'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(tr('il_e2d0a54968')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteVideo(String videoId, Map<String, dynamic> data) async {
    try {
      await _sb.from('videos').delete().eq('id', videoId);

      final urls = <String>[
        (data['videoUrl'] ?? '').toString(),
        (data['thumbnailUrl'] ?? '').toString(),
      ].where((u) => u.isNotEmpty).toSet();
      final client = Supabase.instance.client;
      for (final url in urls) {
        try {
          await SupabaseAppStorage.tryRemovePublicObject(client, url);
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }
      _invalidateVideoFeedCaches();
      sl<ProfileBloc>().add(const ProfileEvent.userProfileSyncRequested());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_fbb5de3b38'))),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_ab6f889903'),
          ),
        ),
      );
    }
  }

  // Trending videos
  Widget _buildTrendingVideos() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey<String>(
        'vm-trending-$_trendingFeedFilterKey',
      ),
      future: _memoizedTrendingListFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildVideoGridSkeleton();
        }

        if (snapshot.hasError) {
          return _pullable(Center(
            child: Text(
              tr(
                'il_3a6e650bec',
                args: [snapshot.error?.toString() ?? ''],
              ),
            ),
          ));
        }

        final videos = snapshot.data ?? const <Map<String, dynamic>>[];

        if (videos.isEmpty) {
          return _pullable(Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  tr('il_c2160ba474'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ));
        }

        return ListView.builder(
          key: const PageStorageKey<String>('trending-videos-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return _buildVideoCard(video, (video['id'] ?? '').toString());
          },
        );
      },
    );
  }

  // Challenge helpers
  void _viewChallengeDetails(String challengeId, Map<String, dynamic> challengeData) {
    // Build Challenge from row data
    final challenge = Challenge(
      id: challengeId,
      title: challengeData['title'] ?? '',
      description: challengeData['description'] ?? '',
      type: parseChallengeType(challengeData['type'] as String?),
      audience: ChallengeAudience.values.firstWhere(
        (e) => e.toString() == 'ChallengeAudience.${challengeData['audience']}',
        orElse: () => ChallengeAudience.city,
      ),
      creatorId: challengeData['creatorId'] ?? '',
      creatorName: challengeData['creatorName'] ?? '',
      creatorVideoUrl: challengeData['creatorVideoUrl']?.toString(),
      city: challengeData['city'] ?? '',
      entryFee: challengeData['entryFee'] ?? 10,
      duration: challengeDurationDaysFromRow(
        Map<String, dynamic>.from(challengeData),
      ),
      createdAt: asDateTimeOrNull(challengeData['createdAt']) ?? DateTime.now(),
      startDate: asDateTimeOrNull(challengeData['startDate']) ?? DateTime.now(),
      submissionDeadline:
          asDateTimeOrNull(challengeData['submissionDeadline']) ?? DateTime.now(),
      votingDeadline:
          asDateTimeOrNull(challengeData['votingDeadline']) ?? DateTime.now(),
      endDate: asDateTimeOrNull(challengeData['endDate']) ?? DateTime.now(),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.toString() == 'ChallengeStatus.${challengeData['status']}',
        orElse: () => ChallengeStatus.recruiting,
      ),
      maxParticipants: challengeData['maxParticipants'] ?? 50,
      currentParticipants: challengeData['currentParticipants'] ?? 0,
      prizePool: (challengeData['prizePool'] ?? 0.0).toDouble(),
      participants: List<String>.from(challengeData['participants'] ?? []),
      submissions: List<String>.from(challengeData['submissions'] ?? []),
      votes: Map<String, double>.from(challengeData['votes'] ?? {}),
      detailedVotes: Map<String, Map<String, double>>.from(challengeData['detailedVotes'] ?? {}),
      winners: List<String>.from(challengeData['winners'] ?? []),
      finalScores: Map<String, double>.from(challengeData['finalScores'] ?? {}),
      isActive: challengeData['isActive'] ?? true,
      imageUrl: (challengeData['imageUrl'] ??
              challengeData['creatorThumbnailUrl'] ??
              challengeData['thumbnailUrl'])
          ?.toString(),
      tags: List<String>.from(challengeData['tags'] ?? []),
    );
    
    // Navigate to challenge details
    context.router.push(ChallengeDetailsRoute(challenge: challenge));
  }

}

class _CachedUserProfile {
  final String name;
  final String avatarUrl;
  final String city;

  const _CachedUserProfile({
    required this.name,
    required this.avatarUrl,
    required this.city,
  });
}

/// Decorative diagonal-stripe cover for challenge cards (design `.ccard .cov`),
/// shown when no creator thumbnail is available. Tinted by the challenge accent.
class _CoverStripePainter extends CustomPainter {
  final Color accent;
  const _CoverStripePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0E1C16));

    final stripe = Paint()..color = const Color(0xFF13241C);
    const w = 16.0;
    for (double x = -size.height; x < size.width; x += w * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + w, 0)
        ..lineTo(x + w, size.height)
        ..close();
      canvas.drawPath(path, stripe);
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.22), Colors.transparent],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CoverStripePainter oldDelegate) =>
      oldDelegate.accent != accent;
}
