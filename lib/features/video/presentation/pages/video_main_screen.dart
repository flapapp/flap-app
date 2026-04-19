import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import '../../../../core/di/injection.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../../../../router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../constants/video_categories.dart';
import '../../../challenges/data/models/challenge.dart';
import '../../../../widgets/rating_display.dart';
import '../../../../widgets/video_preview_box.dart';
import '../../../notifications/domain/repositories/notifications_repository.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/mode_speed_dial.dart';
import '../../../../widgets/city_autocomplete_field.dart';

@RoutePage()
class VideoMainScreen extends StatefulWidget {
  /// When set, mirrors legacy `arguments: {'myContent': 'videos'|'challenges'}`.
  final String? myContent;

  const VideoMainScreen({super.key, this.myContent});

  @override
  _VideoMainScreenState createState() => _VideoMainScreenState();
}

class _VideoMainScreenState extends State<VideoMainScreen> {
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
  final Map<String, _CachedUserProfile> _userProfileCache = {};
  final Set<String> _loadingUserProfiles = {};
  final Map<String, _CachedChallengeMeta> _challengeMetaCache = {};
  final Set<String> _challengeMetaLoading = {};
  final Set<String> _challengeMetaDenied = {};
  final Map<String, String?> _challengeCreatorThumbCache = {};
  final Set<String> _challengeCreatorThumbLoading = {};
  late Stream<QuerySnapshot> _videosStream;
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

int _compareVideoDocs(
  QueryDocumentSnapshot<Object?> a,
  QueryDocumentSnapshot<Object?> b,
) {
  final dataA = a.data() as Map<String, dynamic>? ?? const {};
  final dataB = b.data() as Map<String, dynamic>? ?? const {};
    if (_selectedSort == 'my_city' && _currentUserCity.trim().isNotEmpty) {
      final cityA = _normalizeCity((dataA['city'] ?? '').toString());
      final cityB = _normalizeCity((dataB['city'] ?? '').toString());
      final myCity = _normalizeCity(_currentUserCity);
      final aMine = cityA == myCity;
      final bMine = cityB == myCity;
      if (aMine != bMine) {
        return bMine ? 1 : -1;
      }
    }
    if (_selectedSort == 'rating_asc' || _selectedSort == 'rating_desc') {
      final ratingA = _extractVideoRating(dataA);
      final ratingB = _extractVideoRating(dataB);
      final cmp = _selectedSort == 'rating_asc'
          ? ratingA.compareTo(ratingB)
          : ratingB.compareTo(ratingA);
      if (cmp != 0) return cmp;
    } else if (_selectedTab == 'trending' && !_showOnlyMyVideos) {
      final viewsA = (dataA['views'] ?? 0) as num;
      final viewsB = (dataB['views'] ?? 0) as num;
      final cmp = viewsB.compareTo(viewsA);
      if (cmp != 0) return cmp;
    }
    final tsA = _extractCreatedAtMillis(dataA);
    final tsB = _extractCreatedAtMillis(dataB);
    return tsB.compareTo(tsA);
  }

