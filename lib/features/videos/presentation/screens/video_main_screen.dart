import 'dart:async';

import 'dart:ui' show ImageFilter;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/auth_sign_out_helper.dart';
import 'package:flap_app/features/profile/data/profile_legacy_user_map.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/videos/domain/entities/library_video.dart';
import 'package:flap_app/features/videos/domain/entities/video_comment.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'video_player_screen.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_details_bottom_sheet.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_join_flow.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_vertical_feed_screen.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/vertical_video_feed_screen.dart';
import 'package:flap_app/constants/video_categories.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/widgets/rating_display.dart';
import 'package:flap_app/widgets/video_preview_box.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/matches/data/rating_service.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/widgets/city_autocomplete_field.dart';
import 'package:flap_app/core/navigation/flap_navigation.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:google_fonts/google_fonts.dart';

@RoutePage()
class VideoMainScreen extends StatefulWidget {
  /// When set (e.g. from profile shortcuts), filters to "my" videos or challenges.
  final String? myContent;

  /// Embedded under [HomeHubScreen] (no [Scaffold]/[AppBar]/FAB; lists use shrink-wrap).
  final bool embedded;

  const VideoMainScreen({super.key, this.myContent, this.embedded = false});

  @override
  _VideoMainScreenState createState() => _VideoMainScreenState();
}

class _VideoMainScreenState extends State<VideoMainScreen> {
  bool get _embed => widget.embedded;

  ScrollPhysics? get _listPhysics =>
      _embed ? const NeverScrollableScrollPhysics() : null;

  Widget _embedSizedPlaceholder({double minHeight = 200, required Widget child}) {
    if (!_embed) return child;
    return SizedBox(
      width: double.infinity,
      height: minHeight,
      child: child,
    );
  }

  final NotificationService _notificationService = NotificationService();
  final RatingService _ratingService = RatingService();
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
  bool _didInitFromRouteArgs = false;

  Stream<List<LibraryVideo>> _libraryVideosStream(BuildContext context) {
    final forUid = _showOnlyMyVideos ? AppAuthContext.userId : null;
    return context.read<VideosRepository>().watchLibraryVideos(
          forUserId: forUid,
          limit: 400,
        );
  }
  

  List<String> get _cities => [
    I18n.t('all_cities'),
    I18n.t('kyiv'),
    I18n.t('lviv'),
    I18n.t('odesa'),
    I18n.t('kharkiv'),
    I18n.t('dnipro'),
  ];

