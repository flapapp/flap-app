import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/city_localization.dart';
import '../../../../core/locale/football_position.dart';
import '../../../../utils/city_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import '../../../../widgets/mode_speed_dial.dart';
import '../../../../widgets/user_chip.dart';
import '../../../../widgets/team_logo_button.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../ratings/presentation/utils/rating_snapshot_source_label.dart';
import '../../../ratings/presentation/widgets/rating_history_snapshot_card.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../../application/match_participation_actions_use_case.dart';
import '../../data/models/match.dart';
import '../../domain/repositories/matches_repository.dart';
import 'finish_match_flow_page.dart';
import '../controllers/match_list_controller.dart';
import '../cubit/matches_list_cubit.dart';
import '../cubit/matches_list_state.dart';
import '../utils/match_status_ui.dart';
import '../widgets/match_waiting_list_strip.dart';

@RoutePage()
class MatchesScreen extends StatefulWidget {
  final int? initialTabIndex;

  const MatchesScreen({super.key, this.initialTabIndex});

  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with TickerProviderStateMixin {
  // Tab titles
  final List<String> _tabKeys = [
    'find_match',
    'my_matches',
    'history',
    'ratings',
  ];

  // Filter state variables
  late String _selectedCity;
  late String _selectedLevel;
  late String _selectedTime;
  late String _selectedSort;
  String _searchQuery = '';
  bool _filtersExpanded = false;
  final TextEditingController _cityFilterController = TextEditingController();
  String _currentUserCity = '';

  // Filter option lists
  List<String> get _cityOptions => [
    tr('all_cities'),
    tr('kyiv'),
    tr('kharkiv'),
    tr('odesa'),
    tr('dnipro'),
    tr('lviv'),
  ];

  List<String> get _levelOptions => [
    tr('all_levels'),
    tr('beginner'),
    tr('intermediate'),
    tr('advanced'),
    tr('professional'),
  ];

  List<String> get _timeOptions => [
    tr('anytime'),
    tr('il_2b065c7c9c'),
    tr('il_456a73bbce'),
    tr('il_8c4eef5ab2'),
  ];

  List<String> get _sortOptions => ['newest', 'my_city'];

  // "My matches" state variables
  String _selectedMyMatchesFilter =
      'all'; // 'all' | 'organized' | 'participation'

  // TabController for tab switching
  late TabController _tabController;
  bool _isLeaving = false;
  Timer? _searchDebounce;
  final Map<String, String> _teamNameCache = {};
  final Map<String, String> _teamLogoCache = {};

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
  }

  MatchesRepository get _matchRepo => sl<MatchesRepository>();
  late final MatchListController _matchListController;

  RatingsRepository get _ratingsRepo => sl<RatingsRepository>();
  final SupabaseClient _sb = Supabase.instance.client;
  static const List<Color> _finishMatchTeamColors = <Color>[
    Color(0xFF1976D2),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
    Color(0xFFFF7043),
  ];
  final NotificationService _notificationService = sl<NotificationService>();
  // Rating filter state (plain setState instead of ValueNotifier)
  String _ratingsSelectedCity = tr('all_cities');
  String _ratingsSelectedPosition = tr('il_0e333190c1');
  Future<List<Map<String, dynamic>>>? _ratingsTopPlayersFuture;

  MatchParticipationActionsUseCase get _participationActions =>
      sl<MatchParticipationActionsUseCase>();

  /// Join / apply in flight (find-match feed cards).
  final Set<String> _joinInFlightMatchIds = <String>{};

  /// Optimistic "requested" until [Match.pendingApplications] updates from stream.
  final Set<String> _joinRequestedLocalMatchIds = <String>{};

  late final MatchesListCubit _matchesListCubit;

