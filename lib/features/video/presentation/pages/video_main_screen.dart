import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import '../../../../core/di/injection.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../../../../router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import '../../../../core/supabase/supabase_date.dart';
import '../../../../constants/video_categories.dart';
import '../../../challenges/data/models/challenge.dart';
import '../../../../widgets/rating_display.dart';
import '../../../../widgets/video_preview_box.dart';
import '../../../notifications/domain/repositories/notifications_repository.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/mode_speed_dial.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import '../../../../core/supabase/public_video_feed.dart';

@RoutePage()
class VideoMainScreen extends StatefulWidget {
  /// When set, mirrors legacy `arguments: {'myContent': 'videos'|'challenges'}`.
  final String? myContent;

  const VideoMainScreen({super.key, this.myContent});

  @override
  _VideoMainScreenState createState() => _VideoMainScreenState();
}

class _VideoMainScreenState extends State<VideoMainScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  NotificationsRepository get _notificationsRepo => sl<NotificationsRepository>();

  RatingsRepository get _ratingRepo => sl<RatingsRepository>();
  String _selectedCity = '';
  final TextEditingController _cityFilterController = TextEditingController();
  String _selectedCategory = '';
  String _selectedRating = '';
  String _selectedSort = 'newest';
  String _selectedTab = 'all'; // all, challenges, trending
  bool _showOnlyMyVideos = false;
  bool _showOnlyMyChallenges = false;
  String _currentUserCity = '';
  final Map<String, double> _videoRatingCache = {};
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
  String? _cachedMainListKey;
  Future<List<Map<String, dynamic>>>? _cachedMainListFuture;
  String? _cachedMyListKey;
  Future<List<Map<String, dynamic>>>? _cachedMyListFuture;
  bool _didInitFromRouteArgs = false;
  

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

  void initState() {
  super.initState();
  _cityFilterController.text = '';
  _loadCurrentUserCity();
}