  List<String> get _ratings => [
    I18n.inline('Всі рейтинги', 'All ratings'),
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
        return I18n.inline('В моєму місті', 'In my city');
      case 'rating_asc':
        return I18n.inline('Рейтинг: за зростанням', 'Rating: low to high');
      case 'rating_desc':
        return I18n.inline('Рейтинг: за спаданням', 'Rating: high to low');
      case 'newest':
      default:
        return I18n.inline('Нові додані зверху', 'Newest first');
    }
  }

  String _selectedCategoryLabel() {
    if (_selectedCategory.isEmpty) {
      return I18n.inline('Всі категорії', 'All categories');
    }
    return videoCategoryById(_selectedCategory)?.label() ??
        videoCategoryLabel(_selectedCategory);
  }

  double _extractVideoRating(Map<String, dynamic> data) {
    final raw = data['rating'] ?? data['averageRating'] ?? data['voteAverage'] ?? 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  int _extractCreatedAtMillis(Map<String, dynamic> data) {
    final ts =
        data['createdAt'] ?? data['uploadedAt'] ?? data['timestamp'] ?? data['updatedAt'];
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
      if (!mounted) return;
      final repo = context.read<ChallengeRepository>();
      var thumbUrl = (await repo.getSubmission(
                challengeId: challengeId,
                submissionUserId: creatorId,
              ))
          ?.thumbnailUrl
          .trim();
      if (thumbUrl != null && thumbUrl.isEmpty) thumbUrl = null;

      _challengeCreatorThumbCache[challengeId] = thumbUrl;
      if (mounted) setState(() {});
    } catch (_) {
      _challengeCreatorThumbCache[challengeId] = null;
    } finally {
      _challengeCreatorThumbLoading.remove(challengeId);
    }
  }

  @override
  void initState() {
    super.initState();
    _cityFilterController.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentUserCity());
  }

  @override
  void dispose() {
    _cityFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserCity() async {
    final uid = AppAuthContext.userId;
    if (uid == null) return;
    try {
      final row = await context.read<ProfileRepository>().fetchLegacyUserMap(uid);
      final city = (row?['city'] ?? '').toString();
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

    String? my = widget.myContent;
    if (my == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        my = args['myContent'] as String?;
      }
    }
    if (my == 'videos' || my == 'challenges') {
      _showOnlyMyVideos = my == 'videos';
      _showOnlyMyChallenges = my == 'challenges';
      _selectedTab = _showOnlyMyChallenges ? 'challenges' : 'all';
    }
  }

  bool get _hasActiveVideoFilters {
    return _selectedCity.isNotEmpty ||
        _selectedCategory.isNotEmpty ||
        _selectedRating.isNotEmpty ||
        _selectedSort != 'newest';
  }

  void _resetVideoFilters() {
    setState(() {
      _selectedCity = '';
      _cityFilterController.clear();
      _selectedCategory = '';
      _selectedRating = '';
      _selectedSort = 'newest';
    });
  }

  Widget _filterSheetSection({
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FlapTheme.accent.withValues(alpha: 0.35),
                            FlapTheme.accentSecondary.withValues(alpha: 0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        FlapTheme.accent,
                        FlapTheme.accentSecondary.withValues(alpha: 0.9),
                      ],
                    )
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: FlapTheme.accent.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? FlapTheme.pitch : Colors.white.withValues(alpha: 0.88),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetRatingPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected
                    ? const Color(0xFFFFC107).withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFC107).withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _sortModeIcon(String mode) {
    switch (mode) {
      case 'my_city':
        return Icons.location_city_rounded;
      case 'rating_asc':
        return Icons.trending_up_rounded;
      case 'rating_desc':
        return Icons.trending_down_rounded;
      case 'newest':
      default:
        return Icons.schedule_rounded;
    }
  }

  Widget _sheetSortTile({
    required String mode,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? FlapTheme.accent.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: selected
                    ? FlapTheme.accent.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _sortModeIcon(mode),
                  color: selected ? FlapTheme.accent : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _sortLabel(mode),
                    style: GoogleFonts.plusJakartaSans(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: FlapTheme.accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Category chips + city + category dropdown + rating + sort (embed), or sectioned sheet UI.
  Widget _buildVideoFiltersEditor({VoidCallback? onApplied, bool forSheet = false}) {
    void apply() {
      onApplied?.call();
    }

    if (forSheet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filterSheetSection(
            title: I18n.inline('Швидкі теми', 'Quick topics'),
            subtitle: I18n.inline(
              'Обери тег або всі категорії нижче',
              'Pick a tag or use full category below',
            ),
            icon: Icons.local_fire_department_rounded,
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _sheetCategoryChip(
                    label: I18n.inline('Усі теги', 'All tags'),
                    selected: _selectedCategory.isEmpty,
                    onTap: () {
                      setState(() => _selectedCategory = '');
                      apply();
                    },
                  ),
                  ...quickVideoCategories().map(
                    (category) => _sheetCategoryChip(
                      label: category.label(),
                      selected: _selectedCategory == category.id,
                      onTap: () {
                        setState(() {
                          _selectedCategory = _selectedCategory == category.id
                              ? ''
                              : category.id;
                        });
                        apply();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          _filterSheetSection(
            title: I18n.inline('Місто', 'City'),
            subtitle: I18n.inline('Фільтр за містом автора', 'Filter by creator city'),
            icon: Icons.location_on_outlined,
            child: CityAutocompleteField(
              controller: _cityFilterController,
              label: '',
              hint: I18n.inline('Введіть місто', 'Enter city'),
              includeAllOption: true,
              requiredField: false,
              style: const TextStyle(color: Color(0xFF1a1f2e), fontSize: 15),
              labelStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: const Color(0xFFF2F4F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: FlapTheme.accent, width: 2),
              ),
              prefixIcon: Icon(
                Icons.apartment_rounded,
                color: FlapTheme.accentSecondary.withValues(alpha: 0.9),
                size: 22,
              ),
              onSelected: (value) {
                final v = value.trim();
                final allValues = <String>{
                  I18n.t('all_cities').toLowerCase(),
                  'all cities',
                  'всі міста',
                };

                if (v.isEmpty) {
                  setState(() {
                    _selectedCity = '';
                    _cityFilterController.text = '';
                  });
                  apply();
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
                apply();
              },
            ),
          ),
          _filterSheetSection(
            title: I18n.inline('Категорія', 'Category'),
            subtitle: I18n.inline('Повний список категорій', 'Full category list'),
            icon: Icons.dashboard_customize_outlined,
            child: _buildCategoryFilterDropdown(
              onApplied: onApplied,
              dropdownMenuColor: const Color(0xFF2a3142),
              sheetField: true,
            ),
          ),
          _filterSheetSection(
            title: I18n.inline('Мін. рейтинг', 'Min. rating'),
            subtitle: I18n.inline('Лише відео з оцінкою не нижче', 'Only videos rated at least'),
            icon: Icons.star_outline_rounded,
            child: Row(
              children: [
                _sheetRatingPill(
                  label: I18n.inline('Усі', 'Any'),
                  selected: _selectedRating.isEmpty,
                  onTap: () {
                    setState(() => _selectedRating = '');
                    apply();
                  },
                ),
                _sheetRatingPill(
                  label: '4.0+',
                  selected: _selectedRating == '4.0+',
                  onTap: () {
                    setState(() => _selectedRating = '4.0+');
                    apply();
                  },
                ),
                _sheetRatingPill(
                  label: '4.5+',
                  selected: _selectedRating == '4.5+',
                  onTap: () {
                    setState(() => _selectedRating = '4.5+');
                    apply();
                  },
                ),
              ],
            ),
          ),
          _filterSheetSection(
            title: I18n.inline('Сортування', 'Sort'),
            subtitle: I18n.inline('Як упорядковувати стрічку', 'How to order the feed'),
            icon: Icons.sort_rounded,
            child: Column(
              children: _sortModes
                  .map(
                    (mode) => _sheetSortTile(
                      mode: mode,
                      selected: _selectedSort == mode,
                      onTap: () {
                        setState(() => _selectedSort = mode);
                        onApplied?.call();
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                        apply();
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
        Row(
          children: [
            Expanded(
              child: CityAutocompleteField(
                controller: _cityFilterController,
                label: '',
                hint: I18n.inline('Введіть місто', 'Enter city'),
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
                    I18n.t('all_cities').toLowerCase(),
                    'all cities',
                    'всі міста',
                  };

                  if (v.isEmpty) {
                    setState(() {
                      _selectedCity = '';
                      _cityFilterController.text = '';
                    });
                    apply();
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
                  apply();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCategoryFilterDropdown(onApplied: onApplied),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildFilterDropdown(
          _ratings,
          _selectedRating.isEmpty
              ? I18n.inline('Всі рейтинги', 'All ratings')
              : _selectedRating,
          (value) {
            setState(() {
              _selectedRating =
                  value == I18n.inline('Всі рейтинги', 'All ratings')
                      ? ''
                      : value;
            });
            apply();
          },
          '⭐',
        ),
        const SizedBox(height: 10),
        _buildSortDropdown(onApplied: onApplied),
      ],
    );
  }

  void _showVideoFiltersBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void bump() {
              setState(() {});
              setModalState(() {});
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.42,
              maxChildSize: 0.96,
              builder: (context, scrollController) {
                final bottomInset = MediaQuery.paddingOf(context).bottom;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1c2230).withValues(alpha: 0.98),
                        const Color(0xFF0b0e14),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: FlapTheme.accent.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: -8,
                        offset: const Offset(0, -12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.35),
                                  Colors.white.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    I18n.inline('Фільтри стрічки', 'Feed filters'),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    I18n.inline(
                                      'Налаштуй відображення відео під себе',
                                      'Tune how videos appear for you',
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _resetVideoFilters();
                                bump();
                              },
                              child: Text(
                                I18n.inline('Скинути', 'Reset'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: FlapTheme.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          children: [
                            _buildVideoFiltersEditor(onApplied: bump, forSheet: true),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottomInset),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border(
                            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: FlapTheme.accent,
                            foregroundColor: FlapTheme.pitch,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(modalContext).pop(),
                          icon: const Icon(Icons.check_rounded, size: 22),
                          label: Text(
                            I18n.inline('Застосувати і закрити', 'Apply & close'),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
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
      },
    );
  }

  /// TikTok-style top tabs for the standalone [AppBar.title].
  Widget _buildAppBarUnderlineTabs() {
    return Row(
      children: [
        Expanded(
          child: _appBarUnderlineTab(
            I18n.inline('Усі', 'All'),
            'all',
          ),
        ),
        Expanded(
          child: _appBarUnderlineTab(
            I18n.t('challenges'),
            'challenges',
          ),
        ),
        Expanded(
          child: _appBarUnderlineTab(
            I18n.inline('Тренди', 'Trending'),
            'trending',
          ),
        ),
      ],
    );
  }

  Widget _appBarUnderlineTab(String label, String tab) {
    final active = _selectedTab == tab;
    return InkWell(
      onTap: () {
        if (_selectedTab == tab) return;
        setState(() => _selectedTab = tab);
      },
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: -0.2,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                shadows: active
                    ? const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 3,
              width: active ? 28 : 0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tabs, filters, and feed (standalone [Scaffold] or embedded under [HomeHubScreen]).
  Widget _buildMainColumn() {
    if (_embed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  _buildTab(I18n.t('all'), 'all'),
                  _buildTab(I18n.t('challenges'), 'challenges'),
                  _buildTab(I18n.inline('Тренди', 'Trending'), 'trending'),
                ],
              ),
            ),
          if (_selectedTab != 'challenges' &&
              !_showOnlyMyVideos &&
              !_showOnlyMyChallenges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildVideoFiltersEditor(),
            ),
          _buildContent(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(child: _buildContent()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_embed) {
      return _buildMainColumn();
    }
    return Scaffold(
    extendBody: true,
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 0,
      leading: const SizedBox.shrink(),
      title: _showOnlyMyVideos || _showOnlyMyChallenges
          ? Text(
              _showOnlyMyChallenges
                  ? I18n.t('challenges')
                  : I18n.inline('Мої відео', 'My videos'),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            )
          : _buildAppBarUnderlineTabs(),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _showVideoFiltersBottomSheet,
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
        ),
        // Notifications
        StreamBuilder<int>(
          stream: _notificationService.getUnreadCount(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  tooltip: I18n.t('notifications'),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 26,
                  ),
                  onPressed: () => context.pushRoute(const NotificationsRoute()),
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
      ],
    ),
    body: _buildMainColumn(),
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
        return I18n.inline('Гол', 'Goal');
      case ChallengeType.shotPower:
        return I18n.inline('Сила удару', 'Shot power');
      case ChallengeType.pass:
        return I18n.inline('Пас', 'Pass');
      case ChallengeType.longPass:
        return I18n.inline('Довгий пас', 'Long pass');
      case ChallengeType.dribbling:
        return I18n.inline('Дриблінг', 'Dribbling');
      case ChallengeType.tackle:
        return I18n.inline('Підкат', 'Tackle');
      case ChallengeType.penalty:
        return I18n.inline('Пенальті', 'Penalty');
      case ChallengeType.save:
        return I18n.inline('Сейв', 'Save');
      case ChallengeType.wall:
        return I18n.inline('Стіна / стандарт', 'Wall / set-piece');
      case ChallengeType.strategy:
        return I18n.inline('Стратегія', 'Strategy');
      case ChallengeType.trick:
        return I18n.inline('Трюк', 'Trick');
      case ChallengeType.other:
        return I18n.inline('Інше', 'Other');
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
            ratingText ?? I18n.inline('Немає', 'No rating'),
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
      if (!mounted) return;
      final avg = await context
          .read<VideosRepository>()
          .fetchAverageVoteRating(videoId);
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
      if (!mounted) return;
      final count =
          await context.read<VideosRepository>().fetchCommentCount(videoId);
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
      if (!mounted) return;
      final data = await context.read<ProfileRepository>().fetchLegacyUserMap(userId) ??
          const <String, dynamic>{};
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
                : I18n.inline('Користувач', 'User'),
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
      if (!mounted) return;
      final link =
          await context.read<ChallengeRepository>().findChallengeForVideo(videoId);
      if (link == null) return;
      if (mounted) {
        setState(() {
          _challengeMetaCache[videoId] = _CachedChallengeMeta(
            challengeId: link.challengeId,
            title: link.title,
          );
        });
      }
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
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline(
              'Увійдіть, щоб оцінювати відео', 'Sign in to rate videos')),
        ),
      );
      return;
    }

    try {
      final has = await context.read<VideosRepository>().userHasVote(
            videoId: videoId,
            userId: currentUser.id,
          );
      if (has) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline(
                'Ви вже оцінили це відео', 'You already rated this video')),
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
              final success = await _ratingService.rateVideo(
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
                    content: Text(I18n.inline(
                        'Оцінку збережено', 'Rating submitted')),
                  ),
                );
                _prefetchVideoRating(videoId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(I18n.inline(
                        'Не вдалося зберегти оцінку', 'Unable to save rating')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    I18n.inline('Помилка: $e', 'Error: $e'),
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
                    I18n.inline('Оцініть відео', 'Rate video'),
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
                                I18n.inline('Простий', 'Simple'),
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
                                I18n.inline('Розширений', 'Advanced'),
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
                    sliderTile(I18n.inline('Техніка', 'Technical'), technical,
                        (v) => setModalState(() => technical = v)),
                    sliderTile(
                        I18n.inline('Креативність', 'Creativity'),
                        creativity,
                        (v) => setModalState(() => creativity = v)),
                    sliderTile(
                        I18n.inline('Складність', 'Difficulty'),
                        difficulty,
                        (v) => setModalState(() => difficulty = v)),
                    sliderTile(
                        I18n.inline('Якість відео', 'Video quality'),
                        quality,
                        (v) => setModalState(() => quality = v)),
                  ] else ...[
                    sliderTile(
                      I18n.inline('Загальна оцінка', 'Overall rating'),
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
                            ? I18n.inline('Надсилаємо...', 'Submitting...')
                            : I18n.inline('Оцінити відео', 'Submit rating'),
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

  Widget _buildSortDropdown({VoidCallback? onApplied}) {
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
            onApplied?.call();
          },
        ),
      ),
    );
  }

  Widget _buildCategoryFilterDropdown({
    VoidCallback? onApplied,
    Color? dropdownMenuColor,
    bool sheetField = false,
  }) {
    final menuBg = dropdownMenuColor ?? Colors.white;
    final primary = sheetField ? Colors.white : const Color(0xFF1a1f2e);
    final secondary = sheetField ? Colors.white60 : Colors.black54;
    final fieldFill =
        sheetField ? const Color(0xFF252b3a) : Colors.white.withValues(alpha: 0.9);
    final borderColor =
        sheetField ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.3);

    final items = [
      DropdownMenuItem<String>(
        value: '',
        child: Text(
          I18n.inline('Всі категорії', 'All categories'),
          style: TextStyle(fontWeight: FontWeight.w600, color: primary),
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
                style: TextStyle(fontWeight: FontWeight.w600, color: primary),
              ),
              if (category.description().isNotEmpty)
                Text(
                  category.description(),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(sheetField ? 14 : 10),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: sheetField ? 2 : 0),
          dropdownColor: menuBg,
          iconEnabledColor: sheetField ? Colors.white70 : null,
          style: TextStyle(color: primary, fontSize: 14),
          items: items,
          onChanged: (String? newValue) {
            setState(() {
              _selectedCategory = newValue ?? '';
            });
            onApplied?.call();
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
      if (_embed) return _buildChallengesList();
      return ChallengeVerticalFeedScreen(
        key: ValueKey<String>(
          'challenge-vertical-${_showOnlyMyChallenges ? 'mine' : 'all'}',
        ),
        scopeKey: _showOnlyMyChallenges ? 'mine' : 'all',
        onlyMine: _showOnlyMyChallenges,
      );
    case 'trending':
      if (_embed) return _buildTrendingVideos();
      return VerticalVideoFeedScreen(
        key: const ValueKey<String>('vertical-feed-trending'),
        scopeKey: 'trending',
        forUserId: null,
        prepareVideos: (raw) => _filterAndSortVideoDocs(raw),
      );
    case 'all':
      if (_embed) return _buildVideosList();
      return VerticalVideoFeedScreen(
        key: const ValueKey<String>('vertical-feed-all'),
        scopeKey: 'all',
        forUserId: null,
        prepareVideos: (raw) => _filterAndSortVideoDocs(raw),
      );
    default:
      return _buildVideosList();
  }
}

  List<LibraryVideo> _filterAndSortVideoDocs(
    Iterable<LibraryVideo> source, {
    bool excludeChallengeVideos = true,
  }) {
    final docs = source.where((v) {
      final data = v.toLegacyCardMap();

      if (excludeChallengeVideos && _isChallengeVideoData(data)) return false;

      if (_selectedRating.isNotEmpty) {
        final minRating = double.tryParse(_selectedRating.replaceAll('+', '')) ?? 0.0;
        final ratingRaw = _videoRatingCache[v.id] ?? _extractVideoRating(data);
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
      final dataA = a.toLegacyCardMap();
      final dataB = b.toLegacyCardMap();

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
    return StreamBuilder<List<LibraryVideo>>(
      key: ValueKey(
        'vmain-videos-$_selectedTab-$_showOnlyMyVideos-${AppAuthContext.userId}',
      ),
      stream: _libraryVideosStream(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _embedSizedPlaceholder(
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _embedSizedPlaceholder(
            minHeight: 120,
            child: Center(
              child: Text(
                I18n.inline('Помилка завантаження: ${snapshot.error}', 'Error loading: ${snapshot.error}'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _embedSizedPlaceholder(
            minHeight: 280,
            child: Center(
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
                  I18n.inline('Поки що немає відео', 'No videos yet'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.inline('Будьте першим, хто завантажить відео!', 'Be the first to upload a video!'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.pushRoute(VideoUploadRoute()),
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
            ),
          );
        }

        final docs = _filterAndSortVideoDocs(snapshot.data!);

        return ListView.builder(
          key: PageStorageKey<String>(
            'videos-list-$_selectedTab-${_showOnlyMyVideos ? "mine" : "all"}',
          ),
          padding: const EdgeInsets.all(20),
          shrinkWrap: _embed,
          physics: _listPhysics,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildVideoCard(docs[index]);
          },
        );
      },
    );
  }

  Widget _buildVideoCard(LibraryVideo video) {
    final data = video.toLegacyCardMap();
    final videoId = video.id;
    final title = (data['title'] ?? I18n.inline('Без назви', 'No title')).toString();
    final description = (data['description'] ?? '').toString();
    final rawCategory = (data['category'] ?? '').toString();
    final categoryLabel = rawCategory.isEmpty
        ? I18n.inline('Без категорії', 'No category')
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
            I18n.inline('Невідомо', 'Unknown'))
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
      final fallbackCity = cachedProfile?.city.trim() ?? '';
      locationLabel = fallbackCity.isNotEmpty
          ? fallbackCity
          : I18n.inline('Невідомо', 'Unknown');
    }
    final createdAt = video.createdAt;
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
        : I18n.inline('Челендж', 'Challenge');
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
        : (title.isEmpty ? I18n.inline('Без назви', 'Untitled') : title);

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
                      ? I18n.inline('$views переглядів', '$views views')
                      : I18n.inline('Новинка', 'New')),
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
                            context.pushRoute(
                              PlayerProfileRoute(
                                playerId: authorId,
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
                              '$locationLabel • ${_formatRelativeMoment(createdAt)}',
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
                      I18n.inline('До челенджу', 'Open challenge'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    StreamBuilder<LibraryVideo?>(
                      stream: context
                          .read<VideosRepository>()
                          .watchVideo(videoId),
                      builder: (context, vSnap) {
                        final likeCount = vSnap.hasData && vSnap.data != null
                            ? vSnap.data!.likes
                            : likes.toInt();
                        return StreamBuilder<bool>(
                          stream: AppAuthContext.userId == null
                              ? null
                              : context.read<VideosRepository>().watchUserLikesVideo(
                                    videoId: videoId,
                                    userId: AppAuthContext.userId!,
                                  ),
                          builder: (context, likeSnap) {
                            final liked =
                                likeSnap.hasData && likeSnap.data == true;
                            return _iconCircleButton(
                              icon: liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              tooltip: I18n.inline('Подобається', 'Like'),
                              iconColor:
                                  liked ? Colors.redAccent : Colors.white,
                              background: liked
                                  ? Colors.redAccent.withOpacity(0.15)
                                  : Colors.white10,
                              onPressed: () => _toggleLike(videoId),
                              trailing: likeCount.toString(),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.chat_bubble_outline,
                      tooltip: I18n.t('comments'),
                      onPressed: () => _showComments(videoId, safeTitle),
                      trailing: displayComments.toString(),
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.share,
                      tooltip: I18n.inline('Поділитися', 'Share'),
                      onPressed: () => _shareVideo(videoId, safeTitle),
                    ),
                    const Spacer(),
                    _iconCircleButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: I18n.inline('Дивитися', 'Watch'),
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
                      tooltip: I18n.inline('Проголосувати', 'Vote'),
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
            I18n.inline('Челендж', 'Challenge'),
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
              trailing,
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
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  Future<void> _openVideo({
    required String videoId,
    required String videoUrl,
    required String title,
    required String authorName,
    bool autoRate = false,
  }) async {
    try {
      await context.read<VideosRepository>().incrementViews(videoId);
    } catch (_) {}
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
          authorName: authorName,
          videoId: videoId,
          autoOpenRating: autoRate,
        ),
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
      final challenge = await context.read<ChallengeRepository>().getChallenge(challengeId);
      if (challenge == null) {
        throw Exception('Challenge not found');
      }
      if (!mounted) return;
      context.pushRoute(ChallengeDetailsRoute(challenge: challenge));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Не вдалося відкрити челендж: $e',
              'Unable to open challenge: $e',
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _formatRelativeMoment(DateTime? date) {
    if (date == null) return I18n.inline('Нещодавно', 'Recently');

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return I18n.inline(
        '${difference.inDays} дн. тому',
        '${difference.inDays} d ago',
      );
    } else if (difference.inHours > 0) {
      return I18n.inline(
        '${difference.inHours} год. тому',
        '${difference.inHours} h ago',
      );
    } else if (difference.inMinutes > 0) {
      return I18n.inline(
        '${difference.inMinutes} хв. тому',
        '${difference.inMinutes} min ago',
      );
    } else {
      return I18n.inline('Щойно', 'Just now');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showProfile(BuildContext context) {
    flapOpenMainTab(context, FlapMainTab.profile);
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
      child: Builder(
        builder: (context) {
          final uid = AppAuthContext.userId;
          if (uid == null) {
            return const Center(child: Text('Профіль не знайдено'));
          }
          return StreamBuilder<Map<String, dynamic>>(
            stream: context.read<ProfileRepository>().watchLegacyUserMap(uid),
            builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data ?? const <String, dynamic>{};
          if (userData.isEmpty) {
            return const Center(child: Text('Профіль не знайдено'));
          }
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
                         flapOpenMainTab(context, FlapMainTab.profile);
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
                        await signOutViaBlocAndWait(context);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        context.router.replaceAll([const WelcomeRoute()]);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
            },
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
    return StreamBuilder<List<Challenge>>(
      stream: context.read<ChallengeRepository>().watchChallenges(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              I18n.inline('Помилка: ${snapshot.error}', 'Error: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var challenges = snapshot.data ?? [];
        if (_showOnlyMyChallenges) {
          final uid = AppAuthContext.userId;
          challenges = uid == null
              ? <Challenge>[]
              : challenges.where((c) => c.creatorId == uid).toList();
        }
        challenges = challenges.take(20).toList();

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
                    I18n.inline('Поки що немає челенджів', 'No challenges yet'),
                    style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                    I18n.inline(
                      'Створіть перший челендж або дочекайтеся нових!',
                      'Create your first challenge or wait for new ones!',
                    ),
                    style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.pushRoute(const ChallengeCreateRoute()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    I18n.inline('Створити челендж', 'Create challenge'),
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
          shrinkWrap: _embed,
          physics: _listPhysics,
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            return _buildChallengeCard(challenges[index]);
          },
        );
      },
    );
  }

  // Картка челенджу
  Widget _buildChallengeCard(Challenge challenge) {
    final challengeId = challenge.id;
    final status = challenge.status.name;
    final type = challenge.type.name;
    final accent = _challengeTypeColor(type);
    final currentParticipants = challenge.currentParticipants;
    final prizePool = challenge.prizePool;
    final entryFee = challenge.entryFee;
    final duration = challenge.duration;
    final creatorId = challenge.creatorId;
    final creatorName = challenge.creatorName.isNotEmpty
        ? challenge.creatorName
        : I18n.inline('Невідомо', 'Unknown');
    final creatorVideoUrl = challenge.creatorVideoUrl ?? '';
    String creatorThumbnailUrl = challenge.creatorThumbnailUrl ?? '';
    if (creatorThumbnailUrl.isEmpty && creatorId.isNotEmpty) {
      final cachedThumb = _challengeCreatorThumbCache[challengeId];
      if (cachedThumb != null && cachedThumb.isNotEmpty) {
        creatorThumbnailUrl = cachedThumb;
      } else if (!_challengeCreatorThumbCache.containsKey(challengeId)) {
        _prefetchChallengeCreatorThumbnail(challengeId, creatorId);
      }
    }
    final participants = challenge.participants;
    final now = DateTime.now();
    final votingDeadline = challenge.votingDeadline;
    final createdAt = challenge.createdAt;
    final isCompletedByDate = now.isAfter(votingDeadline);
    final isCompleted = status == 'completed' || isCompletedByDate;
    final displayStatus = isCompleted ? 'completed' : status;
    final remaining = votingDeadline.difference(now);
    final remainingDays =
        remaining.inSeconds <= 0 ? 0 : (remaining.inHours / 24).ceil();
    final totalSeconds = votingDeadline.difference(createdAt).inSeconds;
    final elapsedSeconds =
        now.difference(createdAt).inSeconds.clamp(0, totalSeconds);
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
                  challenge.title.isNotEmpty
                      ? challenge.title
                      : I18n.inline('Без назви', 'Untitled'),
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
                  challenge.description.isNotEmpty
                      ? challenge.description
                      : I18n.inline('Без опису', 'No description'),
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
                            I18n.inline('Автор челенджу', 'Challenge author'),
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
                      '$duration ${I18n.inline('днів', 'days')}',
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(
                              videoUrl: creatorVideoUrl,
                              title: challenge.title.isNotEmpty
                                  ? challenge.title
                                  : I18n.inline('Відео челенджу', 'Challenge video'),
                              authorName: creatorName,
                              videoId: challengeId,
                            ),
                          ),
                        );
                      },
                topLeft: _buildMetaPill(
                  I18n.inline('Відео організатора', 'Organizer video'),
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
                                ? I18n.inline('Статус: завершено', 'Status: completed')
                                : I18n.inline(
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
                                ? I18n.inline('Завершено', 'Completed')
                                : '$remainingDays ${I18n.inline('дн.', 'd')}',
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
                        label: I18n.inline('Учасники', 'Participants'),
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.attach_money,
                        value: '$entryFee',
                        label: I18n.inline('Вхід', 'Entry'),
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.emoji_events,
                        value: '${prizePool.toInt()}',
                        label: I18n.inline('Приз', 'Prize'),
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
                          onPressed: () => _viewChallengeDetails(challenge),
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
                            I18n.inline('Переглянути', 'View'),
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
                              : () => _joinChallenge(challenge),
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
                                ? I18n.inline('Завершено', 'Completed')
                                : I18n.inline('Участь', 'Join'),
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
              I18n.inline('Учасники', 'Participants'),
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
      future: context.read<ProfileRepository>().fetchLegacyUserMap(userId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final resolvedName = (data?['displayName'] ??
                data?['name'] ??
                data?['authorName'] ??
                name ??
                I18n.inline('Гравець', 'Player'))
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
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<List<LibraryVideo>>(
      key: ValueKey('vmain-my-videos-${currentUser.id}'),
      stream: context.read<VideosRepository>().watchLibraryVideos(
            forUserId: currentUser.id,
            limit: 400,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              I18n.inline('Помилка: ${snapshot.error}', 'Error: ${snapshot.error}'),
            ),
          );
        }

        final videos = _filterAndSortVideoDocs(snapshot.data ?? const []);

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
                  I18n.inline('У вас поки що немає відео', 'You have no videos yet'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.inline('Завантажте своє перше відео!', 'Upload your first video!'),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.pushRoute(VideoUploadRoute()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    I18n.inline('Завантажити відео', 'Upload video'),
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
          shrinkWrap: _embed,
          physics: _listPhysics,
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final videoId = video.id;
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
              onDismissed: (_) => _deleteVideo(video),
              child: _buildVideoCard(video),
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
          I18n.inline('Видалити відео?', 'Delete video?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          I18n.inline(
            'Цю дію неможливо скасувати.',
            'This action cannot be undone.',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(I18n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(I18n.inline('Видалити', 'Delete')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteVideo(LibraryVideo video) async {
    final uid = AppAuthContext.userId;
    if (uid == null) return;
    try {
      await context.read<VideosRepository>().deleteVideoIfOwner(
            videoId: video.id,
            userId: uid,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Відео видалено', 'Video deleted'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Не вдалося видалити відео', 'Failed to delete video'),
          ),
        ),
      );
    }
  }

  // Трендові відео
  Widget _buildTrendingVideos() {
    return StreamBuilder<List<LibraryVideo>>(
      key: ValueKey('vmain-trending-${AppAuthContext.userId}'),
      stream: context.read<VideosRepository>().watchLibraryVideos(limit: 400),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              I18n.inline('Помилка: ${snapshot.error}', 'Error: ${snapshot.error}'),
            ),
          );
        }

        final videos = _filterAndSortVideoDocs(snapshot.data ?? const []);

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
                  I18n.inline('Поки що немає трендових відео', 'No trending videos yet'),
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
          shrinkWrap: _embed,
          physics: _listPhysics,
          itemCount: videos.length,
          itemBuilder: (context, index) {
            return _buildVideoCard(videos[index]);
          },
        );
      },
    );
  }

  // Методи для роботи з челенджами
  void _joinChallenge(Challenge challenge) {
    showChallengeJoinDialog(context, challenge);
  }

  void _viewChallengeDetails(Challenge challenge) {
    unawaited(showChallengeDetailsBottomSheet(context, challenge: challenge));
  }

  // Interactive methods
  Future<void> _toggleLike(String videoId) async {
    final uid = AppAuthContext.userId;
    if (uid == null) return;
    try {
      final liked = await context
          .read<VideosRepository>()
          .watchUserLikesVideo(videoId: videoId, userId: uid)
          .first;
      await context.read<VideosRepository>().toggleLike(
            videoId: videoId,
            userId: uid,
            currentlyLiked: liked,
          );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка лайку: $e', 'Like error: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showComments(String videoId, String videoTitle) {
    final commentController = TextEditingController();
    final safeTitle = videoTitle.trim().isEmpty
        ? I18n.inline('відео', 'video')
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
                      'Коментарі до "$safeTitle"',
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
              child: StreamBuilder<List<VideoComment>>(
                stream: context.read<VideosRepository>().watchComments(videoId),
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

                  final comments = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final vc = comments[index];
                      final userId = vc.userId;
                      final commentText = vc.body;

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: userId.isEmpty
                            ? null
                            : context
                                .read<ProfileRepository>()
                                .fetchLegacyUserMap(userId),
                        builder: (context, userSnapshot) {
                          final userData =
                              userSnapshot.data ?? const <String, dynamic>{};
                          final authorName = vc.authorName.isNotEmpty
                              ? vc.authorName
                              : (userData['displayName'] ??
                                      userData['name'] ??
                                      userData['authorName'] ??
                                      'Користувач')
                                  .toString();
                          final avatarUrl = (userData['avatarUrl'] ??
                                  userData['photoUrl'] ??
                                  '')
                              .toString();

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
                                  borderColor:
                                      Colors.white.withValues(alpha: 0.25),
                                  borderWidth: 1,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (userId.isEmpty) return;
                                          context.pushRoute(
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
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatRelativeMoment(vc.createdAt),
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
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
        content: Text('📤 Відео "$videoTitle" поділено!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }

  void _addComment(String videoId, String comment) async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;

    // Перевірка чи videoId не порожній
    if (videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Помилка: ID відео не знайдено'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final profile = await context
          .read<ProfileRepository>()
          .fetchLegacyUserMap(currentUser.id);
      var authorName = (profile?['displayName'] ??
              profile?['authorName'] ??
              profile?['name'] ??
              '')
          .toString()
          .trim();
      if (authorName.isEmpty) {
        authorName = I18n.inline('Користувач', 'User');
      }
      await context.read<VideosRepository>().addComment(
            videoId: videoId,
            userId: currentUser.id,
            authorName: authorName,
            body: comment,
          );

      _commentCountCache.remove(videoId);
      _prefetchCommentCount(videoId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💬 Коментар додано!'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Помилка додавання коментаря: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // User chips with coins and rating
  Widget _buildUserChips() {
    final uid = AppAuthContext.userId;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      stream: context.read<ProfileRepository>().watchLegacyUserMap(uid),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? const <String, dynamic>{};
        if (userData.isEmpty) {
          return const SizedBox.shrink();
        }

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
    final uid = AppAuthContext.userId;
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
                          Text(I18n.inline('Мої монети', 'My coins'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            I18n.inline('Баланс: $currentCoins', 'Balance: $currentCoins'),
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
                  stream: context.read<ProfileRepository>().watchWalletTransactions(uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          I18n.inline(
                            'Не вдалося завантажити історію монет',
                            'Unable to load coin history',
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                    }
                    final docs = List<Map<String, dynamic>>.from(snapshot.data!)
                      ..sort((a, b) {
                        final at = a['timestamp'] as DateTime?;
                        final bt = b['timestamp'] as DateTime?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          I18n.inline('Поки немає транзакцій', 'No transactions yet'),
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
                        final ts = data['timestamp'] as DateTime?;
                        final timestampText = _formatRelativeMoment(ts);
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
    final uid = AppAuthContext.userId;
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
                            I18n.inline('Історія рейтингу', 'Rating history'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            I18n.inline(
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
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: context.read<ProfileRepository>().watchLegacyUserMap(uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          I18n.inline(
                            'Не вдалося завантажити історію рейтингу',
                            'Unable to load rating history',
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                      );
                    }

                    final userMap = snapshot.data ?? const <String, dynamic>{};
                    final rawList = userMap['ratingHistory'];
                    final entries = <Map<String, dynamic>>[];
                    if (rawList is List) {
                      for (final e in rawList) {
                        if (e is Map) {
                          entries.add(Map<String, dynamic>.from(e));
                        }
                      }
                    }
                    entries.sort((a, b) {
                      final at = profileRatingHistoryTimestamp(a['timestamp']);
                      final bt = profileRatingHistoryTimestamp(b['timestamp']);
                      if (at == null && bt == null) return 0;
                      if (at == null) return 1;
                      if (bt == null) return -1;
                      return bt.compareTo(at);
                    });

                    if (entries.isEmpty) {
                      return Center(
                        child: Text(
                          I18n.inline(
                            'Поки немає історії рейтингу',
                            'No rating history yet',
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final tsDt = profileRatingHistoryTimestamp(entry['timestamp']);

                        if (entry.containsKey('change')) {
                          final delta = (entry['change'] ?? 0.0).toDouble();
                          final oldRating =
                              (entry['oldRating'] ?? 0.0).toDouble();
                          final newRating =
                              (entry['newRating'] ?? 0.0).toDouble();
                          final reason = (entry['reason'] ?? '').toString();
                          final challengeTitle =
                              (entry['challengeTitle'] ?? '').toString();
                          final voterName =
                              (entry['voterName'] ?? '').toString();
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
                                      delta >= 0
                                          ? Icons.trending_up
                                          : Icons.trending_down,
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
                                if (tsDt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatRelativeMoment(tsDt),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        final overall =
                            (entry['overallRating'] ?? 0.0).toDouble();
                        final matchR =
                            (entry['matchRating'] ?? 0.0).toDouble();
                        final videoR =
                            (entry['videoRating'] ?? 0.0).toDouble();

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
                              Text(
                                I18n.inline(
                                  'Знімок рейтингу',
                                  'Rating snapshot',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                I18n.inline(
                                  'Загальний: ${overall.toStringAsFixed(2)} · Матчі: ${matchR.toStringAsFixed(2)} · Відео: ${videoR.toStringAsFixed(2)}',
                                  'Overall: ${overall.toStringAsFixed(2)} · Matches: ${matchR.toStringAsFixed(2)} · Videos: ${videoR.toStringAsFixed(2)}',
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              if (tsDt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatRelativeMoment(tsDt),
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
          return I18n.inline(
            '$voterName оцінив ваше відео "$challengeTitle"',
            '$voterName rated your video "$challengeTitle"',
          );
        }
        if (voterName.isNotEmpty) {
          return I18n.inline(
            '$voterName оцінив ваше відео',
            '$voterName rated your video',
          );
        }
        if (challengeTitle.isNotEmpty) {
          return I18n.inline(
            'Отримано оцінку за відео "$challengeTitle"',
            'Received a rating for video "$challengeTitle"',
          );
        }
        return I18n.inline(
          'Отримано оцінку за відео',
          'Received a video rating',
        );
      case 'challenge_win':
        return I18n.inline(
          'Перемога в челенджі "$challengeTitle"',
          'Challenge win "$challengeTitle"',
        );
      case 'challenge_second':
        return I18n.inline(
          '2-е місце в челенджі "$challengeTitle"',
          '2nd place in challenge "$challengeTitle"',
        );
      case 'challenge_third':
        return I18n.inline(
          '3-є місце в челенджі "$challengeTitle"',
          '3rd place in challenge "$challengeTitle"',
        );
      case 'match_rating':
        if (voterName.isNotEmpty) {
          return I18n.inline(
            '$voterName оцінив вас після матчу',
            '$voterName rated you after the match',
          );
        }
        return I18n.inline(
          'Оцінка після матчу',
          'Post-match rating',
        );
      case 'manual_recompute':
      case 'manual_recalculation':
      case 'system_recompute':
        return I18n.inline(
          'Перерахунок рейтингу системою',
          'System rating recalculation',
        );
      case 'penalty':
        return I18n.inline(
          'Штраф за порушення правил',
          'Penalty for rule violation',
        );
      case 'bonus':
        return I18n.inline('Бонус за активність', 'Activity bonus');
      default:
        if (reason == 'Оцінка після матчу') {
          return voterName.isNotEmpty
              ? I18n.inline(
                  '$voterName оцінив вас після матчу',
                  '$voterName rated you after the match',
                )
              : I18n.inline('Оцінка після матчу', 'Post-match rating');
        }
        return reason.isNotEmpty
            ? reason
            : I18n.inline('Зміна рейтингу', 'Rating change');
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