  double _extractVideoRating(Map<String, dynamic> data) {
    final raw = data['rating'] ?? data['averageRating'] ?? data['voteAverage'] ?? 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  int _extractCreatedAtMillis(Map<String, dynamic> data) {
    final ts =
        data['createdAt'] ?? data['uploadedAt'] ?? data['timestamp'] ?? data['updatedAt'];
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    if (ts is DateTime) return ts.millisecondsSinceEpoch;
    if (ts is int) return ts;
    return 0;
  }

  bool _isChallengeVideoData(Map<String, dynamic> data) {
    final challengeId = (data['challengeId'] ?? '').toString().trim();
    final challengeTitle = (data['challengeTitle'] ?? '').toString().trim();
    final title = (data['title'] ?? '').toString().trim().toLowerCase();
    final description = (data['description'] ?? '').toString().trim().toLowerCase();
    final explicitFlag = data['isChallengeVideo'] == true;

    if (explicitFlag) return true;
    if (challengeId.isNotEmpty || challengeTitle.isNotEmpty) return true;

    // Legacy fallback markers for old challenge submissions.
    return title == 'відео челенджу' ||
        title == 'challenge video' ||
        description == 'відео челенджу' ||
        description == 'challenge video';
  }

  String _normalizeCity(String city) {
    final v = _primaryCityToken(city);
    const aliases = <String, String>{
      'kyiv': 'kyiv',
      'київ': 'kyiv',
      'kiev': 'kyiv',
      'lviv': 'lviv',
      'львів': 'lviv',
      'odesa': 'odesa',
      'odessa': 'odesa',
      'одеса': 'odesa',
      'kharkiv': 'kharkiv',
      'харків': 'kharkiv',
      'dnipro': 'dnipro',
      'дніпро': 'dnipro',
      'днепр': 'dnipro',
      'london': 'london',
      'лондон': 'london',
    };
    return aliases[v] ?? v;
  }

  String _primaryCityToken(String city) {
    final raw = city.trim().toLowerCase();
    if (raw.isEmpty) return '';
    final noParens = raw.replaceAll(RegExp(r'\(.*?\)'), '');
    final beforeComma = noParens.split(',').first;
    final beforeSlash = beforeComma.split('/').first;
    return beforeSlash.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _cityMatchesFilter(String cityValue) {
    if (_selectedCity.isEmpty) return true;
    final cityNorm = _normalizeCity(cityValue);
    final selectedNorm = _normalizeCity(_selectedCity);
    return cityNorm.isNotEmpty && selectedNorm.isNotEmpty && cityNorm == selectedNorm;
  }

  String _resolveVideoCityForFilter(
    Map<String, dynamic> data,
  ) {
    final directCity = (data['city'] ?? '').toString().trim();
    if (directCity.isNotEmpty) return directCity;

    final userId = (data['userId'] ?? '').toString().trim();
    if (userId.isEmpty) return '';

    final cached = _userProfileCache[userId]?.city.trim() ?? '';
    if (cached.isNotEmpty) return cached;

    if (!_loadingUserProfiles.contains(userId)) {
      _prefetchUserProfile(userId);
    }
    return '';
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
      final directDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .collection('submissions')
          .doc(creatorId)
          .get();
      final directData = directDoc.data();
      thumbUrl = (directData?['thumbnailUrl'] ?? '').toString().trim();

      if (thumbUrl.isEmpty) {
        final fallback = await FirebaseFirestore.instance
            .collection('challenges')
            .doc(challengeId)
            .collection('submissions')
            .where('isCreatorVideo', isEqualTo: true)
            .limit(1)
            .get();
        if (fallback.docs.isNotEmpty) {
          thumbUrl =
              (fallback.docs.first.data()['thumbnailUrl'] ?? '').toString().trim();
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
  _videosStream = _createVideosStream();
  _cityFilterController.text = '';
  _loadCurrentUserCity();
}

@override
void dispose() {
  _cityFilterController.dispose();
  super.dispose();
}

  Future<void> _loadCurrentUserCity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final city = (doc.data()?['city'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _currentUserCity = city;
      });
    } catch (_) {}
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
      _videosStream = _createVideosStream();
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
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () => _showProfile(context),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
            final userName = userData['displayName'] ??
                userData['name'] ??
                userData['email']?.split('@')[0] ??
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
      final votesSnap = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('votes')
          .get();
      double sum = 0.0;
      for (final doc in votesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        sum += (data['rating'] ?? 0.0).toDouble();
      }
      final avg = votesSnap.docs.isEmpty
          ? 0.0
          : double.parse((sum / votesSnap.docs.length).toStringAsFixed(2));
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
      final aggregate = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .count()
          .get();
      final count = aggregate.count ?? 0;
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

  void _prefetchUserProfile(String userId) async {
    if (userId.isEmpty ||
        _userProfileCache.containsKey(userId) ||
        _loadingUserProfiles.contains(userId)) {
      return;
    }
    _loadingUserProfiles.add(userId);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final resolvedName = (data['displayName'] ??
              data['name'] ??
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim())
          .toString()
          .trim();
      final avatar = (data['avatarUrl'] ?? data['avatar'] ?? '').toString();
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

  void _prefetchChallengeMetaForVideo(String videoId) async {
    if (_challengeMetaCache.containsKey(videoId) ||
        _challengeMetaLoading.contains(videoId) ||
        _challengeMetaDenied.contains(videoId)) {
      return;
    }
    _challengeMetaLoading.add(videoId);
    try {
      final submissions = await FirebaseFirestore.instance
          .collectionGroup('submissions')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();
      if (submissions.docs.isEmpty) return;
      final doc = submissions.docs.first;
      final challengeRef = doc.reference.parent.parent;
      if (challengeRef == null) return;
      final challengeSnap = await challengeRef.get();
      if (!challengeSnap.exists) return;
      final challengeData =
          challengeSnap.data() as Map<String, dynamic>? ?? const {};
      final title = (challengeData['title'] ?? '').toString();
      final challengeId = challengeRef.id;
      if (mounted) {
        setState(() {
          _challengeMetaCache[videoId] = _CachedChallengeMeta(
            challengeId: challengeId,
            title: title,
          );
        });
      }
    } on FirebaseException catch (e) {
  if (e.code == 'permission-denied') {
    _challengeMetaDenied.add(videoId);
    // блокуємо повторні запити для цього videoId, щоб не було "спаму" у логах
    _challengeMetaCache[videoId] = const _CachedChallengeMeta(
      challengeId: '',
      title: '',
    );
    return;
  }
  debugPrint('Error prefetching challenge meta for video $videoId: $e');
} catch (e) {
  debugPrint('Error prefetching challenge meta for video $videoId: $e');
} finally {
      _challengeMetaLoading.remove(videoId);
    }
  }

  Future<void> _showRateVideoSheet({
    required String videoId,
    required String videoTitle,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_4afcf6b419')),
        ),
      );
      return;
    }

    try {
      final existingVote = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('votes')
          .doc(currentUser.uid)
          .get();
      if (existingVote.exists) {
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
                ratedBy: currentUser.uid,
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
                    tr('il_e69e7edfdf'),
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
          if (tab != 'challenges') {
            _videosStream = _createVideosStream();
          }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (category.description().isNotEmpty)
                Text(
                  category.description(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
            ],
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

  List<QueryDocumentSnapshot> _filterAndSortVideoDocs(
    Iterable<QueryDocumentSnapshot> source, {
    bool excludeChallengeVideos = true,
  }) {
    final docs = source.where((d) {
      final data = d.data() as Map<String, dynamic>;

      if (excludeChallengeVideos && _isChallengeVideoData(data)) return false;

      if (_selectedRating.isNotEmpty) {
        final minRating = double.tryParse(_selectedRating.replaceAll('+', '')) ?? 0.0;
        final ratingRaw = _videoRatingCache[d.id] ?? _extractVideoRating(data);
        if (ratingRaw < minRating) return false;
      }

      if (_selectedCategory.isNotEmpty) {
        final categoryValue = (data['category'] ?? '').toString();
        final normalized = normalizeVideoCategoryValue(categoryValue);
        if (normalized != _selectedCategory) return false;
      }

      if (_selectedCity.isNotEmpty) {
        final city = _resolveVideoCityForFilter(data);
        if (!_cityMatchesFilter(city)) return false;
      }

      return true;
    }).toList();

    docs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>? ?? const {};
      final dataB = b.data() as Map<String, dynamic>? ?? const {};

      if (_selectedSort == 'rating_asc' || _selectedSort == 'rating_desc') {
        final ratingA = _videoRatingCache[a.id] ?? _extractVideoRating(dataA);
        final ratingB = _videoRatingCache[b.id] ?? _extractVideoRating(dataB);
        final cmp = _selectedSort == 'rating_asc'
            ? ratingA.compareTo(ratingB)
            : ratingB.compareTo(ratingA);
        if (cmp != 0) return cmp;
      } else if (_selectedSort == 'my_city' &&
          _currentUserCity.trim().isNotEmpty) {
        final cityA = _normalizeCity(_resolveVideoCityForFilter(dataA));
        final cityB = _normalizeCity(_resolveVideoCityForFilter(dataB));
        final mine = _normalizeCity(_currentUserCity);
        final aMine = cityA == mine;
        final bMine = cityB == mine;
        if (aMine != bMine) return bMine ? 1 : -1;
      } else if (_selectedTab == 'trending' && !_showOnlyMyVideos) {
        final viewsA = (dataA['views'] ?? 0) as num;
        final viewsB = (dataB['views'] ?? 0) as num;
        final cmp = viewsB.compareTo(viewsA);
        if (cmp != 0) return cmp;
      }

      final tsA = _extractCreatedAtMillis(dataA);
      final tsB = _extractCreatedAtMillis(dataB);
      return tsB.compareTo(tsA);
    });

    return docs;
  }

  Widget _buildVideosList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _videosStream,
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
              tr('il_24ffa7c8c5'),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

        final docs = _filterAndSortVideoDocs(snapshot.data!.docs);

        return ListView.builder(
          key: PageStorageKey<String>(
            'videos-list-$_selectedTab-${_showOnlyMyVideos ? "mine" : "all"}',
          ),
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final video = docs[index];
            final data = video.data() as Map<String, dynamic>;
            return _buildVideoCard(data, video.id);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _createVideosStream() {
    Query query = FirebaseFirestore.instance.collection('videos');
    final filteringOwnVideos = _showOnlyMyVideos;
    
    if (filteringOwnVideos) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) query = query.where('userId', isEqualTo: uid);
    }
    
    // Remove city and category filters from Firestore query to avoid composite index issues
    // These will be applied on the client side in _buildVideosList()
    
    // All sorting/filtering is handled client-side for consistency.
    return query.limit(400).snapshots();
  }

  Widget _buildVideoCard(Map<String, dynamic> data, String videoId) {
    final title = (data['title'] ?? tr('il_30a3b02cbe')).toString();
    final description = (data['description'] ?? '').toString();
    final rawCategory = (data['category'] ?? '').toString();
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
    final createdAt = data['createdAt'] as Timestamp?;
    final isLiked = data['isLikedByCurrentUser'] == true;
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final thumbnailUrl = data['thumbnailUrl']?.toString();
    final durationSeconds = data['duration'] is int ? data['duration'] as int : null;
    final categoryColor = _videoCategoryColor(rawCategory);
    String resolvedChallengeId = (data['challengeId'] ?? '').toString();
    String resolvedChallengeTitle = (data['challengeTitle'] ?? '').toString();
    final bool isChallengeVideo = resolvedChallengeId.isNotEmpty ||
        title == 'Відео челенджу' ||
        description == 'Відео челенджу' ||
        (data['isChallengeVideo'] == true);
    final bool hasChallengeInfo = isChallengeVideo || resolvedChallengeTitle.isNotEmpty;

    if (hasChallengeInfo && resolvedChallengeId.isEmpty) {
      final cachedMeta = _challengeMetaCache[videoId];
      if (cachedMeta != null) {
        resolvedChallengeId = cachedMeta.challengeId;
        if (resolvedChallengeTitle.isEmpty) {
          resolvedChallengeTitle = cachedMeta.title;
        }
      } else if (!_challengeMetaLoading.contains(videoId) &&
          !_challengeMetaDenied.contains(videoId)) {
        _prefetchChallengeMetaForVideo(videoId);
      }
    }

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
                      ? tr('il_d972e65e3c')
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
                      onPressed: () => _toggleLike(videoId, isLiked),
                      trailing: likes.toString(),
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
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .update({'views': FieldValue.increment(1)});
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
      final doc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();
      if (!doc.exists) {
        throw Exception('Challenge not found');
      }
      final challenge = Challenge.fromFirestore(doc);
      if (!mounted) return;
      context.router.push(ChallengeDetailsRoute(challenge: challenge));
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return tr('il_f81ae5034f');
    
    final now = DateTime.now();
    final date = timestamp.toDate();
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(tr('profile_not_found')));
          }

                     final userData = snapshot.data!.data()!;
           final displayName = userData['authorName'] ?? userData['displayName'] ?? 'Невідомий';
           final avatarUrl = userData['avatarUrl'] as String?;
           final email = userData['email'] ?? '';

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6a1b9a), Color(0xFF9c27b0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Color(0xFF6a1b9a),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF6a1b9a),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Profile options
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                                         _buildProfileOption(
                       icon: Icons.edit,
                       title: 'Редагувати профіль',
                       onTap: () {
                         Navigator.pop(context);
                         context.router.push(const ProfileRoute());
                       },
                     ),
                    _buildProfileOption(
                      icon: Icons.video_library,
                      title: 'Мої відео',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Show user's videos
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.favorite,
                      title: 'Улюблені',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Show liked videos
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.settings,
                      title: 'Налаштування',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to settings
                      },
                    ),
                    const Divider(height: 30),
                    _buildProfileOption(
                      icon: Icons.logout,
                      title: 'Вийти',
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pop(context);
                        context.router.replace(const LoginRoute());
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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
    return StreamBuilder<QuerySnapshot>(
      stream: (() {
        Query q = FirebaseFirestore.instance.collection('challenges');
        if (_showOnlyMyChallenges) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            q = q.where('creatorId', isEqualTo: uid);
          }
          q = q.limit(20);
        } else {
          q = q.orderBy('createdAt', descending: true).limit(20);
        }
        return q.snapshots();
      })(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr('il_3a6e650bec'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final challenges = snapshot.data?.docs ?? [];

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
            final challenge = challenges[index].data() as Map<String, dynamic>;
            return _buildChallengeCard(challenge, challenges[index].id);
          },
        );
      },
    );
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
    final createdAtTs = challenge['createdAt'] as Timestamp?;
    final votingDeadlineTs = challenge['votingDeadline'] as Timestamp?;
    final endDateTs = challenge['endDate'] as Timestamp?;
    final votingDeadline = votingDeadlineTs?.toDate() ?? endDateTs?.toDate();
    final createdAt = createdAtTs?.toDate() ?? now;
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
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final resolvedName = (data?['displayName'] ??
                data?['name'] ??
                data?['authorName'] ??
                name ??
                tr('il_64aee8c6cb'))
            .toString();
        final avatarUrl =
            (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString();
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr('il_3a6e650bec'),
            ),
          );
                  }

        final videos = _filterAndSortVideoDocs(snapshot.data?.docs ?? const []);

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
            final video = videos[index].data() as Map<String, dynamic>;
            final videoId = videos[index].id;
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
      await FirebaseFirestore.instance.collection('videos').doc(videoId).delete();

      final urls = <String>[
        (data['videoUrl'] ?? '').toString(),
        (data['thumbnailUrl'] ?? '').toString(),
      ].where((u) => u.isNotEmpty).toSet();
      for (final url in urls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_fbb5de3b38'))),
      );
    } catch (e) {
      if (!mounted) return;
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
    return StreamBuilder<QuerySnapshot>(
      stream: _videosStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr('il_3a6e650bec'),
            ),
          );
        }

        final videos = _filterAndSortVideoDocs(snapshot.data?.docs ?? const []);

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
            final video = videos[index].data() as Map<String, dynamic>;
            return _buildVideoCard(video, videos[index].id);
          },
        );
      },
    );
  }

  // Методи для роботи з челенджами
  void _joinChallenge(String challengeId, Map<String, dynamic> challenge) {
    // Перевірити чи користувач вже учасник
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final votingDeadline = (challenge['votingDeadline'] as Timestamp?)?.toDate();
    final endDate = (challenge['endDate'] as Timestamp?)?.toDate();
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
              
              // Спочатку додаємо користувача в учасники
              try {
                await FirebaseFirestore.instance
                    .collection('challenges')
                    .doc(challengeId)
                    .update({
                  'participants': FieldValue.arrayUnion([currentUser.uid]),
                  'currentParticipants': FieldValue.increment(1),
                });
                
                // Тепер переходимо до завантаження відео
    context.router.push(
      VideoUploadRoute(
        challengeId: challengeId,
        challengeTitle: challenge['title']?.toString(),
      ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('il_4f9785e6ae'))),
                );
              }
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
      createdAt: (challengeData['createdAt'] as Timestamp).toDate(),
      startDate: (challengeData['startDate'] as Timestamp).toDate(),
      submissionDeadline: (challengeData['submissionDeadline'] as Timestamp).toDate(),
      votingDeadline: (challengeData['votingDeadline'] as Timestamp).toDate(),
      endDate: (challengeData['endDate'] as Timestamp).toDate(),
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
  Future<void> _toggleLike(String videoId, bool isCurrentlyLiked) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final likeRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(uid);
      if (isCurrentlyLiked) {
        await likeRef.delete();
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .update({'likes': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_e11b346cb1')), backgroundColor: Colors.red),
      );
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
      builder: (context) => Container(
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .doc(videoId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                            'Поки що немає коментарів',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Будьте першим, хто залишить коментар!',
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
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final comment = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final userId = (comment['userId'] ?? '').toString();
                      final commentText =
                          (comment['comment'] ?? comment['text'] ?? '').toString();
                      final timestamp = comment['createdAt'] as Timestamp?;

                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: userId.isEmpty
                            ? null
                            : FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          final userData = userSnapshot.data?.data() ?? const <String, dynamic>{};
                          final authorName = (userData['displayName'] ??
                                  userData['name'] ??
                                  userData['authorName'] ??
                                  'Користувач')
                              .toString();
                          final avatarUrl =
                              (userData['avatarUrl'] ?? userData['photoUrl'] ?? '').toString();

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
                                  avatarUrl: avatarUrl,
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
                                      GestureDetector(
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
                                      const SizedBox(height: 4),
                                      Text(
                                        commentText,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (timestamp != null)
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 11,
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
                  );
                },
              ),
            ),
            // Comment input
            Container(
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
                        decoration: const InputDecoration(
                          hintText: 'Написати коментар...',
                          hintStyle: TextStyle(color: Colors.white70),
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
          ],
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

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final commentTime = timestamp.toDate();
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
    final currentUser = FirebaseAuth.instance.currentUser;
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
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .add({
        'userId': currentUser.uid,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Оновити лічильник коментарів
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .update({
        'comments': FieldValue.increment(1),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final coins = userData['coins'] ?? 0;
        final rating = (userData['rating'] ?? 0.0).toDouble();

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
                onTap: () => _showRatingHistory(userData),
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
  }

  void _showCoinsHistory(int currentCoins) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
                            tr('il_7a6d30960a'),
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userId', isEqualTo: uid)
                      .limit(50)
                      .snapshots(),
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
                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final ad = a.data() as Map<String, dynamic>;
                        final bd = b.data() as Map<String, dynamic>;
                        final at = ad['timestamp'] as Timestamp?;
                        final bt = bd['timestamp'] as Timestamp?;
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
                        final data = docs[index].data() as Map<String, dynamic>;
                        final amount = (data['amount'] ?? 0) as num;
                        final description = (data['description'] ?? '').toString();
                        final ts = data['timestamp'] as Timestamp?;
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

  void _showRatingHistory(Map<String, dynamic> userData) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final currentRating = ((userData['rating'] ?? 0.0) as num).toDouble();

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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rating_history')
                      .where('userId', isEqualTo: uid)
                      .limit(50)
                      .snapshots(),
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

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final ad = a.data() as Map<String, dynamic>;
                        final bd = b.data() as Map<String, dynamic>;
                        final at = ad['timestamp'] as Timestamp?;
                        final bt = bd['timestamp'] as Timestamp?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });

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
                        final entry = docs[index].data() as Map<String, dynamic>;
                        final delta = (entry['change'] ?? 0.0).toDouble();
                        final oldRating = (entry['oldRating'] ?? 0.0).toDouble();
                        final newRating = (entry['newRating'] ?? 0.0).toDouble();
                        final reason = (entry['reason'] ?? '').toString();
                        final challengeTitle =
                            (entry['challengeTitle'] ?? '').toString();
                        final voterName = (entry['voterName'] ?? '').toString();
                        final timestamp = entry['timestamp'] as Timestamp?;
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

class _CachedChallengeMeta {
  final String challengeId;
  final String title;

  const _CachedChallengeMeta({
    required this.challengeId,
    required this.title,
  });
}