@override
void dispose() {
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
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF0f0f23), // Темний фон як у HTML MVP
    appBar: AppBar(
      backgroundColor: const Color(0xFF0f0f23).withValues(alpha: 0.95),
      elevation: 0,
      title: InkWell(
        onTap: () => context.router.push(const ModeSelectionRoute()),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/logo/flap_logo.jpg',
                fit: BoxFit.cover,
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      actions: [
        // User chips: coins and rating
        _buildUserChips(),

        // Notifications
        StreamBuilder<int>(
          stream: _notificationsRepo.getUnreadCount(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  tooltip: tr('notifications'),
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () => context.router.push(const NotificationsRoute()),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // Profile button with avatar
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _sb
              .from('profiles')
              .stream(primaryKey: ['id'])
              .eq('id', AppAuth.currentUserId ?? ''),
          builder: (context, snapshot) {
            final userData = snapshot.data?.isNotEmpty == true
                ? snapshot.data!.first
                : null;
            if (userData == null) {
              return IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () => _showProfile(context),
              );
            }

            final avatarUrl = userData['avatar_url'] ?? '';
            final userName = userData['display_name'] ??
                userData['email']?.toString().split('@')[0] ??
                'User';

            return IconButton(
              onPressed: () => _showProfile(context),
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF4caf50),
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    ),
    body: SafeArea(
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

          // Filters (тільки для відео та трендів)
          if (_selectedTab != 'challenges' &&
              !_showOnlyMyVideos &&
              !_showOnlyMyChallenges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // Швидкі категорії
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: quickVideoCategories()
                          .map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                selected: _selectedCategory == category.id,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = selected ? category.id : '';
                                  });
                                },
                                label: Text(category.label()),
                                selectedColor: const Color(0xFF4caf50),
                                labelStyle: TextStyle(
                                  color: _selectedCategory == category.id
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // City and Category filters
                  Row(
                    children: [
                      Expanded(
                        child: CityAutocompleteField(
                          controller: _cityFilterController,
                          label: '',
                          hint: tr('il_ada640060a'),
                          includeAllOption: true,
                          requiredField: false,
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          labelStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF4caf50)),
                          ),
                          prefixIcon: const Icon(
                            Icons.location_city,
                            color: Colors.black54,
                            size: 18,
                          ),
                          onSelected: (value) {
                        final v = value.trim();
                        final allValues = <String>{
                          tr('all_cities').toLowerCase(),
                          'all cities',
                          'всі міста',
                        };

                        if (v.isEmpty) {
                          setState(() {
                            _selectedCity = '';
                            _cityFilterController.text = '';
                          });
                          return;
                        }

                        final isAll = allValues.contains(v.toLowerCase());

                        setState(() {
                          _selectedCity = isAll ? '' : v;
                          _cityFilterController.text = isAll ? '' : v;
                          _cityFilterController.selection = TextSelection.collapsed(
                            offset: _cityFilterController.text.length,
                          );
                        });
                      },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCategoryFilterDropdown(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Rating filter
                  _buildFilterDropdown(
                    _ratings,
                    _selectedRating.isEmpty
                        ? tr('il_a90e7e92a6')
                        : _selectedRating,
                    (value) {
                      setState(() {
                        _selectedRating =
                            value == tr('il_a90e7e92a6')
                                ? ''
                                : value;
                      });
                    },
                    '⭐',
                  ),
                  const SizedBox(height: 10),

                  _buildSortDropdown(),
                ],
              ),
            ),

          // Content based on selected tab
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    ),
    floatingActionButton: ModeSpeedDial(
      shortcuts: [
        ModeDialAction(
          icon: Icons.sports_soccer,
          tooltip: tr('matches'),
          onTap: () => context.router.push(MatchesRoute()),
        ),
        ModeDialAction(
          icon: Icons.groups_outlined,
          tooltip: tr('teams'),
          onTap: () => context.router.push(const TeamHubRoute()),
        ),
      ],
      onCreate: _showVideoCreateSheet,
      createTooltip: tr('il_4759498ac2'),
      createGradient: const [Color(0xFFFF6B35), Color(0xFFFF8A65)],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  );
}

  void _showVideoCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101320),
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
              onTap: () {
                Navigator.pop(ctx);
                context.router.push(VideoUploadRoute());
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

  Widget _buildCategoryLabel(String label, Color color, {VoidCallback? onTap}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: pill,
    );
  }

  Color _videoCategoryColor(String category) => videoCategoryColor(category);

  bool _isUnknownLabel(String value) {
    final normalized = value.toLowerCase().trim();
    return normalized.isEmpty ||
        normalized == 'невідомо' ||
        normalized == 'unknown';
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

  String _challengeTypeLabel(String type) {
    switch (parseChallengeType(type)) {
      case ChallengeType.goal:
        return tr('il_cdbf6975e8');
      case ChallengeType.shotPower:
        return tr('il_a387ab1835');
      case ChallengeType.pass:
        return tr('il_ebdf8cc00b');
      case ChallengeType.longPass:
        return tr('il_a30ef79268');
      case ChallengeType.dribbling:
        return tr('il_0b337d1bc7');
      case ChallengeType.tackle:
        return tr('il_9c0dd00951');
      case ChallengeType.defending:
        return tr('challenge_type_defending');
      case ChallengeType.penalty:
        return tr('il_241c754092');
      case ChallengeType.save:
        return tr('il_1509f561f2');
      case ChallengeType.wall:
        return tr('il_93819c7151');
      case ChallengeType.strategy:
        return tr('il_6b27710dfa');
      case ChallengeType.trick:
        return tr('il_209e3aa0b5');
      case ChallengeType.other:
        return tr('il_f97e9da0e3');
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

  Widget _buildMetaPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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
      final likeDoc = await _sb
          .from('video_likes')
          .select('video_id')
          .eq('video_id', videoId)
          .eq('user_id', uid)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _likedByMeCache[videoId] = likeDoc != null;
        });
      }
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
      final existingVote = await _sb
          .from('video_ratings')
          .select('id')
          .eq('video_id', videoId)
          .eq('rated_by', currentUser.id)
          .maybeSingle();
      if (existingVote != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_908b4d0670')),
          ),
        );
        return;
      }
    } catch (_) {}

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
      backgroundColor: const Color(0xFF101320),
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
                  divisions: 50,
                  label: value.toStringAsFixed(1),
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

  Widget _buildTab(String title, String tab) {
    final isActive = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
      onTap: () {
        if (_selectedTab == tab) return;
        setState(() {
          _selectedTab = tab;
        });
      },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            gradient: isActive ? LinearGradient(
              colors: [
                const Color(0xFF4caf50),
                const Color(0xFF66bb6a),
              ],
            ) : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color(0xFF4caf50).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
        ),
        child: Text(
          title.toUpperCase(),
            textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            letterSpacing: 0.5,
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
    String icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Text(icon),
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

  Widget _buildSortDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSort,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: _sortModes
              .map(
                (mode) => DropdownMenuItem<String>(
                  value: mode,
                  child: Row(
                    children: [
                      const Text('↕️'),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_sortLabel(mode))),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (String? mode) {
            if (mode == null) return;
            setState(() => _selectedSort = mode);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryFilterDropdown() {
    final items = [
      DropdownMenuItem<String>(
        value: '',
        child: Text(
          tr('il_9d5097a837'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      ...kVideoCategories.map(
        (category) => DropdownMenuItem<String>(
          value: category.id,
          child: Text(
            category.label(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: items,
          onChanged: (String? newValue) {
            setState(() {
              _selectedCategory = newValue ?? '';
            });
          },
        ),
      ),
    );
  }

  String get _videoFeedStateKey => [
        _selectedTab,
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
    return <String>[_selectedCategory];
  }

  VideoFeedSort _mapSortForFeed({required bool useTrendingViews}) {
    if (useTrendingViews) {
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

  VideoFeedParams _defaultFeedParams({required bool trendingLayout}) {
    return VideoFeedParams(
      onlyUserId: null,
      categoryCodes: _categoryCodesForFilter(),
      minAvgRating: _minRatingParam(),
      cityKey: _cityKeyForFeed(),
      excludeChallengeRelated: true,
      sort: _mapSortForFeed(useTrendingViews: trendingLayout),
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
      sort: _mapSortForFeed(useTrendingViews: false),
      limit: 400,
    );
  }

  Future<List<Map<String, dynamic>>> _loadFeedForMainList() {
    final isTrendingTab = _selectedTab == 'trending';
    final p = isTrendingTab
        ? _defaultFeedParams(trendingLayout: true)
        : _defaultFeedParams(trendingLayout: false);
    return getVideosFromDatabase(_sb, p);
  }

  Future<List<Map<String, dynamic>>> _loadFeedForMyList() {
    return getVideosFromDatabase(_sb, _myVideosFeedParams());
  }

  /// Stable future per filter/tab so [FutureBuilder] is not re-started every frame.
  Future<List<Map<String, dynamic>>> _memoizedMainListFuture() {
    final k = 'main-$_videoFeedStateKey';
    if (_cachedMainListKey == k) {
      return _cachedMainListFuture!;
    }
    _cachedMainListKey = k;
    return _cachedMainListFuture = _loadFeedForMainList();
  }

  Future<List<Map<String, dynamic>>> _memoizedMyListFuture() {
    final k = 'my-$_videoFeedStateKey';
    if (_cachedMyListKey == k) {
      return _cachedMyListFuture!;
    }
    _cachedMyListKey = k;
    return _cachedMyListFuture = _loadFeedForMyList();
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
        'vm-feed-$_videoFeedStateKey',
      ),
      future: _memoizedMainListFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr(
                'il_24ffa7c8c5',
                args: [snapshot.error?.toString() ?? ''],
              ),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final docs = snapshot.data ?? const <Map<String, dynamic>>[];
        if (docs.isEmpty) {
          return Center(
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
                  onPressed: () => context.router.push(VideoUploadRoute()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Завантажити відео',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          key: PageStorageKey<String>(
            'videos-list-$_selectedTab-${_showOnlyMyVideos ? "mine" : "all"}',
          ),
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            return _buildVideoCard(data, (data['id'] ?? '').toString());
          },
        );
      },
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> data, String videoId) {
    final title = (data['title'] ?? tr('il_30a3b02cbe')).toString();
    final description = (data['description'] ?? '').toString();
    final rawCategory = _resolveVideoCategoryCode(data);
    final categoryLabel = rawCategory.isEmpty
        ? tr('il_b91b9cac50')
        : videoCategoryLabel(rawCategory);
    final ratingRaw = data['rating'] ?? data['averageRating'] ?? data['voteAverage'] ?? 0.0;
    final double rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw.toString()) ?? 0.0;
    final views = (data['views'] ?? 0) as num;
    final likes = (data['likes'] ?? 0) as num;
    final commentsValue = (data['comments'] ?? data['commentCount'] ?? 0) as num;
    double displayRating = rating;
    final cachedRating = _videoRatingCache[videoId];
    if (displayRating <= 0 && cachedRating != null) {
      displayRating = cachedRating;
    } else if (displayRating <= 0 &&
        !_videoRatingLoading.contains(videoId)) {
      _prefetchVideoRating(videoId);
    }

    int displayComments = commentsValue.toInt();
    final cachedComments = _commentCountCache[videoId];
    if (cachedComments != null) {
      displayComments = cachedComments;
    } else if (!_commentCountLoading.contains(videoId)) {
      _prefetchCommentCount(videoId);
    }
    int displayLikes = likes.toInt();
    final cachedLikes = _likeCountCache[videoId];
    if (cachedLikes != null) {
      displayLikes = cachedLikes;
    }

    String authorDisplayName = (data['authorName'] ??
            data['displayName'] ??
            data['userName'] ??
            tr('il_b764cdc0ea'))
        .toString();
    final authorId = data['userId'] as String?;
    String? authorAvatar;
    _CachedUserProfile? cachedProfile;
    if (authorId != null && authorId.isNotEmpty) {
      cachedProfile = _userProfileCache[authorId];
      if (cachedProfile != null) {
        authorDisplayName = cachedProfile.name;
        authorAvatar = cachedProfile.avatarUrl;
      } else {
        _prefetchUserProfile(authorId);
      }
    }
    final rawCity = (data['city'] ?? '').toString();
    String locationLabel = rawCity.trim();
    if (locationLabel.isEmpty || _isUnknownLabel(locationLabel)) {
      final fallbackCity = cachedProfile?.city?.trim() ?? '';
      locationLabel = fallbackCity.isNotEmpty
          ? fallbackCity
          : tr('il_b764cdc0ea');
    }
    final createdAt = asDateTimeOrNull(data['createdAt']);
    final bool serverIsLiked = data['isLikedByCurrentUser'] == true;
    final isLiked = _likedByMeCache[videoId] ?? serverIsLiked;
    if (AppAuth.currentUserId != null &&
        !serverIsLiked &&
        !_likedByMeCache.containsKey(videoId)) {
      _prefetchLikeState(videoId);
    }
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final thumbnailUrl = data['thumbnailUrl']?.toString();
    final durationSeconds = data['duration'] is int ? data['duration'] as int : null;
    final categoryColor = _videoCategoryColor(rawCategory);
    String resolvedChallengeId = (data['challengeId'] ?? '').toString();
    String resolvedChallengeTitle = (data['challengeTitle'] ?? '').toString();
    final bool isChallengeVideo = title == 'Відео челенджу' ||
        description == 'Відео челенджу' ||
        (data['isChallengeVideo'] == true);
    final bool hasChallengeInfo = isChallengeVideo || resolvedChallengeTitle.isNotEmpty;

    final bool hasChallengeLink = resolvedChallengeId.isNotEmpty;
    final String challengeLabel = resolvedChallengeTitle.isNotEmpty
        ? resolvedChallengeTitle
        : tr('il_27cf1792f7');
    final Color challengeColor = const Color(0xFFFFC107);

    final badges = <Widget>[];
    if (hasChallengeInfo) {
      badges.add(
        _buildVideoChip(
          challengeLabel,
          challengeColor,
          onTap: hasChallengeLink
              ? () => _openChallenge(
                    resolvedChallengeId,
                    challengeLabel,
                  )
              : null,
        ),
      );
      badges.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _buildVideoChip(categoryLabel, categoryColor),
        ),
      );
    } else {
      badges.add(_buildVideoChip(categoryLabel, categoryColor));
    }

    final safeTitle = (hasChallengeInfo && challengeLabel.isNotEmpty)
        ? challengeLabel
        : (title.isEmpty ? tr('il_f59ab8d133') : title);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoPreviewBox(
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            borderRadius: 20,
            onTap: () => _openVideo(
              videoId: videoId,
              videoUrl: videoUrl,
              title: safeTitle,
              authorName: authorDisplayName,
            ),
            topLeft: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: badges,
            ),
            topRight: _buildRatingBadge(
              displayRating > 0 ? displayRating.toStringAsFixed(2) : null,
            ),
            bottomRight: _buildMetaPill(
              durationSeconds != null
                  ? _formatDuration(durationSeconds)
                  : (views > 0
                      ? tr('il_d972e65e3c', namedArgs: {'views': '$views'})
                      : tr('il_18fdd549b2')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildCategoryLabel(
                      hasChallengeInfo ? challengeLabel : categoryLabel,
                      hasChallengeInfo ? challengeColor : categoryColor,
                      onTap: hasChallengeInfo && hasChallengeLink
                          ? () => _openChallenge(
                            resolvedChallengeId,
                                challengeLabel,
                              )
                          : null,
                    ),
                    const Spacer(),
                    _videoInfoChip(
                      icon: Icons.remove_red_eye,
                      label: views.toString(),
                    ),
                    const SizedBox(width: 6),
                    _videoInfoChip(
                      icon: Icons.chat_bubble_outline,
                      label: displayComments.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  safeTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    PlayerAvatarButton(
                      userId: authorId ?? '',
                      displayName: authorDisplayName,
                      avatarUrl: authorAvatar,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (authorId != null) {
                            context.router.push(
                              PlayerProfileRoute(
                                playerId: authorId!,
                                playerName: authorDisplayName,
                              ),
                            );
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorDisplayName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$locationLabel • ${_formatDate(createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (authorId != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: CompactRatingDisplay(userId: authorId, size: 16),
                      ),
                  ],
                ),
                if (resolvedChallengeId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _openChallenge(resolvedChallengeId, challengeLabel),
                    icon: const Icon(Icons.emoji_events_outlined, color: Colors.white70),
                    label: Text(
                      tr('il_1157649c00'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _iconCircleButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      tooltip: tr('il_64f915cb8b'),
                      iconColor: isLiked ? Colors.redAccent : Colors.white,
                      background: isLiked ? Colors.redAccent.withOpacity(0.15) : Colors.white10,
                      onPressed: () => _toggleLike(videoId, isLiked, displayLikes),
                      trailing: displayLikes.toString(),
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.chat_bubble_outline,
                      tooltip: tr('comments'),
                      onPressed: () => _showComments(videoId, safeTitle),
                      trailing: displayComments.toString(),
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.share,
                      tooltip: tr('il_29887a5ff9'),
                      onPressed: () => _shareVideo(videoId, safeTitle),
                    ),
                    const Spacer(),
                    _iconCircleButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: tr('il_a71e757324'),
                      background: const Color(0xFF4caf50),
                      onPressed: () => _openVideo(
                        videoId: videoId,
                        videoUrl: videoUrl,
                        title: safeTitle,
                        authorName: authorDisplayName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.star_rate_rounded,
                      tooltip: tr('il_cd5588db6f'),
                      background: const Color(0xFFFFC107),
                      onPressed: () => _showRateVideoSheet(
                        videoId: videoId,
                        videoTitle: safeTitle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final result = await context.router.push(
      VideoPlayerRoute(
        videoUrl: videoUrl,
        title: title,
        authorName: authorName,
        videoId: videoId,
        autoOpenRating: autoRate,
      ),
    );
    if (result is Map && result['ratingUpdated'] == true) {
      setState(() {
        _videoRatingCache.remove(videoId);
      });
      _prefetchVideoRating(videoId);
    }
  }

  Future<void> _openChallenge(String challengeId, String title) async {
    try {
      final row = await _sb
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .maybeSingle();
      if (row == null) {
        throw Exception('Challenge not found');
      }
      final challenge = _mapChallengeRow(row);
      if (!mounted) return;
      _viewChallengeDetails(challengeId, challenge);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bilingual(
              'Не вдалося відкрити челендж: $e',
              'Unable to open challenge: $e',
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
      return bilingual(
        '${difference.inDays} дн. тому',
        '${difference.inDays} d ago',
      );
    } else if (difference.inHours > 0) {
      return bilingual(
        '${difference.inHours} год. тому',
        '${difference.inHours} h ago',
      );
    } else if (difference.inMinutes > 0) {
      return bilingual(
        '${difference.inMinutes} хв. тому',
        '${difference.inMinutes} min ago',
      );
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

  // Список челенджів
  Widget _buildChallengesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: (() {
        final uid = _showOnlyMyChallenges ? AppAuth.currentUserId : null;
        return _sb
            .from('challenges')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .limit(20)
            .map((rows) => rows
                .where((row) => uid == null || (row['creator_id'] ?? '').toString() == uid)
                .map(_mapChallengeRow)
                .toList());
      })(),
      builder: (context, snapshot) {
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final challenges = snapshot.data ?? const <Map<String, dynamic>>[];

        if (challenges.isEmpty) {
          return Center(
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
          );
        }

        return ListView.builder(
          key: const PageStorageKey<String>('challenges-list'),
          padding: const EdgeInsets.all(20),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return _buildChallengeCard(challenge, (challenge['id'] ?? '').toString());
          },
        );
      },
    );
  }

  Map<String, dynamic> _mapChallengeRow(Map<String, dynamic> row) {
    return <String, dynamic>{
      'id': row['id']?.toString() ?? '',
      'title': row['title'],
      'description': row['description'],
      'type': row['type'] ?? row['challenge_type'] ?? 'goal',
      'audience': row['audience'] ?? 'city',
      'status': row['status'] ?? 'recruiting',
      'creatorId': row['creator_id']?.toString() ?? '',
      'creatorName': row['creator_name'] ?? '',
      'city': row['city'] ?? '',
      'entryFee': row['entry_fee'] ?? 0,
      'duration': row['duration'] ?? 7,
      'createdAt': row['created_at'],
      'startDate': row['start_date'],
      'submissionDeadline': row['submission_deadline'],
      'votingDeadline': row['voting_deadline'],
      'endDate': row['end_date'],
      'maxParticipants': row['max_participants'] ?? 50,
      'currentParticipants': row['current_participants'] ?? 0,
      'prizePool': row['prize_pool'] ?? 0.0,
      'participants': row['participants'] ?? const <String>[],
      'creatorVideoUrl': row['video_url'] ?? row['creator_video_url'],
      'creatorThumbnailUrl':
          row['video_thumbnail_url'] ?? row['creator_thumbnail_url'] ?? row['thumbnail_url'],
      'thumbnailUrl': row['video_thumbnail_url'] ?? row['thumbnail_url'],
      'imageUrl': row['image_url'],
      'isActive': row['is_active'] ?? true,
      'tags': row['tags'] ?? const <String>[],
    };
  }

  // Картка челенджу
  Widget _buildChallengeCard(Map<String, dynamic> challenge, String challengeId) {
    final status = (challenge['status'] ?? 'recruiting').toString();
    final type = (challenge['type'] ?? 'goal').toString();
    final accent = _challengeTypeColor(type);
    final currentParticipants = challenge['currentParticipants'] ?? 0;
    final maxParticipants = challenge['maxParticipants'] ?? 50;
    final prizePool = (challenge['prizePool'] ?? 0.0).toDouble();
    final entryFee = challenge['entryFee'] ?? 10;
    final duration = challenge['duration'] ?? 7;
    final creatorId = (challenge['creatorId'] ?? '').toString();
    final creatorName = (challenge['creatorName'] ??
            tr('il_b764cdc0ea'))
        .toString();
    final creatorVideoUrl =
        (challenge['creatorVideoUrl'] ?? '').toString();
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
    final participants =
        List<String>.from(challenge['participants'] ?? const []);
    final now = DateTime.now();
    final createdAtTs = asDateTimeOrNull(challenge['createdAt']);
    final votingDeadlineTs = asDateTimeOrNull(challenge['votingDeadline']);
    final endDateTs = asDateTimeOrNull(challenge['endDate']);
    final votingDeadline = votingDeadlineTs ?? endDateTs;
    final createdAt = createdAtTs ?? now;
    final isCompletedByDate =
        votingDeadline != null && now.isAfter(votingDeadline);
    final isCompleted = status == 'completed' || isCompletedByDate;
    final displayStatus = isCompleted ? 'completed' : status;
    final remaining = votingDeadline?.difference(now) ?? Duration.zero;
    final remainingDays =
        remaining.inSeconds <= 0 ? 0 : (remaining.inHours / 24).ceil();
    final totalSeconds = votingDeadline != null
        ? votingDeadline.difference(createdAt).inSeconds
        : 0;
    final elapsedSeconds = votingDeadline != null
        ? now.difference(createdAt).inSeconds.clamp(0, totalSeconds)
        : 0;
    final timelineProgress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Заголовок челенджу
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withValues(alpha: 0.8)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                  challenge['title'] ?? tr('il_f59ab8d133'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusText(displayStatus),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildCategoryLabel(_challengeTypeLabel(type), accent),
                const SizedBox(height: 8),
                Text(
                  challenge['description'] ??
                      tr('il_bcd8cc53f4'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Author and duration info
                Row(
                  children: [
                    _buildUserAvatarChip(
                      userId: creatorId,
                      name: creatorName,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creatorName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            tr('il_bb42908a8a'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.access_time, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$duration ${tr('il_ab51004e9d')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (creatorVideoUrl.isNotEmpty || creatorThumbnailUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VideoPreviewBox(
                videoUrl: creatorVideoUrl.isNotEmpty ? creatorVideoUrl : null,
                thumbnailUrl: creatorThumbnailUrl.isNotEmpty
                    ? creatorThumbnailUrl
                    : null,
                borderRadius: 18,
                onTap: creatorVideoUrl.isEmpty
                    ? null
                    : () {
                        context.router.push(
                          VideoPlayerRoute(
                            videoUrl: creatorVideoUrl,
                            title: challenge['title'] ??
                                tr('il_4c92b02f91'),
                            authorName: creatorName,
                            videoId: challengeId,
                          ),
                        );
                      },
                topLeft: _buildMetaPill(
                  tr('il_bfccfa4baf'),
                ),
              ),
            ),
          ],

          // Інформація про челендж
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
            child: Column(
              children: [
                Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                          Text(
                            isCompleted
                                ? tr('il_5042fbee3b')
                                : bilingual(
                                    'До завершення голосування: $remainingDays дн.',
                                    'Voting ends in: $remainingDays days',
                                  ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            isCompleted
                                ? tr('il_22a970d2e5')
                                : '$remainingDays ${tr('il_18ac3e7343')}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                    ),
                  ],
                ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: isCompleted ? 1.0 : timelineProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF66bb6a),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.people,
                        value: '$currentParticipants',
                        label: tr('il_0e27279b33'),
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.attach_money,
                        value: '$entryFee',
                        label: tr('il_2649e082d9'),
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.emoji_events,
                        value: '${prizePool.toInt()}',
                        label: tr('il_0a489d848c'),
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // Action Buttons Row
                Row(
                  children: [
                    // Переглянути челендж
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      child: ElevatedButton.icon(
                          onPressed: () => _viewChallengeDetails(challengeId, challenge),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            tr('il_dcc839a401'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Приєднатися
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4caf50).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: isCompleted
                              ? null
                              : () => _joinChallenge(challengeId, challenge),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.video_library,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            isCompleted
                                ? tr('il_22a970d2e5')
                                : tr('il_fd30fe681b'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (participants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildParticipantsRow(participants),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsRow(List<String> ids) {
    final preview = ids.take(5).toList();
    final remaining = ids.length - preview.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_2, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              tr('il_0e27279b33'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ...preview.map(
              (id) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildUserAvatarChip(
                  userId: id,
                  size: 34,
                ),
              ),
            ),
            if (remaining > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
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
        return 'Збір';
      case 'submission':
        return 'Відео';
      case 'voting':
        return 'Голосування';
      case 'completed':
        return 'Завершено';
      default:
        return 'Активний';
    }
  }

  // Мої відео
  Widget _buildMyVideosList() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey<String>(
        'my-videos-feed-$_videoFeedStateKey',
      ),
      future: _memoizedMyListFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
                  onPressed: () => context.router.push(VideoUploadRoute()),
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
      setState(() {
        _myVideosRefreshToken++;
        _cachedMyListKey = null;
        _cachedMyListFuture = null;
        _cachedMainListKey = null;
        _cachedMainListFuture = null;
      });
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

  // Трендові відео
  Widget _buildTrendingVideos() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey<String>(
        'vm-trending-$_videoFeedStateKey',
      ),
      future: _memoizedMainListFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
          );
        }

        return ListView.builder(
          key: const PageStorageKey<String>('trending-videos-list'),
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

  // Методи для роботи з челенджами
  void _joinChallenge(String challengeId, Map<String, dynamic> challenge) {
    // Перевірити чи користувач вже учасник
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    final votingDeadline = asDateTimeOrNull(challenge['votingDeadline']);
    final endDate = asDateTimeOrNull(challenge['endDate']);
    final isCompletedByDate = (votingDeadline != null &&
            DateTime.now().isAfter(votingDeadline)) ||
        (endDate != null && DateTime.now().isAfter(endDate));
    if ((challenge['status'] ?? '') == 'completed' || isCompletedByDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_e957ce6dda'),
          ),
        ),
      );
      return;
    }
    
    // Показуємо підтвердження участі
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e7d32),
        title: Text(
          tr('il_e56c7271db'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              bilingual(
                'Ви приєднуєтеся до челенджу "${challenge['title']}"',
                'You are joining the challenge "${challenge['title']}"',
              ),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              bilingual(
                'Ставка входу: ${challenge['entryFee'] ?? 0} монет',
                'Entry fee: ${challenge['entryFee'] ?? 0} coins',
              ),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr('cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              context.router.push(
                VideoUploadRoute(
                  challengeId: challengeId,
                  challengeTitle: challenge['title']?.toString(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4caf50)),
            child: Text(
              tr('il_ea79e83338'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _viewChallengeDetails(String challengeId, Map<String, dynamic> challengeData) {
    // Створюємо Challenge об'єкт з даних
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
      city: challengeData['city'] ?? '',
      entryFee: challengeData['entryFee'] ?? 10,
      duration: challengeData['duration'] ?? 7,
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
      imageUrl: challengeData['imageUrl'],
      tags: List<String>.from(challengeData['tags'] ?? []),
    );
    
    // Переходимо на екран деталей челенджу
    context.router.push(ChallengeDetailsRoute(challenge: challenge));
  }

  // Interactive methods
  Future<void> _toggleLike(
    String videoId,
    bool isCurrentlyLiked,
    int currentDisplayedLikes,
  ) async {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    if (_likeToggleLoading.contains(videoId)) return;
    final previousLiked = _likedByMeCache[videoId] ?? isCurrentlyLiked;
    final previousCount = _likeCountCache[videoId];
    final currentCount = previousCount ?? currentDisplayedLikes;
    final nextCount = previousLiked
        ? (currentCount - 1).clamp(0, 1 << 30)
        : currentCount + 1;
    _likeToggleLoading.add(videoId);
    if (mounted) {
      setState(() {
        _likedByMeCache[videoId] = !previousLiked;
        _likeCountCache[videoId] = nextCount;
      });
    }
    try {
      if (previousLiked) {
        await _sb
            .from('video_likes')
            .delete()
            .eq('video_id', videoId)
            .eq('user_id', uid);
      } else {
        await _sb.from('video_likes').upsert({
          'video_id': videoId,
          'user_id': uid,
        });
      }
      final likes = await _sb
          .from('video_likes')
          .select('user_id')
          .eq('video_id', videoId);
      if (mounted) {
        setState(() {
          _likeCountCache[videoId] = (likes as List<dynamic>).length;
          _likedByMeCache[videoId] = !previousLiked;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likedByMeCache[videoId] = previousLiked;
          if (previousCount == null) {
            _likeCountCache.remove(videoId);
          } else {
            _likeCountCache[videoId] = previousCount;
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_e11b346cb1', namedArgs: {'e': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _likeToggleLoading.remove(videoId);
      if (mounted) setState(() {});
    }
  }

  void _showComments(String videoId, String videoTitle) {
    final commentController = TextEditingController();
    final safeTitle = videoTitle.trim().isEmpty
        ? tr('il_0cab1c9617')
        : videoTitle;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e7d32), Color(0xFF2e7d32)],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
          child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('comments_to_video_title', namedArgs: {'title': safeTitle}),
                      style: const TextStyle(
                color: Colors.white,
                        fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Comments list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _sb
                    .from('video_comments')
                    .stream(primaryKey: ['id'])
                    .eq('video_id', videoId)
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('il_6b25808365'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('il_comment_empty_cta'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final comment = snapshot.data![index];
                      final userId = (comment['user_id'] ?? '').toString();
                      final commentText =
                          (comment['comment'] ?? comment['text'] ?? comment['body'] ?? '')
                              .toString();
                      final timestamp = comment['created_at'];
                      String authorName = (comment['author_name'] ?? tr('il_b764cdc0ea'))
                          .toString();
                      String? authorAvatarUrl;
                      if (userId.isNotEmpty) {
                        final cachedProfile = _userProfileCache[userId];
                        if (cachedProfile != null) {
                          authorName = cachedProfile.name;
                          authorAvatarUrl = cachedProfile.avatarUrl;
                        } else {
                          _prefetchUserProfile(userId);
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlayerAvatarButton(
                              userId: userId,
                              displayName: authorName,
                              avatarUrl: authorAvatarUrl,
                              size: 38,
                              backgroundColor: const Color(0xFF4caf50),
                              borderColor: Colors.white.withValues(alpha: 0.25),
                              borderWidth: 1,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            if (userId.isEmpty) return;
                                            context.router.push(
                                              PlayerProfileRoute(
                                                playerId: userId,
                                                playerName: authorName,
                                              ),
                                            );
                                          },
                                          child: Text(
                                            authorName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (timestamp != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    commentText,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Comment input
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: tr('il_23c5f33170'),
                          hintStyle: const TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (text) {
                          final value = text.trim();
                          if (value.isNotEmpty) {
                            _addComment(videoId, value);
                            commentController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      final value = commentController.text.trim();
                      if (value.isEmpty) return;
                      _addComment(videoId, value);
                      commentController.clear();
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
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
    );
  }

  void _shareVideo(String videoId, String videoTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('video_shared_message', args: [videoTitle])),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    final commentTime = asDateTimeOrNull(timestamp);
    if (commentTime == null) return tr('il_66f53417d3');
    final now = DateTime.now();
    final difference = now.difference(commentTime);

    if (difference.inDays > 0) {
      return bilingual(
        '${difference.inDays} днів тому',
        '${difference.inDays} d ago',
      );
    } else if (difference.inHours > 0) {
      return bilingual(
        '${difference.inHours} годин тому',
        '${difference.inHours} h ago',
      );
    } else if (difference.inMinutes > 0) {
      return bilingual(
        '${difference.inMinutes} хвилин тому',
        '${difference.inMinutes} min ago',
      );
    } else {
      return tr('il_66f53417d3');
    }
  }

  void _addComment(String videoId, String comment) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;

    // Перевірка чи videoId не порожній
    if (videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('video_id_not_found')),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Додати коментар
      await _sb.from('video_comments').insert({
        'video_id': videoId,
        'user_id': currentUser.id,
        'body': comment,
      });

      _commentCountCache.remove(videoId);
      _prefetchCommentCount(videoId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('comment_added_snack')),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('comment_add_error_detail', args: ['$e'])),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // User chips with coins and rating
  Widget _buildUserChips() {
    final uid = AppAuth.currentUserId;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sb
          .from('coin_transactions')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid),
      builder: (context, txSnapshot) {
        final rows = txSnapshot.data ?? const <Map<String, dynamic>>[];
        final coins = rows.fold<int>(
          0,
          (sum, r) => sum + (((r['amount'] as num?) ?? 0).toInt()),
        );
        return FutureBuilder<Map<String, dynamic>?>(
          future: _sb
              .from('user_rating_snapshots')
              .select('rating_value')
              .eq('user_id', uid)
              .eq('rating_scope', 'overall')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle(),
          builder: (context, profileSnap) {
            final rating =
                ((profileSnap.data?['rating_value'] as num?) ?? 0).toDouble();
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _showCoinsHistory(coins),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFffc107).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFffc107), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, color: Color(0xFFffc107), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            coins.toString(),
                            style: const TextStyle(
                              color: Color(0xFFffc107),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showRatingHistory(rating),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4caf50).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4caf50), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Color(0xFF4caf50), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Color(0xFF4caf50),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCoinsHistory(int currentCoins) {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('il_8162d9ed63'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            tr(
                              'il_7a6d30960a',
                              namedArgs: {'currentCoins': '$currentCoins'},
                            ),
                            style: const TextStyle(color: Color(0xFFFFD700)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb
                      .from('coin_transactions')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          tr('il_e18668fad3'),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                    }
                    final docs = (snapshot.data ?? const <Map<String, dynamic>>[])
                      ..sort((a, b) {
                        final at = asDateTimeOrNull(a['created_at']);
                        final bt = asDateTimeOrNull(b['created_at']);
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          tr('il_f75dda0d2e'),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index];
                        final amount = (data['amount'] ?? 0) as num;
                        final description = (data['description'] ?? '').toString();
                        final ts = data['created_at'];
                        final timestampText = ts != null
                            ? _formatTimestamp(ts)
                            : tr('il_f81ae5034f');
                        final isPositive = amount >= 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isPositive
                                      ? const Color(0xFF4caf50).withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  isPositive ? Icons.add : Icons.remove,
                                  color: isPositive ? const Color(0xFF4caf50) : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(description,
                                        style: const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.w600)),
                                    Text(
                                      timestampText,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isPositive ? '+' : ''}${amount.toString()}',
                                style: TextStyle(
                                  color: isPositive ? const Color(0xFF4caf50) : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  void _showRatingHistory(double currentRating) {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('il_f717400739'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            bilingual(
                              'Поточний рейтинг: ${currentRating.toStringAsFixed(2)}',
                              'Current rating: ${currentRating.toStringAsFixed(2)}',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF4caf50),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb
                      .from('user_rating_snapshots')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', uid)
                      .order('created_at', ascending: false)
                      .limit(50),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          tr('il_48be616f61'),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                      );
                    }

                    final docs = snapshot.data ?? const <Map<String, dynamic>>[];

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          tr('il_f0dbc57339'),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final entry = docs[index];
                        final delta = 0.0;
                        final oldRating = (entry['rating_value'] ?? 0.0).toDouble();
                        final newRating = (entry['rating_value'] ?? 0.0).toDouble();
                        final reason = (entry['reason'] ?? '').toString();
                        final challengeTitle =
                            (entry['challengeTitle'] ?? '').toString();
                        final voterName = (entry['voterName'] ?? '').toString();
                        final timestamp = entry['created_at'];
                        final deltaSign = delta >= 0 ? '+' : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    delta >= 0 ? Icons.trending_up : Icons.trending_down,
                                    color: delta >= 0
                                        ? const Color(0xFF4caf50)
                                        : Colors.redAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$deltaSign${delta.toStringAsFixed(2)} → '
                                    '${newRating.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatRatingHistoryReason(
                                  reason,
                                  challengeTitle,
                                  voterName,
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${oldRating.toStringAsFixed(2)} → '
                                '${newRating.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
    );
  }

  String _formatRatingHistoryReason(
    String reason,
    String challengeTitle,
    String voterName,
  ) {
    switch (reason) {
      case 'challenge_vote':
      case 'video_vote':
      case 'video_rating':
        if (voterName.isNotEmpty && challengeTitle.isNotEmpty) {
          return bilingual(
            '$voterName оцінив ваше відео "$challengeTitle"',
            '$voterName rated your video "$challengeTitle"',
          );
        }
        if (voterName.isNotEmpty) {
          return bilingual(
            '$voterName оцінив ваше відео',
            '$voterName rated your video',
          );
        }
        if (challengeTitle.isNotEmpty) {
          return bilingual(
            'Отримано оцінку за відео "$challengeTitle"',
            'Received a rating for video "$challengeTitle"',
          );
        }
        return tr('il_29262e8a7e');
      case 'challenge_win':
        return bilingual(
          'Перемога в челенджі "$challengeTitle"',
          'Challenge win "$challengeTitle"',
        );
      case 'challenge_second':
        return bilingual(
          '2-е місце в челенджі "$challengeTitle"',
          '2nd place in challenge "$challengeTitle"',
        );
      case 'challenge_third':
        return bilingual(
          '3-є місце в челенджі "$challengeTitle"',
          '3rd place in challenge "$challengeTitle"',
        );
      case 'match_rating':
        if (voterName.isNotEmpty) {
          return bilingual(
            '$voterName оцінив вас після матчу',
            '$voterName rated you after the match',
          );
        }
        return tr('il_64d8152d62');
      case 'manual_recompute':
      case 'manual_recalculation':
      case 'system_recompute':
        return tr('il_b6ce244d3a');
      case 'penalty':
        return tr('il_58659f628a');
      case 'bonus':
        return tr('il_c88734b3ea');
      default:
        if (reason == 'Оцінка після матчу') {
          return voterName.isNotEmpty
              ? bilingual(
                  '$voterName оцінив вас після матчу',
                  '$voterName rated you after the match',
                )
              : tr('il_64d8152d62');
        }
        return reason.isNotEmpty
            ? reason
            : tr('il_bcfd1b4865');
    }
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