  @override
  void initState() {
    super.initState();
    _matchListController = MatchListController(_matchRepo);
    _matchesListCubit = MatchesListCubit(_matchRepo)..load();
    _tabController = TabController(length: _tabKeys.length, vsync: this);
    _tabController.addListener(_onMatchesPrimaryTabChanged);

    // Initialize filters
    _selectedCity = tr('all_cities');
    _selectedLevel = tr('all_levels');
    _selectedTime = tr('anytime');
    _selectedSort = 'newest';
    _loadCurrentUserCity();

    final idx = widget.initialTabIndex;
    if (idx != null && idx >= 0 && idx < _tabKeys.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (idx < _tabController.length) {
          _tabController.index = idx;
        }
        if (idx == 3) {
          _ensureRatingsTopPlayersLoaded(force: true);
        }
      });
    }
  }

  /// Ratings tab loads a heavy leaderboard query; defer until that tab is opened.
  void _onMatchesPrimaryTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 3) {
      _ensureRatingsTopPlayersLoaded(force: true);
    }
  }

  void _refreshMatchLists() {
    if (!mounted) return;
    unawaited(_matchesListCubit.load());
  }

  void _ensureRatingsTopPlayersLoaded({bool force = false}) {
    if (_ratingsTopPlayersFuture != null && !force) return;
    _ratingsTopPlayersFuture = _ratingsRepo.getTopPlayers(limit: 300);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _matchesListCubit.close();
    _tabController.removeListener(_onMatchesPrimaryTabChanged);
    _searchDebounce?.cancel();
    _cityFilterController.dispose();
    _tabController.dispose();
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

  void _resetFindFilters() {
    setState(() {
      _selectedCity = tr('all_cities');
      _cityFilterController.clear();
      _selectedLevel = tr('all_levels');
      _selectedTime = tr('anytime');
      _selectedSort = 'newest';
      _searchQuery = '';
    });
  }

  // Build filter chips
  bool get _hasActiveFilters =>
      _cityFilterController.text.trim().isNotEmpty ||
      _selectedLevel != tr('all_levels') ||
      _selectedTime != tr('anytime') ||
      _searchQuery.isNotEmpty;

  Widget _buildFilterToggle() {
    final hasFilters = _hasActiveFilters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(
                _filtersExpanded ? Icons.filter_alt_off : Icons.filter_alt,
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('il_be8a172001'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _filtersExpanded
                          ? tr('il_9e6ea475a2')
                          : tr('il_de3c130792'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFilters)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tr('il_4a2689be5a'),
                    style: const TextStyle(
                      color: Color(0xFF4caf50),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              Icon(
                _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final bool narrow = constraints.maxWidth < 380;
              final city = SizedBox(
                width: double.infinity,
                child: CityAutocompleteField(
                  controller: _cityFilterController,
                  label: tr('city_label'),
                  requiredField: false,
                  includeAllOption: true,
                  style: const TextStyle(color: Colors.white),
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4caf50)),
                  ),
                  prefixIcon: const Icon(
                    Icons.location_city,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onSelected: (value) {
                    setState(() {
                      _selectedCity = value.trim().isEmpty
                          ? tr('all_cities')
                          : value.trim();
                    });
                  },
                ),
              );
              final level = SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  decoration: InputDecoration(
                    labelText: tr('level_label'),
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(
                      Icons.star,
                      color: Colors.white70,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF4caf50)),
                    ),
                  ),
                  dropdownColor: Color(0xFF070A08),
                  style: TextStyle(color: Colors.white),
                  items: _levelOptions
                      .map(
                        (level) => DropdownMenuItem(
                          value: level,
                          child: Text(
                            level,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLevel = value ?? tr('all_levels');
                    });
                  },
                ),
              );
              return narrow
                  ? Column(children: [city, SizedBox(height: 12), level])
                  : Row(
                      children: [
                        Expanded(child: city),
                        SizedBox(width: 16),
                        Expanded(child: level),
                      ],
                    );
            },
          ),
          SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool narrow = constraints.maxWidth < 380;
              final time = SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<String>(
                  value: _selectedTime,
                  decoration: InputDecoration(
                    labelText: tr('time_label'),
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(
                      Icons.access_time,
                      color: Colors.white70,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF4caf50)),
                    ),
                  ),
                  dropdownColor: Color(0xFF070A08),
                  style: TextStyle(color: Colors.white),
                  items: _timeOptions
                      .map(
                        (time) => DropdownMenuItem(
                          value: time,
                          child: Text(
                            time,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTime = value ?? tr('anytime');
                    });
                  },
                ),
              );
              final search = SizedBox(
                width: double.infinity,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: tr('search_label'),
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: tr('search_matches'),
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white70,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF4caf50)),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchQuery = value;
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (!mounted) return;
                        setState(() {});
                      },
                    );
                  },
                ),
              );
              return narrow
                  ? Column(children: [time, SizedBox(height: 12), search])
                  : Row(
                      children: [
                        Expanded(child: time),
                        SizedBox(width: 16),
                        Expanded(child: search),
                      ],
                    );
            },
          ),

          // Reset filters button
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _resetFindFilters,
                icon: Icon(Icons.refresh, color: Colors.white70, size: 18),
                label: Text(
                  tr('reset_filters'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  MatchListFilters _matchListFilters() {
    return MatchListFilters(
      selectedCity: _selectedCity,
      allCitiesLabel: tr('all_cities'),
      selectedLevel: _selectedLevel,
      allLevelsLabel: tr('all_levels'),
      selectedTime: _selectedTime,
      anytimeLabel: tr('anytime'),
      todayLabel: tr('il_2b065c7c9c'),
      tomorrowLabel: tr('il_456a73bbce'),
      weekLabel: tr('il_8c4eef5ab2'),
      selectedSort: _selectedSort,
      searchQuery: _searchQuery,
      currentUserCity: _currentUserCity,
    );
  }

  List<Match> _filteredAvailableMatches(MatchesListState listState) {
    return _matchListController.filterMatches(
      listState.availableMatches,
      _matchListFilters(),
      levelTextResolver: _getLevelText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 400;
    return BlocProvider.value(
      value: _matchesListCubit,
      child: Scaffold(
      backgroundColor: const Color(0xFF070A08),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF13241B), FlapColors.bg],
            ),
          ),
        ),
        title: InkWell(
          onTap: () => context.router.push(const ModeSelectionRoute()),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/logo/flap_logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Flap',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () =>
                        context.router.push(const NotificationsRoute()),
                    padding: EdgeInsets.zero,
                    tooltip: tr('notifications'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _sb
                .from('profiles')
                .stream(primaryKey: ['id'])
                .eq('id', AppAuth.currentUserId ?? ''),
            builder: (context, snapshot) {
              String avatarUrl = '';
              String displayName = '';
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isNotEmpty) {
                final d = rows.first;
                avatarUrl = (d['avatar_url'] ?? '').toString();
                displayName =
                    (d['display_name'] ??
                            d['email']?.toString().split('@').first ??
                            tr('il_a25513c7e0'))
                        .toString();
              }
              return IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => context.router.push(const ProfileRoute()),
                icon: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF4caf50),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],

        bottom: PreferredSize(
          preferredSize: Size.fromHeight(70),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                border: Border.all(color: FlapColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: _tabKeys
                    .map(
                      (key) => Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 6 : 8,
                          ),
                          child: Text(
                            tr(key),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isCompact ? 13 : 14,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicator: BoxDecoration(
                  color: const Color(0xFF4caf50),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Find match
          _buildFindMatchTab(),

          // TAB 2: My matches
          _buildMyMatchesTab(),

          // TAB 3: History
          _buildHistoryTab(),

          // TAB 4: Ratings
          _buildRatingsTab(),
        ],
      ),
      floatingActionButton: ModeSpeedDial(
        shortcuts: [
          ModeDialAction(
            icon: Icons.groups_outlined,
            tooltip: tr('teams'),
            onTap: () => context.router.push(const TeamHubRoute()),
          ),
          ModeDialAction(
            icon: Icons.play_circle_outline,
            tooltip: tr('videos'),
            onTap: () => context.router.push(VideoMainRoute()),
          ),
        ],
        onCreate: () async {
          await context.router.push(const CreateMatchRoute());
          if (!mounted) return;
          _refreshMatchLists();
        },
        createTooltip: tr('il_4759498ac2'),
      ),
      ),
    );
  }

  // ignore: unused_element
  void _showRatingModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0E1310),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1310),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF4caf50,
                              ).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('my_rating'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 18,
                        ),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Current rating
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 10,
                        color: Color(0xFF4caf50),
                      ),
                      const SizedBox(width: 8),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _sb
                            .from('profiles')
                            .stream(primaryKey: ['id'])
                            .eq('id', AppAuth.currentUserId ?? ''),
                        builder: (context, snapshot) {
                          final rows =
                              snapshot.data ?? const <Map<String, dynamic>>[];
                          final rating = rows.isNotEmpty
                              ? ((rows.first['rating'] ?? 0.0) as num)
                                    .toDouble()
                              : 0.0;
                          return RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${tr('current_rating')}: ',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: rating.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: '  '),
                                const WidgetSpan(
                                  child: Icon(
                                    Icons.star,
                                    color: Color(0xFFFFD700),
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // How the rating is calculated (detail)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e7d32).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF1e7d32).withValues(alpha: 0.40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF4caf50,
                          ).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            tr('how_rating_formed'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Formula
                        Text(
                          tr('formula'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('rating_formula'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 10),
                        // Weights
                        Text(
                          tr('weights'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('il_b7262e4ea5'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          tr('il_4cf022c9db'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 10),
                        // Matches
                        Text(
                          tr('il_8cb5668888'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('il_db707121f6'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          tr('il_006d502126'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          tr('il_a984b8b480'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 10),
                        // Videos / challenges
                        Text(
                          tr('il_4f71cbdf42'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('il_921f40cf93'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 10),
                        // Defense / anti-abuse
                        Text(
                          tr('il_b679eb4ef3'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('il_27eb1319c4'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 10),
                        // Player tiers
                        Text(
                          tr('il_8ea73ba2a4'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('il_98c956f0fe'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Rating change history (new)
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _sb
                        .from('profiles')
                        .stream(primaryKey: ['id'])
                        .eq('id', AppAuth.currentUserId ?? ''),
                    builder: (context, snap) {
                      final rows = snap.data ?? const <Map<String, dynamic>>[];
                      if (rows.isEmpty) return const SizedBox.shrink();
                      final data = rows.first;
                      final List<Map<String, dynamic>> history =
                          List<Map<String, dynamic>>.from(
                            data['ratingHistory'] ?? [],
                          );
                      if (history.isEmpty) return const SizedBox.shrink();

                      var publicHistory = history
                          .where(
                            (h) => ratingHistoryIsPublicTriggerSource(
                              (h['trigger_source'] ?? h['triggerSource'])
                                  ?.toString(),
                            ),
                          )
                          .toList();
                      if (publicHistory.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      // Newest first
                      publicHistory.sort((a, b) {
                        final ta = _readDate(a['timestamp']);
                        final tb = _readDate(b['timestamp']);
                        return tb.compareTo(ta);
                      });

                      return Column(
                        children: publicHistory.asMap().entries.map((e) {
                          final i = e.key;
                          final h = e.value;
                          final dt = _readDate(h['timestamp']);
                          final rawOverall = h['overallRating'] ?? h['rating'];
                          final overall = ((rawOverall ?? 0) as num).toDouble();
                          final rawPrev = i + 1 < publicHistory.length
                              ? (publicHistory[i + 1]['overallRating'] ??
                                  publicHistory[i + 1]['rating'])
                              : null;
                          final prev = rawPrev == null
                              ? null
                              : ((rawPrev ?? 0) as num).toDouble();
                          final delta = prev == null
                              ? null
                              : double.parse(
                                  (overall - prev).toStringAsFixed(2),
                                );
                          final triggerSrc = (h['trigger_source'] ??
                                  h['triggerSource'] ??
                                  '')
                              .toString()
                              .trim();

                          return RatingHistorySnapshotCard(
                            newRating: overall,
                            oldRating: prev,
                            delta: delta,
                            triggerSource:
                                triggerSrc.isEmpty ? null : triggerSrc,
                            detailSubtitle: delta == null
                                ? tr('rating_history_baseline')
                                : null,
                            timeLabel:
                                '${dt.day}.${dt.month}.${dt.year}',
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  void _showCoinsSheet(int currentCoins) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070A08),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Color(0xFFFFD700),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('my_coins'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            tr(
                              'il_7bd5596886',
                              namedArgs: {'currentCoins': '$currentCoins'},
                            ),
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('il_de7c340f64'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb
                      .from('coin_transactions')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', AppAuth.currentUserId ?? ''),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFD700),
                        ),
                      );
                    }
                    final txDocs = List<Map<String, dynamic>>.from(
                      snapshot.data ?? const <Map<String, dynamic>>[],
                    );
                    txDocs.sort((a, b) {
                      final at = _readDate(a['created_at']);
                      final bt = _readDate(b['created_at']);
                      return bt.compareTo(at);
                    });
                    if (txDocs.isEmpty) {
                      return Center(
                        child: Text(
                          tr('matches_no_transactions'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: txDocs.length,
                      itemBuilder: (context, index) {
                        final t = txDocs[index];
                        final amount = t['amount'] ?? 0;
                        final description = t['description'] ?? '';
                        final timestamp = _readDate(t['created_at']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: amount > 0
                                      ? const Color(
                                          0xFF4caf50,
                                        ).withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  amount > 0 ? Icons.add : Icons.remove,
                                  color: amount > 0
                                      ? const Color(0xFF4caf50)
                                      : Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatTransactionTime(timestamp),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${amount > 0 ? '+' : ''}$amount',
                                style: TextStyle(
                                  color: amount > 0
                                      ? const Color(0xFF4caf50)
                                      : Colors.red,
                                  fontSize: 16,
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

  DateTime _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      final dynamic v = value;
      final d = v?.toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatTransactionTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7) {
      return DateFormat.yMMMd(context.locale.toString()).format(dateTime);
    } else if (difference.inDays > 0) {
      return tr('il_adf8ee5f65', args: ['${difference.inDays}']);
    } else if (difference.inHours > 0) {
      return tr('il_7634d1849f', args: ['${difference.inHours}']);
    } else if (difference.inMinutes > 0) {
      return tr('il_e0b53645d6', args: ['${difference.inMinutes}']);
    } else {
      return tr('il_66f53417d3');
    }
  }

  // TAB 1: Find match
  Widget _buildFindMatchTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFilterToggle(),
          if (_filtersExpanded) _buildFilters(),

          // Available matches list
          BlocBuilder<MatchesListCubit, MatchesListState>(
            builder: (context, listState) {
              if (listState.status == MatchesListStatus.error) {
                return Center(
                  child: Text(
                    tr(
                      'il_c64c77589a',
                      args: [listState.errorMessage ?? ''],
                    ),
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (listState.isLoading &&
                  listState.availableMatches.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                );
              }

              final items = _filteredAvailableMatches(listState);
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.sports_soccer,
                        size: 64,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('matches_no_available'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('matches_no_available_hint'),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_alt,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('il_3a10c3ba9b', args: ['${items.length}']),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedSort,
                            underline: const SizedBox.shrink(),
                            dropdownColor: const Color(0xFF070A08),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            items: _sortOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option,
                                    child: Text(_sortLabel(option)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedSort = value;
                              });
                            },
                          ),
                        ),
                        TextButton(
                          onPressed: _resetFindFilters,
                          child: Text(
                            tr('reset_filters'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final match = items[index];
                      return _buildMatchCard(match);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // TAB 2: My matches
  Widget _buildMyMatchesTab() {
    return Column(
      children: [
        // Section header with Create match button
        _buildMyMatchesHeader(),

        // My matches filters
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              ChoiceChip(
                label: Text(tr('all')),
                selected: _selectedMyMatchesFilter == 'all',
                onSelected: (_) =>
                    setState(() => _selectedMyMatchesFilter = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(tr('organized')),
                selected: _selectedMyMatchesFilter == 'organized',
                onSelected: (_) =>
                    setState(() => _selectedMyMatchesFilter = 'organized'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(tr('participation')),
                selected: _selectedMyMatchesFilter == 'participation',
                onSelected: (_) =>
                    setState(() => _selectedMyMatchesFilter = 'participation'),
              ),
            ],
          ),
        ),

        // User's match list
        Expanded(
          child: BlocBuilder<MatchesListCubit, MatchesListState>(
            builder: (context, listState) {
              if (listState.status == MatchesListStatus.error) {
                return Center(
                  child: Text(
                    tr(
                      'il_c64c77589a',
                      args: [listState.errorMessage ?? ''],
                    ),
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (listState.isLoading && listState.userMatches.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                );
              }

              if (listState.userMatches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 64, color: Colors.white54),
                      SizedBox(height: 16),
                      Text(
                        tr('matches_no_user_matches'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('matches_no_user_matches_hint'),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final all = listState.userMatches;
              final currentUserId = AppAuth.currentUserId;
              List<Match> filtered = all;
              if (_selectedMyMatchesFilter == 'organized' &&
                  currentUserId != null) {
                filtered = all
                    .where((m) => m.organizerId == currentUserId)
                    .toList();
              } else if (_selectedMyMatchesFilter == 'participation' &&
                  currentUserId != null) {
                filtered = all
                    .where(
                      (m) =>
                          m.organizerId != currentUserId &&
                          m.isUserMatchMember(currentUserId),
                    )
                    .toList();
              }
              // Nearest matches first
              // Unplayed overdue at bottom; nearest upcoming at top
              filtered.sort((a, b) {
                if (a.isUnplayedByTimeout != b.isUnplayedByTimeout) {
                  return a.isUnplayedByTimeout ? 1 : -1;
                }
                return b.date.compareTo(a.date);
              });

              // Render user match list
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final match = filtered[index];
                  return _buildMyMatchCard(match);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // TAB 3: History
  Widget _buildHistoryTab() {
    return BlocBuilder<MatchesListCubit, MatchesListState>(
      builder: (context, listState) {
        if (listState.status == MatchesListStatus.error) {
          return Center(
            child: Text(
              tr('il_3a6e650bec', args: [listState.errorMessage ?? '']),
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (listState.isLoading && listState.historyMatches.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          );
        }
        final matches = listState.historyMatches;
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.white54),
                SizedBox(height: 12),
                Text(
                  tr('match_history_empty'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Section header (MVP style)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                tr('match_history'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Match list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final m = matches[index];
                  return _buildHistoryMatchCard(m);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // TAB 4: Ratings (MVP)
  Widget _buildRatingsTab() {
    // Reuse cached Future instead of creating a new one
    final topFuture =
        _ratingsTopPlayersFuture ?? Future.value(<Map<String, dynamic>>[]);
    final allPositionsLabel = tr('il_0e333190c1');

    // Local filter helpers (no dependency on external helpers)
    String norm(String? s) => (s ?? '').trim().toLowerCase();

    // DB/spelling variants per slug (`city_match_aliases_*` in translations).
    List<String> cityMatchAliasesForSlug(String slug) {
      final key = 'city_match_aliases_$slug';
      final raw = tr(key);
      if (raw == key) return const [];
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    bool cityMatches(String dbCity, String selectedUi) {
      final db = norm(dbCity);
      final sel = norm(selectedUi);
      if (db == sel) return true;
      final slug = CityCatalog.toEnglishStorageKey(selectedUi);
      if (slug == null || slug.isEmpty) return false;
      final extras = cityMatchAliasesForSlug(slug);
      if (extras.isEmpty) return false;
      final aliases = <String>{sel, ...extras.map(norm)};
      return aliases.contains(db);
    }

    // Position codes
    String toCode(String uiOrCode) {
      return positionToEnglishDb(uiOrCode) ?? uiOrCode;
    }

    // Compact unlabeled dropdown
    Widget narrowDropdown({
      required String value,
      required List<String> options,
      required ValueChanged<String?> onChanged,
      Key? key,
    }) {
      final String safeValue = options.contains(value)
          ? value
          : (options.isNotEmpty ? options.first : '');
      return SizedBox(
        width: 160,
        child: DropdownButtonFormField<String>(
          key: key,
          value: options.isNotEmpty ? safeValue : null,
          items: options
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(v, style: const TextStyle(color: Colors.white)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF0B0F0C),
          iconEnabledColor: Colors.white70,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF4caf50), width: 1.5),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + manual recount
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  tr('ratings_title'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Sub-tabs
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: SizedBox(
                height: 56, // Room for two lines
                child: TabBar(
                  isScrollable: false,
                  labelPadding: const EdgeInsets.symmetric(vertical: 6),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicator: BoxDecoration(
                    color: const Color(0xFF4caf50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tabs: [
                    Tab(
                      child: Center(
                        child: Text(
                          tr('il_e08c0a239b'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                    Tab(
                      child: Center(
                        child: Text(
                          tr('il_5d34135df2'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Tab(
                      child: Center(
                        child: Text(
                          tr('il_252d7af35a'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Tab(
                      child: Center(
                        child: Text(
                          tr('il_32e5400485'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Body content
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: topFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                  );
                }
                final all = (snap.data ?? const <Map<String, dynamic>>[])
                    .toList();

                // Sort by rating descending
                all.sort((a, b) {
                  final ar = ((a['rating'] ?? 0) as num).toDouble();
                  final br = ((b['rating'] ?? 0) as num).toDouble();
                  return br.compareTo(ar);
                });

                return TabBarView(
                  key: ValueKey(
                    'ratings_${_ratingsSelectedCity}_${_ratingsSelectedPosition}',
                  ),
                  children: [
                    // 1) Overall rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                          child: Text(
                            tr('il_ccd407766c'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                            itemCount: all.length,
                            itemBuilder: (context, i) =>
                                _buildRatingItem(all[i], i + 1),
                          ),
                        ),
                      ],
                    ),

                    // 2) By city
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Row(
                            children: [
                              narrowDropdown(
                                value: _ratingsSelectedCity,
                                options: _cityOptions,
                                onChanged: (v) {
                                  setState(() {
                                    _ratingsSelectedCity =
                                        v ?? tr('all_cities');
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                          child: Text(
                            tr('il_ccd407766c'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: () {
                            final String? cityFilter =
                                (_ratingsSelectedCity == tr('all_cities'))
                                ? null
                                : _ratingsSelectedCity;
                            final list = (cityFilter == null)
                                ? all
                                : all
                                      .where(
                                        (p) => cityMatches(
                                          (p['city'] ?? '').toString(),
                                          cityFilter,
                                        ),
                                      )
                                      .toList();
                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  tr('empty_for_city'),
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                              itemCount: list.length,
                              itemBuilder: (context, i) =>
                                  _buildRatingItem(list[i], i + 1),
                            );
                          }(),
                        ),
                      ],
                    ),

                    // 3) By position
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Row(
                            children: [
                              narrowDropdown(
                                value: _ratingsSelectedPosition,
                                options: [
                                  tr('il_0e333190c1'),
                                  tr('il_f2d20c7ee1'),
                                  tr('il_157ddc59b5'),
                                  tr('il_d332e47845'),
                                  tr('il_f1c65e1481'),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _ratingsSelectedPosition =
                                        v ?? allPositionsLabel;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                          child: Text(
                            tr('il_ccd407766c'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: () {
                            final allPositionsLabel = tr('il_0e333190c1');
                            final String? positionFilter =
                                (_ratingsSelectedPosition == allPositionsLabel)
                                ? null
                                : toCode(_ratingsSelectedPosition);
                            final list = (positionFilter == null)
                                ? all
                                : all.where((p) {
                                    final raw = (p['position'] ?? '')
                                        .toString();
                                    final dbCode =
                                        [
                                          'goalkeeper',
                                          'defender',
                                          'midfielder',
                                          'forward',
                                        ].contains(raw)
                                        ? raw
                                        : toCode(raw);
                                    return norm(dbCode) == norm(positionFilter);
                                  }).toList();
                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  tr('empty_for_position'),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                              itemCount: list.length,
                              itemBuilder: (context, i) =>
                                  _buildRatingItem(list[i], i + 1),
                            );
                          }(),
                        ),
                      ],
                    ),

                    // 4) My stats
                    Builder(
                      builder: (context) {
                        final uid = AppAuth.currentUserId;
                        if (uid == null) {
                          return Center(
                            child: Text(
                              tr('sign_in_for_stats'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        }
                        return FutureBuilder<Map<String, dynamic>>(
                          future: _ratingsRepo.getUserRatingStats(uid),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4caf50),
                                ),
                              );
                            }
                            final s = snap.data ?? const {};
                            final current = ((s['currentRating'] ?? 3.0) as num)
                                .toDouble();
                            final m = ((s['matchRating'] ?? 3.0) as num)
                                .toDouble();
                            final v = ((s['videoRating'] ?? 3.0) as num)
                                .toDouble();
                            final tm = (s['totalMatches'] ?? 0).toString();
                            final tv = (s['totalVideos'] ?? 0).toString();

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                16,
                              ),
                              children: [
                                _statTile(tr('current_rating'), current),
                                const SizedBox(height: 8),
                                _statTile(tr('match_rating_70'), m),
                                const SizedBox(height: 8),
                                _statTile(tr('video_rating_30'), v),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _chipStat(
                                      Icons.sports_soccer,
                                      tr('il_98abff28a9'),
                                      tm,
                                    ),
                                    const SizedBox(width: 8),
                                    _chipStat(
                                      Icons.videocam,
                                      tr('il_c9a9639463'),
                                      tv,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const SizedBox.shrink(),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTapJoinMatch(Match match) async {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    if (_joinInFlightMatchIds.contains(match.id)) return;

    if (match.organizerId == uid) return;
    if (match.isUnplayedByTimeout) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_d11de119cf'))));
      return;
    }
    if (match.status == MatchStatus.cancelled) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('status_cancelled'))));
      return;
    }
    if (match.isTeamMatch) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_4d74338dc3'))));
      return;
    }
    if (match.isPrivate && !match.invitedFriends.contains(uid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('private_match_invite_only'))));
      return;
    }
    if (match.isUserMatchMember(uid) ||
        match.hasPendingApplication(uid) ||
        _joinRequestedLocalMatchIds.contains(match.id)) {
      return;
    }
    if (match.wasRejected(uid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_3bbca810b0'))));
      return;
    }
    if (match.status != MatchStatus.open ||
        match.currentPlayers >= match.maxPlayers) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_1b3438d9c8'))));
      return;
    }

    setState(() => _joinInFlightMatchIds.add(match.id));
    try {
      final ok = await _participationActions.applyForMatch(
        matchId: match.id,
        userId: uid,
      );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _joinRequestedLocalMatchIds.add(match.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('applied_wait')),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
        _refreshMatchLists();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('already_applied')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _joinInFlightMatchIds.remove(match.id));
      }
    }
  }

  Widget _buildMatchSecondaryAction(Match match, String uid) {
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: FlapColors.text,
      disabledForegroundColor: FlapColors.muted,
      side: const BorderSide(color: FlapColors.borderStrong),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    const labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    if (match.organizerId == uid) {
      // Organizer manages via tapping the card; ownership shown as a top-right
      // badge instead of a bottom action (see _matchCardTop / _ownerBadge).
      return const SizedBox.shrink();
    }

    if (match.getUserStatus(uid) == 'participant') {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: Text(
          tr('match_joined_short'),
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        style: buttonStyle,
      );
    }

    final requested =
        match.hasPendingApplication(uid) ||
        _joinRequestedLocalMatchIds.contains(match.id);
    if (requested) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.mark_email_read_outlined, size: 16),
        label: Text(
          tr('match_feed_join_requested'),
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        style: buttonStyle,
      );
    }

    if (match.wasRejected(uid)) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.block, size: 16),
        label: Text(
          tr('il_3bbca810b0'),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: labelStyle,
        ),
        style: buttonStyle,
      );
    }

    if (match.isTeamMatch) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.groups, size: 16),
        label: Text(
          tr('join'),
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        style: buttonStyle,
      );
    }

    if (match.isPrivate && !match.invitedFriends.contains(uid)) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_outline, size: 16),
        label: Text(
          tr('join'),
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        style: buttonStyle,
      );
    }

    if (match.status == MatchStatus.finished ||
        match.status == MatchStatus.inProgress) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.event_busy, size: 16),
        label: Text(
          match.statusText,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        style: buttonStyle,
      );
    }

    if (match.status == MatchStatus.full ||
        match.currentPlayers >= match.maxPlayers) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.groups, size: 16),
        label: Text(
          tr('status_full'),
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        style: buttonStyle,
      );
    }

    final loading = _joinInFlightMatchIds.contains(match.id);
    return OutlinedButton.icon(
      onPressed: loading ? null : () => _onTapJoinMatch(match),
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            )
          : const Icon(Icons.person_add_outlined, size: 16),
      label: Text(
        loading ? tr('player_add_friend_sending') : tr('join'),
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      ),
      style: buttonStyle,
    );
  }

  // Average participant rating
  Future<double> _calculateAverageRating(List<String> participantIds) async {
    try {
      if (participantIds.isEmpty) return 3.0; // Default rating

      double totalRating = 0.0;
      int ratedParticipants = 0;

      for (final participantId in participantIds) {
        final rating = await _ratingsRepo.getUserRating(participantId);
        totalRating += rating;
        ratedParticipants++;
      }

      return ratedParticipants > 0 ? totalRating / ratedParticipants : 3.0;
    } catch (e) {
      print('Error calculating average rating: $e');
      return 3.0;
    }
  }

  // Match card builder (design `.mcard`: date block · meta · pills /
  // avatar stack · spots · eligibility tag, with join actions preserved).
  Widget _buildMatchCard(Match match) {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return SizedBox.shrink();

    final isOrganizer = match.organizerId == currentUser.id;

    // Functional section content. The state-aware action (Join / Joined /
    // Requested …) now lives in the top-right corner; organizers show an
    // ownership badge there and team matches show only the "Team match" tag.
    final functional = <Widget>[
      if (_shouldShowMatchWaitingList(match))
        MatchWaitingListStrip(pendingUserIds: match.pendingApplications),
      if (match.coverPhotoUrl?.isNotEmpty == true) _buildMatchPhotoFooter(match),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Tap anywhere on the card (except the inner buttons) → details.
          onTap: () => context.router.push(MatchDetailsRoute(match: match)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- top: date block + info ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                child: _matchCardTop(
                  match,
                  trailing:
                      _cornerTrailing(match, isOrganizer, currentUser.id),
                ),
              ),
              // ---- bottom: avatar stack + spots + eligibility tag ----
              _matchCardBottom(match),
              // ---- functional section (logic preserved) ----
              if (functional.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < functional.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        functional[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- design match-card pieces ----

  Widget _matchCardTop(Match match, {Widget? trailing}) {
    final dt = match.scheduledDateTime;
    final locale = context.locale.toString();
    final month = DateFormat.MMM(locale).format(dt).toUpperCase();
    final weekday = DateFormat.E(locale).format(dt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // date block
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: FlapColors.border),
          ),
          child: Column(
            children: [
              Text('${dt.day}',
                  style: FlapText.cond(fontSize: 22, height: 0.9)),
              const SizedBox(height: 2),
              Text(month,
                  style: FlapText.sora(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.muted,
                    letterSpacing: 1,
                  )),
            ],
          ),
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
                    child: Text(
                      match.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing,
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  _metaItem(Icons.schedule, '$weekday · ${match.scheduledKickoffTimeLabel}'),
                  _metaItem(Icons.place_outlined, match.location.split(',').first),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  _pill(Icons.bar_chart_rounded, _getLevelText(match.level)),
                  const SizedBox(width: 8),
                  _pill(
                    Icons.monetization_on_outlined,
                    match.cost <= 0
                        ? tr('match_cost_free')
                        : '${match.cost.toInt()} ₴',
                    iconColor: FlapColors.gold,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: FlapColors.greenBright),
        const SizedBox(width: 5),
        Text(text,
            style: FlapText.sora(fontSize: 12, color: FlapColors.muted)),
      ],
    );
  }

  Widget _pill(IconData icon, String text, {Color iconColor = FlapColors.text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(text,
              style: FlapText.sora(
                  fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _matchCardBottom(Match match) {
    final filled = match.participants.length;
    final cap = match.maxPlayers;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0x05FFFFFF),
        border: Border(top: BorderSide(color: FlapColors.border)),
      ),
      child: Row(
        children: [
          _avatarStack(match.participants),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$filled',
                  style: FlapText.sora(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '/$cap ${tr('players')}',
                  style: FlapText.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FlapColors.muted),
                ),
              ],
            ),
          ),
          const Spacer(),
          _eligibilityTag(match, filled, cap),
        ],
      ),
    );
  }

  Widget _avatarStack(List<String> ids) {
    final shown = ids.take(3).toList();
    if (shown.isEmpty) return const SizedBox(width: 0, height: 30);
    const outer = 30.0;
    const step = 18.0;
    return SizedBox(
      width: outer + step * (shown.length - 1),
      height: outer,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: FlapColors.card, width: 2),
                ),
                child: UserChip(userId: shown[i], size: 26, showName: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eligibilityTag(Match match, int filled, int cap) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String label;
    if (match.isTeamMatch) {
      bg = const Color(0x265C97E0);
      fg = FlapColors.blue;
      icon = Icons.shield_outlined;
      label = tr('match_tag_team');
    } else if (cap > 0 && filled >= cap) {
      bg = const Color(0x10FFFFFF);
      fg = FlapColors.muted;
      icon = Icons.people_alt_outlined;
      label = tr('match_tag_full');
    } else {
      bg = const Color(0x294CAF50);
      fg = FlapColors.greenBright;
      icon = Icons.add_rounded;
      label = tr('match_tag_open');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: FlapText.sora(
                  fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  // Top-right corner widget for upcoming/active cards: ownership badge for
  // organizers, the compact state action for joinable matches, nothing for
  // team matches (join is team-invite only).
  Widget? _cornerTrailing(Match match, bool isOrganizer, String uid) {
    if (isOrganizer) return _ownerBadge();
    if (match.isTeamMatch) return null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: _buildMatchSecondaryAction(match, uid),
    );
  }

  // Compact top-right ownership badge for matches you organize.
  Widget _ownerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x1A4CAF50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x334CAF50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded,
              size: 12, color: FlapColors.greenBright),
          const SizedBox(width: 4),
          Text(
            tr('match_your_match'),
            style: FlapText.sora(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FlapColors.greenBright,
            ),
          ),
        ],
      ),
    );
  }

  // Superseded by the corner action (kept for reference).
  // ignore: unused_element
  Widget _buildJoinedIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4caf50).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF4caf50).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFF81C784)),
          const SizedBox(width: 6),
          Text(
            tr('match_joined_short'),
            style: const TextStyle(
              color: Color(0xFFE8F5E9),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchPhotoFooter(Match match) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              match.coverPhotoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('il_f8077f8181'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (match.teamAScore != null && match.teamBScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${match.teamAScore}:${match.teamBScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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

  bool _shouldShowMatchWaitingList(Match match) {
    if (match.pendingApplications.isEmpty) return false;
    switch (match.status) {
      case MatchStatus.inProgress:
      case MatchStatus.finished:
      case MatchStatus.cancelled:
        return false;
      case MatchStatus.open:
      case MatchStatus.full:
        return true;
    }
  }

  // Retained for reference; superseded by the design match-card pieces above.
  // ignore: unused_element
  Widget _buildMatchDetails(Match match) {
    final totalParticipants = match.participants.length;
    final confirmedCount = match.isTeamMatch
        ? match.confirmedParticipantsCount
        : totalParticipants;

    return Column(
      children: [
        // Kickoff (from scheduled_at via date + time)
        Row(
          children: [
            const Icon(Icons.schedule, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(
                  'match_card_short_date_time',
                  namedArgs: {
                    'day': '${match.scheduledDateTime.day}',
                    'month': '${match.scheduledDateTime.month}',
                    'time': match.scheduledKickoffTimeLabel,
                  },
                ),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),

        SizedBox(height: 6),

        // Location
        Row(
          children: [
            Icon(Icons.location_city, color: Colors.white70, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                match.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),

        SizedBox(height: 6),

        // Difficulty level
        Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 16),
            SizedBox(width: 8),
            Text(
              '${tr('level_colon')} ${_getLevelText(match.level)}',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),

        SizedBox(height: 8),

        // Avg. participant rating (MVP)
        FutureBuilder<double>(
          future: _calculateAverageRating(match.participants),
          builder: (context, snap) {
            final avg = (snap.hasData ? snap.data! : 0.0).toStringAsFixed(2);
            return Row(
              children: [
                Icon(Icons.star, color: Color(0xFFFFD54F), size: 16),
                SizedBox(width: 8),
                Text(
                  '${tr('average_rating')}: $avg',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            );
          },
        ),

        SizedBox(height: 8),

        // Players with avatars
        // Player count + status chip (single row)
        Row(
          children: [
            Icon(Icons.people, color: Colors.white70, size: 16),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalParticipants/${match.maxPlayers} ${tr('participants')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (match.isTeamMatch)
                  Text(
                    tr(
                      'il_83aab55000',
                      namedArgs: {'confirmedCount': '$confirmedCount'},
                    ),
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
            Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(match.status, match: match),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusText(match.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (match.isTeamMatch) ...[
          const SizedBox(height: 4),
          _buildTeamMatchBanner(match),
        ],

        // Avatars on their own row to avoid overflow
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            children: match.participants.take(10).map((id) {
              return Container(
                margin: const EdgeInsets.only(right: 6),
                child: UserChip(userId: id, size: 22, showName: false),
              );
            }).toList(),
          ),
        ),

        if (_shouldShowMatchWaitingList(match)) ...[
          const SizedBox(height: 10),
          MatchWaitingListStrip(pendingUserIds: match.pendingApplications),
        ],

        SizedBox(height: 8),

        // Organizer (same as participant chips — loads avatar_url from profiles)
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: UserChip(
                userId: match.organizerId,
                name: match.organizerName.isNotEmpty
                    ? match.organizerName
                    : null,
                size: 36,
                showName: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('organizer'),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    match.organizerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Superseded by the corner action + functional list (kept for reference).
  // ignore: unused_element
  Widget _buildActionButtons(Match match, String currentUserId) {
    final isOrganizer = match.organizerId == currentUserId;
    final isTeamListedMember = match.isUserMatchMember(currentUserId);
    if (match.isTeamMatch && !isOrganizer && !isTeamListedMember) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('il_4d74338dc3'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailActionRow(match, currentUserId),
        ],
      );
    }

    // Private match — invite only
    if (match.isPrivate && !match.invitedFriends.contains(currentUserId)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('private_match_invite_only'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailActionRow(match, currentUserId),
        ],
      );
    }

    return _buildDetailActionRow(match, currentUserId);
  }

  Widget _buildDetailActionRow(Match match, String currentUserId) {
    // Details is reached by tapping the card; the primary action spans full width.
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: _buildMatchSecondaryAction(match, currentUserId),
    );
  }

  Widget _buildTeamMatchBanner(Match match) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sb
          .from('team_match_requests')
          .stream(primaryKey: ['id'])
          .map(
            (rows) => (rows as List<dynamic>)
                .map((raw) => Map<String, dynamic>.from(raw as Map))
                .where((row) => (row['match_id'] ?? '').toString() == match.id)
                .toList(growable: false),
          ),
      builder: (context, snapshot) {
        final invite = _resolveListTeamInviteRequest(match, snapshot.data ?? const []);
        final creatorTeamId = (match.teamAId ?? '').trim().isNotEmpty
            ? (match.teamAId ?? '').trim()
            : (invite?['requesting_team_id'] ?? '').toString();
        final invitedTeamId = (invite?['target_team_id'] ?? '').toString();
        final creatorStatus = match.teamAStatus ?? 'confirmed';
        final invitedStatus = (invite?['status'] ?? match.teamBStatus ?? 'pending').toString();

        return FutureBuilder<List<Map<String, String?>>>(
          future: Future.wait([
            _resolveTeamSummary(
              teamId: creatorTeamId,
              fallbackName: match.teamA?.name,
              fallbackLabel: tr('il_d161440e8d'),
            ),
            _resolveTeamSummary(
              teamId: invitedTeamId,
              fallbackName: match.teamB?.name,
              fallbackLabel: tr('il_852ae4ce70'),
            ),
          ]),
          builder: (context, summarySnap) {
            final summaries = summarySnap.data;
            final host = (summaries != null && summaries.isNotEmpty)
                ? summaries[0]
                : <String, String?>{'id': creatorTeamId, 'name': tr('il_d161440e8d'), 'logoUrl': null};
            final invited = (summaries != null && summaries.length == 2)
                ? summaries[1]
                : <String, String?>{'id': invitedTeamId, 'name': tr('il_852ae4ce70'), 'logoUrl': null};
            final waiting = invitedTeamId.isEmpty;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.sports_soccer,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('il_4f76cec7a7'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTeamMatchRow(
                    sectionLabel: tr('il_d161440e8d'),
                    teamId: host['id'] ?? '',
                    teamName: host['name'] ?? tr('il_d161440e8d'),
                    logoUrl: host['logoUrl'],
                    status: creatorStatus,
                  ),
                  const SizedBox(height: 14),
                  _buildTeamMatchRow(
                    sectionLabel: waiting ? tr('il_852ae4ce70') : tr('il_6b3e8cd77f'),
                    teamId: invited['id'] ?? '',
                    teamName: invited['name'] ?? tr('il_852ae4ce70'),
                    logoUrl: invited['logoUrl'],
                    status: invitedStatus,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamMatchRow({
    required String sectionLabel,
    required String teamId,
    required String teamName,
    required String? logoUrl,
    required String status,
  }) {
    const logoSize = 32.0;
    final trimmedLabel = sectionLabel.trimRight();
    final labelText =
        trimmedLabel.endsWith(':') ? trimmedLabel : '$trimmedLabel:';
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.72),
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
      height: 1.3,
    );
    final nameStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.98),
      fontWeight: FontWeight.w700,
      fontSize: 15,
      height: 1.25,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TeamLogoButton(
            teamId: teamId,
            teamName: teamName,
            logoUrl: logoUrl,
            size: logoSize,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                labelText,
                style: labelStyle,
                softWrap: true,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      teamName,
                      style: nameStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: _buildTeamStatusChip(status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Map<String, String?>> _resolveTeamSummary({
    required String? teamId,
    required String? fallbackName,
    required String fallbackLabel,
  }) async {
    final cleanFallback = (fallbackName ?? '').trim();
    if (cleanFallback.isNotEmpty &&
        cleanFallback != tr('il_d161440e8d') &&
        cleanFallback != tr('il_6b3e8cd77f') &&
        cleanFallback != tr('il_852ae4ce70')) {
      return <String, String?>{
        'id': (teamId ?? '').trim(),
        'name': cleanFallback,
        'logoUrl': null,
      };
    }
    final id = (teamId ?? '').trim();
    if (id.isEmpty) {
      return <String, String?>{
        'id': '',
        'name': fallbackLabel,
        'logoUrl': null,
      };
    }
    if (_teamNameCache.containsKey(id)) {
      return <String, String?>{
        'id': id,
        'name': _teamNameCache[id],
        'logoUrl': _teamLogoCache[id],
      };
    }
    try {
      final row =
          await _sb.from('teams').select('name,logo_url').eq('id', id).maybeSingle();
      final name = (row?['name'] ?? '').toString().trim();
      final logo = (row?['logo_url'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        _teamNameCache[id] = name;
        _teamLogoCache[id] = logo;
        return <String, String?>{
          'id': id,
          'name': name,
          'logoUrl': logo.isEmpty ? null : logo,
        };
      }
    } catch (_) {}
    return <String, String?>{
      'id': id,
      'name': cleanFallback.isNotEmpty ? cleanFallback : fallbackLabel,
      'logoUrl': null,
    };
  }

  Map<String, dynamic>? _resolveListTeamInviteRequest(
    Match match,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return null;
    final hostTeamId = (match.teamAId ?? '').trim();
    final invitedTeamId = (match.teamBId ?? '').trim();
    final valid = rows.where((row) {
      final status = (row['status'] ?? '').toString();
      return status == 'pending' || status == 'accepted' || status == 'declined';
    }).toList(growable: false);
    if (valid.isEmpty) return null;

    List<Map<String, dynamic>> scoped = valid;
    if (hostTeamId.isNotEmpty) {
      scoped = scoped.where((row) {
        final requesting = (row['requesting_team_id'] ?? '').toString();
        final target = (row['target_team_id'] ?? '').toString();
        return requesting == hostTeamId && target != hostTeamId;
      }).toList(growable: false);
    }
    if (invitedTeamId.isNotEmpty) {
      final byInvitedId = scoped.where((row) {
        final target = (row['target_team_id'] ?? '').toString();
        return target == invitedTeamId;
      }).toList(growable: false);
      if (byInvitedId.isNotEmpty) {
        scoped = byInvitedId;
      }
    }
    if (scoped.isEmpty) {
      scoped = valid.where((row) {
        final createdBy = (row['created_by'] ?? '').toString();
        final requesting = (row['requesting_team_id'] ?? '').toString();
        final target = (row['target_team_id'] ?? '').toString();
        return createdBy == match.organizerId && requesting != target;
      }).toList(growable: false);
    }
    final pool = scoped.isNotEmpty ? scoped : valid;
    pool.sort((a, b) {
      final aDate = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return pool.first;
  }

  Widget _buildTeamStatusChip(String status) {
    final text = _getTeamStatusText(status);
    final color = _getTeamStatusColor(status);
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
    );
  }

  String _getTeamStatusText(String? status) {
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return tr('il_fe00b67b6d');
      case 'declined':
        return tr('il_dce083a2c4');
      default:
        return tr('il_331551b0de');
    }
  }

  Color _getTeamStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }

  String _sortLabel(String key) {
    switch (key) {
      case 'my_city':
        return tr('il_fd59d53cdc');
      case 'newest':
      default:
        return tr('il_ffb6f5764b');
    }
  }

  // Status color helper
  Color _getStatusColor(MatchStatus status, {Match? match}) {
    return buildMatchListStatusUi(status, match: match).color;
  }

  String _getStatusText(MatchStatus status, {Match? match}) {
    return buildMatchListStatusUi(status, match: match).label;
  }

  String _getLevelText(MatchLevel level) {
    switch (level) {
      case MatchLevel.beginner:
        return tr('beginner');
      case MatchLevel.intermediate:
        return tr('intermediate');
      case MatchLevel.advanced:
        return tr('advanced');
      case MatchLevel.professional:
        return tr('professional');
    }
  }

  // My matches section header
  Widget _buildMyMatchesHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tr('my_matches'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.router.push(const CreateMatchRoute());
              if (!mounted) return;
              _refreshMatchLists();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4caf50),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              tr('create_match'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // My matches card
  // version_0.1/lib/screens/matches_screen.dart

  Widget _buildMyMatchCard(Match match) {
    final currentUser = AppAuth.currentUser;
    final uid = currentUser?.id ?? '';
    final isOrganizer = AppAuth.currentUserId == match.organizerId;

    // Functional actions live below the design strip. Details is reached by
    // tapping the card; ownership/state shows in the top-right corner.
    final actions = <Widget>[];

    if (isOrganizer &&
        match.status != MatchStatus.finished &&
        match.status != MatchStatus.cancelled &&
        !match.isUnplayedByTimeout) {
      actions.add(
        ElevatedButton(
          onPressed: () {
            context.router.push(MatchManagementRoute(match: match));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4caf50),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            tr('manage'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (!isOrganizer &&
        match.status == MatchStatus.open &&
        !match.isUnplayedByTimeout &&
        currentUser != null &&
        match.participants.contains(currentUser.id)) {
      actions.add(
        ElevatedButton(
          onPressed: _isLeaving
              ? null
              : () async {
                  final sure = await _confirm(
                    tr('leave_match_confirm'),
                    tr('leave_match_sure'),
                  );
                  if (sure != true) return;
                  setState(() => _isLeaving = true);
                  await _onLeaveMatch(match);
                  setState(() => _isLeaving = false);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _isLeaving ? tr('leaving') : tr('leave_match'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (isOrganizer &&
        match.status != MatchStatus.cancelled &&
        !match.isUnplayedByTimeout) {
      actions.add(
        Builder(
          builder: (context) {
            final canStartNow = match.hasTeams
                ? match.hasConfirmedPlayersForBothTeams
                : match.participants.length >= 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!match.hasTeams &&
                        match.participants.length >= 4 &&
                        match.status != MatchStatus.finished)
                      ElevatedButton(
                        onPressed: () async {
                          final sure = await _confirm(
                            tr('matches_autobalance_confirm_title'),
                            tr('matches_autobalance_confirm_body'),
                          );
                          if (sure != true) return;
                          await _onAutoBalance(match);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF66bb6a),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          tr('matches_autobalance_action'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (!match.hasTeams && match.participants.length >= 4)
                      const SizedBox(width: 8),
                    if (match.hasTeams &&
                        match.status != MatchStatus.inProgress &&
                        match.status != MatchStatus.finished)
                      ElevatedButton(
                        onPressed: canStartNow
                            ? () async {
                                final sure = await _confirm(
                                  tr('matches_start_confirm_title'),
                                  tr('matches_start_confirm_body'),
                                );
                                if (sure != true) return;
                                await _onStartMatch(match);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canStartNow
                              ? const Color(0xFF2196f3)
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          tr('action_start_match_ui'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (match.status != MatchStatus.inProgress &&
                        match.hasTeams)
                      const SizedBox(width: 8),
                    if (match.status == MatchStatus.inProgress)
                      ElevatedButton(
                        onPressed: () async {
                          final sure = await _confirm(
                            '${tr('finish_match')}?',
                            tr('il_a2eff0d408'),
                          );
                          if (sure != true) return;
                          await _onFinishMatch(match);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          tr('finish_match'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                if (match.hasTeams &&
                    match.status == MatchStatus.open &&
                    !canStartNow)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tr('il_72b3134a15'),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    if (!isOrganizer) {
      actions.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('il_508bc5f440'),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.router.push(MatchDetailsRoute(match: match)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                child: _matchCardTop(
                  match,
                  trailing: _cornerTrailing(match, isOrganizer, uid),
                ),
              ),
              _matchCardBottom(match),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        actions[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Leave match flow
  Future<void> _onLeaveMatch(Match match) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_1141023944')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final ok = await _matchRepo.leaveMatch(match.id, currentUser.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? tr('left_match') : tr('leave_failed')),
          backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
        ),
      );
      if (ok) setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Organizer actions
  Future<void> _onAutoBalance(Match match) async {
    final ok = await _matchRepo.autoBalanceTeams(match.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? tr('teams_balanced') : tr('teams_balance_failed')),
        backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
      ),
    );
    if (ok) setState(() {});
  }

  Future<void> _onStartMatch(Match match) async {
    final ok = await _matchRepo.startMatch(match.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? tr('match_started') : tr('match_start_failed')),
        backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
      ),
    );
    if (ok) setState(() {});
  }

  Future<void> _onFinishMatch(Match match) async {
    final result = await Navigator.of(context).push<FinishMatchResult?>(
      MaterialPageRoute<FinishMatchResult?>(
        fullscreenDialog: true,
        builder: (_) => FinishMatchFlowPage(
          match: match,
          participantIds: match.participants,
          teamColors: _finishMatchTeamColors,
          loadPlayerRows: (ids) => loadFinishMatchPlayerRows(_sb, ids),
        ),
      ),
    );
    if (!mounted || result == null) return;

    final MatchResult matchResult = result.teamAScore > result.teamBScore
        ? MatchResult.teamAWins
        : result.teamBScore > result.teamAScore
        ? MatchResult.teamBWins
        : MatchResult.draw;

    final ok = await _matchRepo.finishMatch(
      match.id,
      matchResult,
      result.teamAScore,
      result.teamBScore,
      goalsByPlayer: result.goalsByPlayer,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? tr('il_a7c0f718a2') : tr('il_9a01f718c1')),
        backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
      ),
    );
    if (!ok) return;

    setState(() {});
    final refreshed = await _matchRepo.fetchMatchById(match.id);
    if (!mounted) return;
    await context.router.push(MatchRatingRoute(match: refreshed ?? match));
  }

  // History match card (MVP detail)
  Widget _buildHistoryMatchCard(Match match) {
    final currentUserId = AppAuth.currentUserId;
    if (currentUserId == null) return const SizedBox.shrink();

    final matchResult = _getMatchResultForUser(match, currentUserId);
    final resultColor = _getResultColor(matchResult);
    final resultText = _getResultText(matchResult);

    // Result (W/D/L) chip lives in the top-right corner.
    final resultChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resultColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: resultColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        resultText,
        style: FlapText.sora(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: resultColor,
        ),
      ),
    );

    final body = <Widget>[
      Row(
        children: [
          const Icon(Icons.people_alt_outlined,
              size: 16, color: FlapColors.greenBright),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${match.teamA?.name ?? tr('il_e18d322f14')} vs ${match.teamB?.name ?? tr('il_aceaf5d9ac')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlapText.sora(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      if (match.teamAScore != null && match.teamBScore != null)
        Row(
          children: [
            const Icon(Icons.sports_soccer,
                size: 16, color: FlapColors.greenBright),
            const SizedBox(width: 8),
            Text(
              '${tr('score')} ${match.teamAScore}:${match.teamBScore}',
              style: FlapText.sora(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      FutureBuilder<double>(
        future: _ratingsRepo.getUserRating(currentUserId),
        builder: (context, snapshot) {
          final rating = snapshot.hasData ? snapshot.data! : 0.0;
          return Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: FlapColors.gold),
              const SizedBox(width: 8),
              Text(
                '${tr('your_rating')} ${rating.toStringAsFixed(2)}',
                style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
              ),
            ],
          );
        },
      ),
      if (match.coverPhotoUrl?.isNotEmpty == true)
        _buildMatchPhotoFooter(match),
      if (match.status == MatchStatus.finished &&
          match.isUserMatchMember(currentUserId))
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              context.router.push(MatchRatingRoute(match: match));
            },
            icon: const Icon(Icons.star_outline_rounded,
                size: 18, color: FlapColors.greenBright),
            label: Text(
              tr('rate_players'),
              style: FlapText.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FlapColors.greenBright,
              ),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.router.push(MatchDetailsRoute(match: match)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                child: _matchCardTop(match, trailing: resultChip),
              ),
              const Divider(height: 1, thickness: 1, color: FlapColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < body.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      body[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // User-facing match outcome
  String _getMatchResultForUser(Match match, String userId) {
    if (match.teamAScore == null || match.teamBScore == null) {
      return 'unknown';
    }

    final teamAIds = List<String>.from(match.teamA?.playerIds ?? []);
    final teamBIds = List<String>.from(match.teamB?.playerIds ?? []);

    if (teamAIds.contains(userId)) {
      if (match.teamAScore! > match.teamBScore!) return 'win';
      if (match.teamAScore! < match.teamBScore!) return 'loss';
      return 'draw';
    } else if (teamBIds.contains(userId)) {
      if (match.teamBScore! > match.teamAScore!) return 'win';
      if (match.teamBScore! < match.teamAScore!) return 'loss';
      return 'draw';
    }

    return 'unknown';
  }

  // Outcome colors
  Color _getResultColor(String result) {
    switch (result) {
      case 'win':
        return const Color(0xFF4CAF50); // Green
      case 'loss':
        return const Color(0xFFf44336); // Red
      case 'draw':
        return const Color(0xFFFFC107); // Yellow
      default:
        return const Color(0xFF9E9E9E); // Gray
    }
  }

  // Outcome label text
  String _getResultText(String result) {
    switch (result) {
      case 'win':
        return tr('il_2e9b5a0c4e');
      case 'loss':
        return tr('il_df292782b2');
      case 'draw':
        return tr('draw');
      default:
        return tr('status_finished');
    }
  }

  Widget _buildRatingItem(Map<String, dynamic> p, int rank) {
    final String name =
        (p['name'] ??
                p['displayName'] ??
                ((p['firstName'] != null || p['lastName'] != null)
                    ? '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()
                    : null) ??
                tr('il_b764cdc0ea'))
            .toString();

    final double rating = ((p['rating'] ?? 0) as num).toDouble();
    final String rawPosition = (p['position'] ?? '').toString();
    final String city = localizeCity((p['city'] ?? '').toString());
    final String avatar = (p['avatarUrl'] ?? p['photoUrl'] ?? '').toString();
    final _Level lvl = _levelFor(rating);
    final int matchesCount =
        ((p['totalMatches'] ?? p['matches'] ?? p['matchesPlayed'] ?? 0) as num)
            .toInt();
    final positionLabel = positionLabelForDisplay(rawPosition);

    return InkWell(
      onTap: () => context.router.push(
        PlayerProfileRoute(playerId: p['id'].toString(), playerName: name),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _rankBadge(rank),
            const SizedBox(width: 14),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white12,
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        positionLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      Text(
                        city,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      Text(
                        tr(
                          'il_1cbac19546',
                          namedArgs: {'matchesCount': '$matchesCount'},
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Color(lvl.color).withValues(alpha: 0.15),
                    border: Border.all(
                      color: Color(lvl.color).withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    lvl.label,
                    style: TextStyle(
                      color: Color(lvl.color),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('il_8a79bbc437'),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Color(0xFF4caf50),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankBadge(int rank) {
    if (rank == 1 || rank == 2 || rank == 3) {
      final String medal = rank == 1
          ? '🥇'
          : rank == 2
          ? '🥈'
          : '🥉';
      return SizedBox(
        width: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(medal, style: const TextStyle(fontSize: 18)),
        ),
      );
    }
    return SizedBox(
      width: 36,
      child: Text(
        '#$rank',
        textAlign: TextAlign.left,
        style: const TextStyle(
          color: Colors.white54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statTile(String title, double val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 6),
          Text(
            val.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text('$label: $value', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _Level {
  final String label;
  final int color;
  _Level(this.label, this.color);
}

_Level _levelFor(double rating) {
  if (rating >= 4.5) return _Level(tr('professional'), 0xFF9C27B0);
  if (rating >= 3.5) return _Level(tr('advanced'), 0xFFFF9800);
  if (rating >= 2.5) return _Level(tr('intermediate'), 0xFF2196F3);
  if (rating >= 1.5) return _Level(tr('beginner'), 0xFF4CAF50);
  return _Level(tr('il_ea0bedb7c8'), 0xFF9E9E9E);
}
