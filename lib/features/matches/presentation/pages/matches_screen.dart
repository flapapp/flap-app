import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../router/app_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/matches_repository.dart';
import '../../data/models/match.dart';
import 'create_match_screen.dart';
import 'match_details_screen.dart';
import '../../../ratings/presentation/pages/ratings_screen.dart';
import '../../../../widgets/rating_display.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import 'match_management_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../../../widgets/user_chip.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/mode_speed_dial.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import 'package:flap_app/core/auth/app_auth.dart';




@RoutePage()
class MatchesScreen extends StatefulWidget {
  final int? initialTabIndex;

  const MatchesScreen({super.key, this.initialTabIndex});

  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with TickerProviderStateMixin {
  // Змінна для поточної вкладки
  int _currentTabIndex = 0;

  // Назви вкладок
  final List<String> _tabKeys = ['find_match', 'my_matches', 'history', 'ratings'];

  // Змінні для фільтрів
  late String _selectedCity;
  late String _selectedLevel;
  late String _selectedTime;
  late String _selectedSort;
  String _searchQuery = '';
  bool _filtersExpanded = false;
  final TextEditingController _cityFilterController = TextEditingController();
  String _currentUserCity = '';

  // Списки опцій для фільтрів
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

  // Змінні для "Мої матчі"
  String _selectedMyMatchesFilter = 'all'; // 'all' | 'organized' | 'participation'
  List<String> get _myMatchesFilters => [tr('all'), tr('organized'), tr('participation')];

  // TabController для керування вкладками
  late TabController _tabController;
    bool _isLeaving = false;
    Timer? _searchDebounce;

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('confirm'))),
        ],
      ),
    );
  }

  MatchesRepository get _matchRepo => sl<MatchesRepository>();

  RatingsRepository get _ratingsRepo => sl<RatingsRepository>();
  final SupabaseClient _sb = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  // Стан фільтрів рейтингів (замість ValueNotifier використовуємо звичайний state)
  String _ratingsSelectedCity = tr('all_cities');
  String _ratingsSelectedPosition = tr('il_0e333190c1');
  Future<List<Map<String, dynamic>>>? _ratingsTopPlayersFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabKeys.length,
      vsync: this,
    );

    // Ініціалізуємо фільтри
    _selectedCity = tr('all_cities');
    _selectedLevel = tr('all_levels');
    _selectedTime = tr('anytime');
    _selectedSort = 'newest';
    _loadCurrentUserCity();

    // Завантажуємо топ гравців один раз
    _ratingsTopPlayersFuture = _ratingsRepo.getTopPlayers(limit: 300);

    final idx = widget.initialTabIndex;
    if (idx != null && idx >= 0 && idx < _tabKeys.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (idx < _tabController.length) {
          _tabController.index = idx;
        }
      });
    }
  }
  @override
  void dispose() {
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
  // Метод для створення фільтрів
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4caf50)),
        ),
        prefixIcon: const Icon(Icons.location_city, color: Colors.white70, size: 20),
        onSelected: (value) {
          setState(() {
            _selectedCity = value.trim().isEmpty ? tr('all_cities') : value.trim();
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
                  prefixIcon: Icon(Icons.star, color: Colors.white70, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF4caf50)),
                  ),
                    ),
                    dropdownColor: Color(0xFF1a1a2e),
                    style: TextStyle(color: Colors.white),
                    items: _levelOptions.map((level) =>
                      DropdownMenuItem(
                        value: level,
                    child: Text(level, style: TextStyle(color: Colors.white)),
                      )
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value ?? tr('all_levels');
                      });
                    },
                  ),
            );
    return narrow
      ? Column(children: [city, SizedBox(height: 12), level])
      : Row(children: [Expanded(child: city), SizedBox(width: 16), Expanded(child: level)]);
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
                  prefixIcon: Icon(Icons.access_time, color: Colors.white70, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF4caf50)),
                  ),
                    ),
                    dropdownColor: Color(0xFF1a1a2e),
                    style: TextStyle(color: Colors.white),
                    items: _timeOptions.map((time) =>
                      DropdownMenuItem(
                        value: time,
                    child: Text(time, style: TextStyle(color: Colors.white)),
                      )
                    ).toList(),
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
                  prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
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
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    if (!mounted) return;
                    setState(() {});
                      });
                    },
                  ),
            );
    return narrow
      ? Column(children: [time, SizedBox(height: 12), search])
      : Row(children: [Expanded(child: time), SizedBox(width: 16), Expanded(child: search)]);
  },
),
        
        // Кнопка скидання фільтрів
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _resetFindFilters,
              icon: Icon(Icons.refresh, color: Colors.white70, size: 18),
              label: Text(tr('reset_filters'), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 400;
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
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
                child: Image.asset('assets/logo/flap_logo.jpg', fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              const Text(
                'FLAP',
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
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
              onPressed: () => context.router.push(const NotificationsRoute()),
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
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Center(
                    child: Text(unreadCount > 9 ? '9+' : unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
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
          displayName = (d['display_name'] ?? d['email']?.toString().split('@').first ?? tr('il_a25513c7e0')).toString();
        }
        return IconButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.router.push(const ProfileRoute()),
          icon: CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF4caf50),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)) : null,
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
      color: Colors.white.withValues(alpha: 0.05),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TabBar(
              controller: _tabController,
      isScrollable: true,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      tabs: _tabKeys.map((key) => Tab(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8),
                child: Text(
            tr(key),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
              fontSize: isCompact ? 13 : 14,
            ),
                  ),
                ),
              )).toList(),
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
          // ВКЛАДКА 1: Знайти матч
          _buildFindMatchTab(),

          // ВКЛАДКА 2: Мої матчі
          _buildMyMatchesTab(),

          // ВКЛАДКА 3: Історія
          _buildHistoryTab(),

          // ВКЛАДКА 4: Рейтинги
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
        onCreate: () => context.router.push(const CreateMatchRoute()),
        createTooltip: tr('il_4759498ac2'),
      ),
    );
  }

  void _showRatingModal() {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: const Color(0xFF0f0f23),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0f0f23),
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
            color: const Color(0xFF4caf50).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.star, color: Colors.white, size: 18),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Text(
        tr('my_rating'),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
      splashRadius: 18,
    ),
  ],
),
                const SizedBox(height: 8),

                // Поточний рейтинг
                Row(
                  children: [
                    const Icon(Icons.circle, size: 10, color: Color(0xFF4caf50)),
                    const SizedBox(width: 8),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _sb
                          .from('profiles')
                          .stream(primaryKey: ['id'])
                          .eq('id', AppAuth.currentUserId ?? ''),
                      builder: (context, snapshot) {
                        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                        final rating = rows.isNotEmpty
                            ? ((rows.first['rating'] ?? 0.0) as num).toDouble()
                            : 0.0;
                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${tr('current_rating')}: ',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text: rating.toStringAsFixed(2),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(text: '  '),
                              const WidgetSpan(child: Icon(Icons.star, color: Color(0xFFFFD700), size: 14)),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Як формується рейтинг (детально)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
  color: const Color(0xFF1e7d32).withValues(alpha: 0.20),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: const Color(0xFF1e7d32).withValues(alpha: 0.40)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF4caf50).withValues(alpha: 0.25),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Формула
                      Text(tr('formula'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        tr('rating_formula'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      const SizedBox(height: 10),
                      // Ваги
                      Text(tr('weights'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(tr('il_b7262e4ea5'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(tr('il_4cf022c9db'), style: const TextStyle(color: Colors.white70, fontSize: 13)),

                      const SizedBox(height: 10),
                      // Матчі
                      Text(tr('il_8cb5668888'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        tr('il_db707121f6'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        tr('il_006d502126'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        tr('il_a984b8b480'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      const SizedBox(height: 10),
                      // Відео/челенджі
                      Text(tr('il_4f71cbdf42'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        tr('il_921f40cf93'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      const SizedBox(height: 10),
                      // Захист
                      Text(tr('il_b679eb4ef3'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        tr('il_27eb1319c4'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      const SizedBox(height: 10),
                      // Рівні гравців
                      Text(tr('il_8ea73ba2a4'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        tr('il_98c956f0fe'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Історія змін рейтингу (нове)
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
        List<Map<String, dynamic>>.from(data['ratingHistory'] ?? []);
    if (history.isEmpty) return const SizedBox.shrink();

    // нові зверху
    history.sort((a, b) {
      final ta = _readDate(a['timestamp']);
      final tb = _readDate(b['timestamp']);
      return tb.compareTo(ta);
    });

    return Column(
      children: history.asMap().entries.map((e) {
        final i = e.key;
        final h = e.value;
        final dt = _readDate(h['timestamp']);
        final overall = ((h['overallRating'] ?? 0) as num).toDouble();
        final prev = (i + 1 < history.length)
            ? ((history[i + 1]['overallRating'] ?? 0) as num).toDouble()
            : null;
        final delta = prev == null ? 0.0 : double.parse((overall - prev).toStringAsFixed(2));
        final sign = delta >= 0 ? '+' : '';
        final color = delta > 0 ? const Color(0xFF4CAF50) : (delta < 0 ? const Color(0xFFF44336) : Colors.white54);
        final icon = delta > 0 ? Icons.trending_up : (delta < 0 ? Icons.trending_down : Icons.remove);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('il_64d8152d62'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${prev?.toStringAsFixed(2) ?? overall.toStringAsFixed(2)} → ${overall.toStringAsFixed(2)}'
                      '${dt != null ? '   ${dt.day}.${dt.month}.${dt.year}' : ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${sign}${delta.toStringAsFixed(2)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
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

    void _showCoinsSheet(int currentCoins) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
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
                    const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('my_coins'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            tr('il_7bd5596886'),
                            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('il_de7c340f64'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                    }
                    final txDocs = List<Map<String, dynamic>>.from(snapshot.data ?? const <Map<String, dynamic>>[]);
                    txDocs.sort((a, b) {
                      final at = _readDate(a['created_at']);
                      final bt = _readDate(b['created_at']);
                      return bt.compareTo(at);
                    });
                    if (txDocs.isEmpty) {
                      return Center(
                        child: Text(bilingual('Поки немає транзакцій', 'No transactions yet'),
                            style: const TextStyle(color: Colors.white70)),
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
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: amount > 0 ? const Color(0xFF4caf50).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(amount > 0 ? Icons.add : Icons.remove,
                                  color: amount > 0 ? const Color(0xFF4caf50) : Colors.red, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(description, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                    Text(_formatTransactionTime(timestamp),
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text('${amount > 0 ? '+' : ''}$amount',
                                style: TextStyle(color: amount > 0 ? const Color(0xFF4caf50) : Colors.red,
                                  fontSize: 16, fontWeight: FontWeight.bold),
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
      final months = currentAppLanguageCode() == 'en'
          ? ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
          : ['січ', 'лют', 'бер', 'квіт', 'трав', 'черв', 'лип', 'серп', 'вер', 'жовт', 'лист', 'груд'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } else if (difference.inDays > 0) {
      return tr('il_adf8ee5f65');
    } else if (difference.inHours > 0) {
      return tr('il_7634d1849f');
    } else if (difference.inMinutes > 0) {
      return tr('il_e0b53645d6');
    } else {
      return tr('il_66f53417d3');
    }
  }

  // ВКЛАДКА 1: Знайти матч
  Widget _buildFindMatchTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFilterToggle(),
          if (_filtersExpanded) _buildFilters(),

          // Список доступних матчів
          StreamBuilder<List<Match>>(
            stream: _getFilteredMatches(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    tr('il_c64c77589a'),
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4caf50),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                        bilingual('Немає доступних матчів', 'No matches available'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bilingual('Створіть новий матч або зачекайте', 'Create a new match or check back later'),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Лічильник + список матчів
final items = snapshot.data!;
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
              const Icon(Icons.filter_alt, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('il_3a10c3ba9b'),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
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
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              items: _sortOptions
                  .map((option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(_sortLabel(option)),
                      ))
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

  // ВКЛАДКА 2: Мої матчі
  Widget _buildMyMatchesTab() {
    return Column(
      children: [
        // Заголовок секції з кнопкою "Створити матч"
        _buildMyMatchesHeader(),

        // Фільтри "Мої матчі"
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              ChoiceChip(
                label: Text(tr('all')),
                selected: _selectedMyMatchesFilter == 'all',
                onSelected: (_) => setState(() => _selectedMyMatchesFilter = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(tr('organized')),
                selected: _selectedMyMatchesFilter == 'organized',
                onSelected: (_) => setState(() => _selectedMyMatchesFilter = 'organized'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(tr('participation')),
                selected: _selectedMyMatchesFilter == 'participation',
                onSelected: (_) => setState(() => _selectedMyMatchesFilter = 'participation'),
              ),
            ],
          ),
        ),

        // Список матчів користувача
        Expanded(
          child: StreamBuilder<List<Match>>(
            stream: _getUserMatches(),
            builder: (context, snapshot) {
              // Показуємо помилку, якщо є
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    tr('il_c64c77589a'),
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              // Показуємо індикатор завантаження
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4caf50),
                  ),
                );
              }

              // Показуємо повідомлення, якщо немає матчів
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people,
                        size: 64,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        bilingual('У вас поки немає матчів', 'You don’t have any matches yet'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bilingual(
                          'Створіть новий матч або приєднайтеся до існуючого',
                          'Create a new match or join an existing one',
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Фільтрація за чіпами
              final all = snapshot.data!;
              final currentUserId = AppAuth.currentUserId;
              List<Match> filtered = all;
              if (_selectedMyMatchesFilter == 'organized' && currentUserId != null) {
                filtered = all.where((m) => m.organizerId == currentUserId).toList();
              } else if (_selectedMyMatchesFilter == 'participation' && currentUserId != null) {
                filtered = all.where((m) => m.participants.contains(currentUserId) && m.organizerId != currentUserId).toList();
              }
              // Найближчі зверху
              // Незіграні прострочені — вниз списку, далі найближчі зверху.
              filtered.sort((a, b) {
                if (a.isUnplayedByTimeout != b.isUnplayedByTimeout) {
                  return a.isUnplayedByTimeout ? 1 : -1;
                }
                return b.date.compareTo(a.date);
              });

              // Показуємо список матчів користувача
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

  // ВКЛАДКА 3: Історія
  Widget _buildHistoryTab() {
    return StreamBuilder<List<Match>>(
      stream: _getHistoryMatches(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text(tr('il_3a6e650bec'),
                  style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
        }
        final matches = snapshot.data!;
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.white54),
                SizedBox(height: 12),
                Text(tr('match_history_empty'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Заголовок секції як у MVP
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
            // Список матчів
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


// ВКЛАДКА 4: Рейтинги (MVP)
Widget _buildRatingsTab() {
  // Використовуємо кешований Future замість створення нового
  final topFuture = _ratingsTopPlayersFuture ?? Future.value(<Map<String, dynamic>>[]);
  final allPositionsLabel = tr('il_0e333190c1');

  // Локальні хелпери для фільтрації (не залежать від наявності зовнішніх функцій)
  String norm(String? s) => (s ?? '').trim().toLowerCase();

  // Синоніми міст для надійного матчінгу
     final Map<String, List<String>> cityAliases = {
     'Київ':   ['київ', 'kyiv', 'kiev'],
     'Kyiv':   ['київ', 'kyiv', 'kiev'],
     'Харків': ['харків', 'kharkiv'],
     'Kharkiv': ['харків', 'kharkiv'],
     'Одеса':  ['одеса', 'odesa', 'odessa'],
     'Odesa':  ['одеса', 'odesa', 'odessa'],
     'Дніпро': ['дніпро', 'dnipro', 'dnepr', 'dnepropetrovsk'],
     'Dnipro': ['дніпро', 'dnipro', 'dnepr', 'dnepropetrovsk'],
     'Львів':  ['львів', 'lviv', 'lwow', 'lwów'],
     'Lviv':   ['львів', 'lviv', 'lwow', 'lwów'],
   };

  bool cityMatches(String dbCity, String selectedUi) {
    final db = norm(dbCity);
    final sel = norm(selectedUi);
    if (db == sel) return true;
    final aliases = <String>{sel, ...?cityAliases[selectedUi]?.map(norm)};
    return aliases.contains(db);
  }

  // Коди позицій
  String toCode(String uiOrCode) {
    // Якщо вже код — повертаємо
    switch (uiOrCode) {
      case 'goalkeeper':
      case 'defender':
      case 'midfielder':
      case 'forward':
        return uiOrCode;
    }
    // Українська → код
    switch (uiOrCode) {
      case 'Воротар': return 'goalkeeper';
      case 'Захисник': return 'defender';
      case 'Півзахисник': return 'midfielder';
      case 'Нападник': return 'forward';
      default: return uiOrCode;
    }
  }

    // Побудова вузького дропдауна без підпису
     Widget narrowDropdown({
     required String value,
     required List<String> options,
     required ValueChanged<String?> onChanged,
     Key? key,
   }) {
     final String safeValue = options.contains(value) ? value : (options.isNotEmpty ? options.first : '');
     return SizedBox(
       width: 160,
       child: DropdownButtonFormField<String>(
         key: key,
         value: options.isNotEmpty ? safeValue : null,
        items: options
            .map((v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(v, style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        dropdownColor: const Color(0xFF16213e),
        iconEnabledColor: Colors.white70,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
        // Заголовок + ручний перерахунок
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(tr('ratings_title'),
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
            ],
          ),
        ),

        // Підтаби
      ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: SizedBox(
      height: 56, // місце для 2 рядків
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.05),
      ),
    ),
  ),
  Tab(
    child: Center(
      child: Text(
        tr('il_5d34135df2'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  ),
  Tab(
    child: Center(
      child: Text(
        tr('il_252d7af35a'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.05),
      ),
    ),
  ),
]
      ),
    ),
  ),
),

        const SizedBox(height: 8),

        // Вміст
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: topFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
              }
              final all = (snap.data ?? const <Map<String, dynamic>>[]).toList();

              // Гарантоване сортування за рейтингом спадаючим
              all.sort((a, b) {
                final ar = ((a['rating'] ?? 0) as num).toDouble();
                final br = ((b['rating'] ?? 0) as num).toDouble();
                return br.compareTo(ar);
              });

              return TabBarView(
                key: ValueKey('ratings_${_ratingsSelectedCity}_${_ratingsSelectedPosition}'),
                children: [
                  // 1) Загальний рейтинг
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Text(tr('il_ccd407766c'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                          itemCount: all.length,
                          itemBuilder: (context, i) => _buildRatingItem(all[i], i + 1),
                        ),
                      ),
                    ],
                  ),

                  // 2) За містом
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
                                  _ratingsSelectedCity = v ?? tr('all_cities');
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Text(tr('il_ccd407766c'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: () {
                          final String? cityFilter = (_ratingsSelectedCity == tr('all_cities')) ? null : _ratingsSelectedCity;
                          final list = (cityFilter == null)
                              ? all
                              : all.where((p) => cityMatches((p['city'] ?? '').toString(), cityFilter)).toList();
                          if (list.isEmpty) {
                            return Center(
                              child: Text(tr('empty_for_city'),
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                            itemCount: list.length,
                            itemBuilder: (context, i) => _buildRatingItem(list[i], i + 1),
                          );
                        }(),
                      ),
                    ],
                  ),

                  // 3) За позицією
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
                                  _ratingsSelectedPosition = v ?? allPositionsLabel;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Text(tr('il_ccd407766c'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: () {
                          final allPositionsLabel = tr('il_0e333190c1');
                          final String? positionFilter = (_ratingsSelectedPosition == allPositionsLabel) ? null : toCode(_ratingsSelectedPosition);
                          final list = (positionFilter == null)
                              ? all
                              : all.where((p) {
                                  final raw = (p['position'] ?? '').toString();
                                  final dbCode = ['goalkeeper','defender','midfielder','forward'].contains(raw)
                                      ? raw
                                      : toCode(raw);
                                  return norm(dbCode) == norm(positionFilter);
                                }).toList();
                          if (list.isEmpty) {
                            return Center(
                              child: Text(tr('empty_for_position'),
                                  style: const TextStyle(color: Colors.white70)),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                            itemCount: list.length,
                            itemBuilder: (context, i) => _buildRatingItem(list[i], i + 1),
                          );
                        }(),
                      ),
                    ],
                  ),

                  // 4) Моя статистика
                  Builder(
                    builder: (context) {
                      final uid = AppAuth.currentUserId;
                      if (uid == null) {
                        return Center(
                          child: Text(tr('sign_in_for_stats'),
                              style: const TextStyle(color: Colors.white70)),
                        );
                      }
                      return FutureBuilder<Map<String, dynamic>>(
                        future: _ratingsRepo.getUserRatingStats(uid),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(color: Color(0xFF4caf50)));
                          }
                          final s = snap.data ?? const {};
                          final current = ((s['currentRating'] ?? 3.0) as num).toDouble();
                          final m = ((s['matchRating'] ?? 3.0) as num).toDouble();
                          final v = ((s['videoRating'] ?? 3.0) as num).toDouble();
                          final tm = (s['totalMatches'] ?? 0).toString();
                          final tv = (s['totalVideos'] ?? 0).toString();

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            children: [
                              _statTile(tr('current_rating'), current),
                              const SizedBox(height: 8),
                              _statTile(tr('match_rating_70'), m),
                              const SizedBox(height: 8),
                              _statTile(tr('video_rating_30'), v),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _chipStat(Icons.sports_soccer, tr('il_98abff28a9'), tm),
                                  const SizedBox(width: 8),
                                  _chipStat(Icons.videocam, tr('il_c9a9639463'), tv),
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

void _shareMatch(Match match) {
  final url = 'https://flap.app/match/${match.id}';
  Share.share(tr('il_df5a71b7ac') + url);
}
  // Метод для розрахунку середнього рейтингу учасників
  Future<double> _calculateAverageRating(List<String> participantIds) async {
    try {
      if (participantIds.isEmpty) return 3.0; // Початковий рейтинг

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

  // Метод для створення картки матчу
    Widget _buildMatchCard(Match match) {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return SizedBox.shrink();

    final userStatus = match.getUserStatus(currentUser.id);
    final isOrganizer = userStatus == 'organizer';
    final isParticipant = userStatus == 'participant';
    final isFinished = match.status == MatchStatus.finished;

  return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
  crossAxisAlignment: CrossAxisAlignment.start,
            children: [
    Text(
                  match.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Деталі матчу
          _buildMatchDetails(match),
          
          SizedBox(height: 16),
          
          // Кнопки дій
          _buildActionButtons(match, currentUser.id),
          if (match.coverPhotoUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildMatchPhotoFooter(match),
          ],
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
                  const Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 18),
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
                          horizontal: 10, vertical: 4),
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

// ... existing code ...

Widget _buildMatchDetails(Match match) {
  // Діагностика
  print('DEBUG: Building match details for ${match.title}');
  final totalParticipants = match.participants.length;
  final confirmedCount = match.isTeamMatch
      ? match.confirmedParticipantsCount
      : totalParticipants;
  print('DEBUG: Participants count: $confirmedCount');
  print('DEBUG: Participants: ${match.participants}');
  
  return Column(
    children: [
      // Дата та час
          Row(
            children: [
          Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              SizedBox(width: 8),
              Text(
            '${match.date.day}.${match.date.month}.${match.date.year}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(width: 16),
          Icon(Icons.access_time, color: Colors.white70, size: 16),
              SizedBox(width: 8),
              Text(
            match.time,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          
      SizedBox(height: 6),
          
      // Локація
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
          
          // Рівень складності
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

      // Сер. рейтинг учасників (додано під MVP)
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
      
      // Кількість гравців з аватарками
      // Кількість гравців + плашка статусу (в один ряд)
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
            tr('il_83aab55000'),
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

// Аватарки окремим рядком, щоб не було переповнення
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
      
      SizedBox(height: 8),
      
      // Організатор
      Row(
        children: [
          PlayerAvatarButton(
            userId: match.organizerId,
            displayName: match.organizerName ?? tr('organizer'),
            size: 36,
            backgroundColor: const Color(0xFF1f2b3a),
            borderColor: Colors.white.withOpacity(0.15),
            borderWidth: 1.5,
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
                  match.organizerName ?? tr('player'),
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

Widget _buildActionButtons(Match match, String currentUserId) {
  // Перевіряємо статус користувача в матчі
  final rawUserStatus = match.getUserStatus(currentUserId);
  final userStatus = _convertUserStatus(rawUserStatus);

  // Діагностика
  print('DEBUG: Match ${match.title}');
  print('DEBUG: Raw user status: $rawUserStatus');
  print('DEBUG: Converted user status: $userStatus');
  print('DEBUG: Match status: ${match.status}');
  print('DEBUG: Participants: ${match.participants}');
  print('DEBUG: Current user: $currentUserId');
  print('DEBUG: Organizer ID: ${match.organizerId}');

  final isOrganizer = match.organizerId == currentUserId;
  final isParticipant = match.participants.contains(currentUserId);
  if (match.isTeamMatch && !isOrganizer && !isParticipant) {
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
        OutlinedButton.icon(
          onPressed: () =>
              context.router.push(MatchDetailsRoute(match: match)),
          icon: const Icon(Icons.info_outline, size: 16),
          label: Text(tr('details'),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(0, 40),
          ),
        ),
      ],
    );
  }

  // Приватний матч — лише за запрошенням
  if (match.isPrivate && !match.invitedFriends.contains(currentUserId)) {
    return Container(
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
          Text(tr('private_match_invite_only'), style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // Відкритий матч і користувач не учасник — показати три компактні кнопки
  if (rawUserStatus == 'none' && match.status == MatchStatus.open) {
    return LayoutBuilder(
  builder: (context, c) {
    final isNarrow = c.maxWidth < 360;

    final joinBtn = ElevatedButton.icon(
      onPressed: () => _applyForMatch(match.id),
      icon: const Icon(Icons.person_add_alt_1, size: 16),
      label: Text(tr('join'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4caf50),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
      ),
    );

    final detailsBtn = OutlinedButton.icon(
      onPressed: () => context.router.push(MatchDetailsRoute(match: match)),
      icon: const Icon(Icons.info_outline, size: 16),
      label: Text(tr('details'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
      ),
    );

    final shareBtn = OutlinedButton.icon(
      onPressed: () => _shareMatch(match),
      icon: const Icon(Icons.share, size: 16),
      label: Text(tr('il_29887a5ff9'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
      ),
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: joinBtn),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: detailsBtn),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: shareBtn),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: SizedBox(height: 40, child: joinBtn)),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 40, child: detailsBtn)),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 40, child: shareBtn)),
      ],
    );
  },
);
  }

  // Інші стани — дві компактні кнопки
  return Row(
    children: [
      // Деталі (outline)
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: TextButton(
            onPressed: () {
              context.router.push(MatchDetailsRoute(match: match));
            },
            child: Text(
              tr('details'),
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Share / Join CTA
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4caf50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: () {
              if (match.status == MatchStatus.open && rawUserStatus == 'none') {
                _applyForMatch(match.id);
                return;
              }
              final url = 'https://flap.app/match/${match.id}';
              Share.share(tr('il_df5a71b7ac') + url);
            },
            child: Text(
              match.status == MatchStatus.open && rawUserStatus == 'none'
                  ? tr('il_fd30fe681b')
                  : tr('il_29887a5ff9'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildTeamMatchBanner(Match match) {
    final teamAName = (match.teamA?.name?.isNotEmpty ?? false)
        ? match.teamA!.name
        : tr('il_d161440e8d');
    final teamBName = (match.teamB?.name?.isNotEmpty ?? false)
        ? match.teamB!.name
        : (match.teamBId != null
            ? tr('il_6b3e8cd77f')
            : tr('il_852ae4ce70'));
    final teamARoster =
        match.teamRosters['teamA'] ?? match.teamA?.playerIds ?? const <String>[];
    final teamBRoster =
        match.teamRosters['teamB'] ?? match.teamB?.playerIds ?? const <String>[];

    final teamAStatus = match.teamAStatus ?? 'confirmed';
    final teamBStatus =
        match.teamBStatus ?? (match.teamBId == null ? 'pending' : 'confirmed');

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
            children: [
              const Icon(Icons.sports_soccer, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('il_4f76cec7a7'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTeamMatchRow(teamAName, teamAStatus, teamARoster),
          const SizedBox(height: 8),
          _buildTeamMatchRow(teamBName, teamBStatus, teamBRoster),
        ],
      ),
    );
  }

  Widget _buildTeamMatchRow(
      String teamName, String status, List<String> roster) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                teamName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildTeamStatusChip(status),
          ],
        ),
        if (roster.isNotEmpty) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: roster.take(8).map((playerId) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: UserChip(userId: playerId, size: 24, showName: false),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTeamStatusChip(String status) {
    final text = _getTeamStatusText(status);
    final color = _getTeamStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getTeamStatusText(String? status) {
    switch (status) {
      case 'confirmed':
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
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }



  Stream<List<Match>> _getFilteredMatches() {
    return _matchRepo.getAvailableMatches().map((matches) {
    final selectedCity = _selectedCity.trim();
    final filtered = matches.where((match) {
        // Фільтр по місту
      if (selectedCity.isNotEmpty &&
      selectedCity != tr('all_cities') &&
      match.city.trim().toLowerCase() != selectedCity.toLowerCase()) {
    return false;
  }
        // Фільтр по рівню
      if (_selectedLevel != tr('all_levels') && _getLevelText(match.level) != _selectedLevel) return false;
        // Фільтр по часу
        if (_selectedTime != tr('anytime')) {
        final now = DateTime.now();
        final matchDate = match.date;
          final timeValue = _selectedTime;
          if (timeValue == tr('il_2b065c7c9c')) {
            if (!_isSameDay(matchDate, now)) return false;
          } else if (timeValue == tr('il_456a73bbce')) {
            final tomorrow = now.add(const Duration(days: 1));
            if (!_isSameDay(matchDate, tomorrow)) return false;
          } else if (timeValue == tr('il_8c4eef5ab2')) {
            final weekEnd = now.add(const Duration(days: 7));
            if (matchDate.isBefore(now) || matchDate.isAfter(weekEnd)) return false;
          }
        }
        // Фільтр по пошуку
        if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return match.title.toLowerCase().contains(q) ||
               match.description.toLowerCase().contains(q) ||
               match.location.toLowerCase().contains(q) ||
               match.city.toLowerCase().contains(q);
      }
        return true;
      }).toList();
    // Сортування
      filtered.sort((a, b) {
      if (a.isUnplayedByTimeout != b.isUnplayedByTimeout) {
        return a.isUnplayedByTimeout ? 1 : -1;
      }

      if (_selectedSort == 'my_city' &&
          _currentUserCity.trim().isNotEmpty) {
        final aMine = a.city.trim().toLowerCase() == _currentUserCity.trim().toLowerCase();
        final bMine = b.city.trim().toLowerCase() == _currentUserCity.trim().toLowerCase();
        if (aMine != bMine) {
          return bMine ? 1 : -1;
        }
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
    });
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
  // Метод для отримання матчів користувача
  Stream<List<Match>> _getUserMatches() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return Stream.value([]);
    return _matchRepo.getUserMatches(currentUser.id);
  }

  // ІСТОРІЯ: завершені матчі користувача (новіші зверху)
  Stream<List<Match>> _getHistoryMatches() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return Stream.value([]);
    return _matchRepo.getUserMatches(currentUser.id).map((list) {
      final finished = list.where((m) => m.status == MatchStatus.finished).toList();
      finished.sort((a, b) => b.date.compareTo(a.date));
      return finished;
    });
  }

  // Метод для отримання кольору статусу
  Color _getStatusColor(MatchStatus status, {Match? match}) {
  if (match?.isUnplayedByTimeout == true) {
    return const Color(0xFF607D8B);
  }
  switch (status) {
    case MatchStatus.open:
      return const Color(0xFF4caf50);
    case MatchStatus.full:
      return Colors.blue;
    case MatchStatus.inProgress:
      return Colors.orange;
    case MatchStatus.finished:
      return Colors.grey;
    case MatchStatus.cancelled:
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String _getStatusText(MatchStatus status, {Match? match}) {
  if (match?.isUnplayedByTimeout == true) {
    return tr('il_ee288d682b');
  }
  switch (status) {
    case MatchStatus.open:
      return tr('status_open');
    case MatchStatus.full:
      return tr('status_full');
    case MatchStatus.inProgress:
      return tr('status_in_progress');
    case MatchStatus.finished:
      return tr('status_finished');
    case MatchStatus.cancelled:
      return tr('status_cancelled');
    default:
      return tr('unknown');
  }
}

IconData _getStatusIcon(MatchStatus status) {
  switch (status) {
    case MatchStatus.open:
      return Icons.person;
    case MatchStatus.full:
      return Icons.check_circle;
    case MatchStatus.inProgress:
      return Icons.play_circle;
    case MatchStatus.finished:
      return Icons.done_all;
    case MatchStatus.cancelled:
      return Icons.cancel;
    default:
      return Icons.help;
    }
  }

  // Метод для форматування дати та часу
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return tr('il_2b065c7c9c') + ' ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return tr('il_456a73bbce') + ' ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}.${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // Допоміжні методи для фільтрації
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
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
      default:
        return tr('unknown');
    }
  }

  // Заголовок секції "Мої матчі"
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
            onPressed: () => context.router.push(const CreateMatchRoute()),
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

  // Картка матчу для "Мої матчі"
// version_0.1/lib/screens/matches_screen.dart

Widget _buildMyMatchCard(Match match) {
  final currentUser = AppAuth.currentUser;
  final isOrganizer = AppAuth.currentUserId == match.organizerId;
  final role = isOrganizer ? tr('organizer') : tr('participant');

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Шапка картки: статус окремим рядком, щоб уникнути overflow
Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    // Дата/час + локація у Wrap: перенос і еліпсиси на вузьких екранах
    Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
        const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
          child: Text(
                        '${match.date.day}.${match.date.month} о ${match.time}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        const Icon(Icons.location_on, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 160),
          child: Text(
                        match.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
                      ),
                    ],
                  ),
    const SizedBox(height: 6),
    Row(
      children: [
        isOrganizer ? const Text('👑', style: TextStyle(fontSize: 16))
                    : const Icon(Icons.person, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(role, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    ),
    const SizedBox(height: 8),
    
  ],
),
        SizedBox(height: 16),

        Row(
  children: [
    Icon(Icons.people, color: Colors.white70, size: 16),
    SizedBox(width: 4),
    Text(
      '${match.currentPlayers}/${match.maxPlayers}',
      style: TextStyle(color: Colors.white70, fontSize: 14),
    ),
    Spacer(),
            Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(match.status),
                borderRadius: BorderRadius.circular(20),
              ),
      child: Text(
                    _getStatusText(match.status, match: match),
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

        // Аватарки учасників (ініціали)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            children: match.participants.take(10).map((id) {
              return Container(
                margin: const EdgeInsets.only(right: 6),
    child: UserChip(
      userId: id,
      size: 24, // ≈ радіус 12
      showName: false,
                ),
              );
            }).toList(),
          ),
        ),

        SizedBox(height: 16),

        // Кнопки дій
        Row(
          children: [
    if (isOrganizer &&
    match.status != MatchStatus.finished &&
    match.status != MatchStatus.cancelled &&
    !match.isUnplayedByTimeout)
              ElevatedButton(
                onPressed: () {
                  context.router.push(MatchManagementRoute(match: match));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4caf50),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  tr('manage'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
    if (isOrganizer && match.status != MatchStatus.finished) SizedBox(width: 8),
    ElevatedButton(
      onPressed: () {
        context.router.push(MatchDetailsRoute(match: match));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        tr('details'),
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
          ],
        ),

        // Кнопка "Вийти з матчу" (учасник, не організатор, відкритий матч)
        if (!isOrganizer &&
            match.status == MatchStatus.open &&
            !match.isUnplayedByTimeout &&
            currentUser != null &&
            match.participants.contains(currentUser.id)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isLeaving
                    ? null
                    : () async {
                        final sure = await _confirm(tr('leave_match_confirm'), tr('leave_match_sure'));
                        if (sure != true) return;
                        setState(() => _isLeaving = true);
                        await _onLeaveMatch(match);
                        setState(() => _isLeaving = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _isLeaving ? tr('leaving') : tr('leave_match'),
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],

        // Швидкі дії для організатора
        if (isOrganizer &&
    match.status != MatchStatus.cancelled &&
    !match.isUnplayedByTimeout) ...[
          const SizedBox(height: 12),
          Builder(builder: (context) {
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
                    final sure = await _confirm('Сформувати команди?', 'Буде виконано автобаланс за рейтингом.');
                    if (sure != true) return;
                    await _onAutoBalance(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66bb6a),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Автобаланс',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                    final sure = await _confirm('Почати матч?', 'Після початку рахунок стане доступним і дії зміняться.');
                    if (sure != true) return;
                    await _onStartMatch(match);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canStartNow ? const Color(0xFF2196f3) : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    tr('start_match'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (match.status != MatchStatus.inProgress && match.hasTeams)
                const SizedBox(width: 8),
              if (match.status == MatchStatus.inProgress)
                ElevatedButton(
                  onPressed: () async {
                    final sure = await _confirm(tr('finish_match') + '?', tr('il_a2eff0d408'));
                    if (sure != true) return;
                    await _onFinishMatch(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    tr('finish_match'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
          ],
            );
          }),
        ],

        // Інфо для неорганізаторів
        if (!isOrganizer) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('il_508bc5f440'),
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
  Future<void> _onStartMatchPrep(Match match) async {
    final ok = await _matchRepo.startMatch(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? tr('il_f6fd06c276') : tr('il_074f215589')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }


  // Метод для подачі заявки на матч
  Future<void> _applyForMatch(String matchId) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_1141023944')), backgroundColor: Colors.red),
        );
        return;
      }

      final success = await _matchRepo.applyForMatch(matchId, currentUser.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_a5cf09124c')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_c8f6eedfa0')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // Вихід з матчу
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? tr('left_match') : tr('leave_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tr('error')}: $e'), backgroundColor: Colors.red),
    );
  }
}
    // Дії організатора
  Future<void> _onAutoBalance(Match match) async {
    final ok = await _matchRepo.autoBalanceTeams(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? tr('teams_balanced') : tr('teams_balance_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }

  Future<void> _onStartMatch(Match match) async {
    final ok = await _matchRepo.startMatch(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? tr('match_started') : tr('match_start_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }

  Future<void> _onFinishMatch(Match match) async {
    final scores = await _showFinishDialog();
    if (scores == null) return;

    final int a = scores['teamAScore']!;
    final int b = scores['teamBScore']!;
    final MatchResult result = (a > b) ? MatchResult.teamAWins : (b > a) ? MatchResult.teamBWins : MatchResult.draw;
    final goals = await _collectGoalsForMatch(match);
    if (goals == null) return;
    if (!_validateGoalsAgainstScore(match, goals, a, b)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_138370a929'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final ok = await _matchRepo.finishMatch(match.id, result, a, b, goalsByPlayer: goals);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? tr('match_finished') : tr('match_finish_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }

  Future<Map<String, int>?> _showFinishDialog() async {
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('finish_match')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('goals_team_a'))),
            TextField(controller: bCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('goals_team_b'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              final int? a = int.tryParse(aCtrl.text);
              final int? b = int.tryParse(bCtrl.text);
              if (a == null || b == null || a < 0 || b < 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('enter_valid_scores')), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx, {'teamAScore': a, 'teamBScore': b});
            },
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>?> _collectGoalsForMatch(Match match) async {
    final ids = match.participants;
    if (ids.isEmpty) return {};
    final names = await _loadParticipantNames(ids);
    final assignments = match.playerTeamAssignments;
    final Map<String, List<String>> grouped = {
      'teamA': [],
      'teamB': [],
      'free': [],
    };
    for (final id in ids) {
      final key = assignments[id] ?? 'free';
      grouped.putIfAbsent(key, () => <String>[]);
      grouped[key]!.add(id);
    }
    final controllers = {
      for (final id in ids) id: TextEditingController(text: '0')
    };
    final map = await showDialog<Map<String, int>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr('il_2da37af5bc')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _buildGoalInputSections(
                grouped: grouped,
                names: names,
                controllers: controllers,
                match: match,
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, <String, int>{}), child: Text(tr('il_28d03596d2'))),
            ElevatedButton(
              onPressed: () {
                final result = <String, int>{};
                controllers.forEach((id, ctrl) {
                  final val = int.tryParse(ctrl.text) ?? 0;
                  if (val > 0) result[id] = val;
                });
                Navigator.pop(ctx, result);
              },
              child: Text(tr('confirm')),
            ),
          ],
        );
      },
    );
    controllers.values.forEach((c) => c.dispose());
    return map;
  }

  bool _validateGoalsAgainstScore(
    Match match,
    Map<String, int> goals,
    int teamAScore,
    int teamBScore,
  ) {
    if (match.hasTeams) {
      final assignments = match.playerTeamAssignments;
      int sumA = 0;
      int sumB = 0;
      goals.forEach((playerId, value) {
        final teamKey = assignments[playerId];
        if (teamKey == 'teamB') {
          sumB += value;
        } else {
          sumA += value;
        }
      });
      return sumA == teamAScore && sumB == teamBScore;
    }
    final total = goals.values.fold<int>(0, (prev, value) => prev + value);
    return total == (teamAScore + teamBScore);
  }

  List<Widget> _buildGoalInputSections({
    required Map<String, List<String>> grouped,
    required Map<String, String> names,
    required Map<String, TextEditingController> controllers,
    required Match match,
  }) {
    final sections = <Widget>[];
    final order = ['teamA', 'teamB', 'free'];

    String _teamLabel(String key) {
      switch (key) {
        case 'teamA':
          return match.teamA?.name ?? tr('il_e18d322f14');
        case 'teamB':
          return match.teamB?.name ?? tr('il_aceaf5d9ac');
        default:
          return tr('il_7d4d74c733');
      }
    }

    for (final key in order) {
      final players = grouped[key] ?? const <String>[];
      if (players.isEmpty) continue;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            _teamLabel(key),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      sections.addAll(players.map((id) {
        final name = names[id] ?? tr('player');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(name)),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: controllers[id],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('goals'),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        );
      }));
    }

    return sections;
  }

  Future<Map<String, String>> _loadParticipantNames(List<String> ids) async {
    final names = <String, String>{};
    for (final id in ids) {
      try {
        final row = await _sb
            .from('profiles')
            .select('display_name, email')
            .eq('id', id)
            .maybeSingle();
        names[id] = (row?['display_name'] ??
                row?['email']?.toString().split('@').first ??
                tr('player'))
            .toString();
      } catch (_) {
        names[id] = tr('player');
      }
    }
    return names;
  }
    // Метод для отримання кольору рівня
  Color _getLevelColor(MatchLevel level) {
    switch (level) {
      case MatchLevel.beginner:
        return Colors.green;
      case MatchLevel.intermediate:
        return Colors.yellow;
      case MatchLevel.advanced:
        return Colors.orange;
      case MatchLevel.professional:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  String _convertUserStatus(String status) {
  switch (status) {
    case 'organizer':
      return tr('manage');
    case 'participant':
      return tr('participant');
    case 'pending':
      return tr('il_f4e93d19a0');
    case 'rejected':
      return tr('reject');
    case 'none':
      return tr('apply');
    default:
      return tr('apply');
  }
} 

  // Картка матчу для історії (детальна як у MVP)
  Widget _buildHistoryMatchCard(Match match) {
    final currentUserId = AppAuth.currentUserId;
    if (currentUserId == null) return const SizedBox.shrink();

    // Визначаємо результат матчу для поточного користувача
    final matchResult = _getMatchResultForUser(match, currentUserId);
    final resultColor = _getResultColor(matchResult);
    final resultText = _getResultText(matchResult);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок та результат
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Результат матчу
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: resultColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    resultText,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Мета-інформація
            Row(
  children: [
    const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        '${match.date.day}.${match.date.month}.${match.date.year}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    ),
    const SizedBox(width: 12),
    const Icon(Icons.people, color: Colors.white70, size: 16),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        '${match.teamA?.name ?? tr('il_e18d322f14')} vs ${match.teamB?.name ?? tr('il_aceaf5d9ac')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  ],
),
            
            const SizedBox(height: 8),
            
            // Рахунок (якщо є)
            if (match.teamAScore != null && match.teamBScore != null) ...[
              Row(
                children: [
                  Icon(Icons.sports_soccer, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${tr('score')} ${match.teamAScore}:${match.teamBScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Рейтинг користувача після матчу
            FutureBuilder<double>(
              future: _ratingsRepo.getUserRating(currentUserId),
              builder: (context, snapshot) {
                final rating = snapshot.hasData ? snapshot.data! : 0.0;
                return Row(
                  children: [
                    Icon(Icons.star, color: const Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${tr('your_rating')} ${rating.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 12),

            if (match.coverPhotoUrl?.isNotEmpty == true) ...[
              _buildMatchPhotoFooter(match),
              const SizedBox(height: 12),
            ],
            
            // Кнопка деталей
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.router.push(MatchDetailsRoute(match: match)),
                  child: Text(
                    tr('match_details'),
                    style: TextStyle(
                      color: Color(0xFF4caf50),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (match.status == MatchStatus.finished &&
                    match.participants.contains(currentUserId))
                  TextButton(
                    onPressed: () {
                      context.router.push(MatchRatingRoute(match: match));
                    },
                    child: Text(
                      tr('rate_players'),
                      style: TextStyle(
                        color: Color(0xFF4caf50),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Визначення результату матчу для користувача
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

  // Кольори для результатів
  Color _getResultColor(String result) {
    switch (result) {
      case 'win':
        return const Color(0xFF4CAF50); // Зелений
      case 'loss':
        return const Color(0xFFf44336); // Червоний
      case 'draw':
        return const Color(0xFFFFC107); // Жовтий
      default:
        return const Color(0xFF9E9E9E); // Сірий
    }
  }

  // Текст для результатів
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

  void _navigateToMatchDetails(Match match) {
    context.router.push(MatchDetailsRoute(match: match));
  }

  void _navigateToMatchManagement(Match match) {
    context.router.push(MatchManagementRoute(match: match));
  }
  // Додати цей метод після рядка 1812 (після _getLevelText)

Widget _buildLevelChip(MatchLevel level) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getLevelColor(level).withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _getLevelColor(level).withValues(alpha: 0.5),
        width: 1,
      ),
    ),
    child: Text(
      _getLevelText(level),
      style: TextStyle(
        color: _getLevelColor(level),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _buildRatingItem(Map<String, dynamic> p, int rank) {
  final String name = (p['name']
        ?? p['displayName']
        ?? ((p['firstName'] != null || p['lastName'] != null)
            ? '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()
            : null)
        ?? tr('il_b764cdc0ea')).toString();

  final double rating = ((p['rating'] ?? 0) as num).toDouble();
  final String rawPosition = (p['position'] ?? '').toString();
  final String position = _humanPosition(rawPosition);
  final String city = (p['city'] ?? tr('unknown')).toString();
  final String avatar = (p['avatarUrl'] ?? p['photoUrl'] ?? '').toString();
  final _Level lvl = _levelFor(rating);
  final int matchesCount = ((p['totalMatches'] ?? p['matches'] ?? p['matchesPlayed'] ?? 0) as num).toInt();
  final positionLabel = _localizedPosition(position);   // додаємо над Text
  final cityLabel = _localizedCity(city);

  return InkWell(
    onTap: () => context.router.push(
      PlayerProfileRoute(
        playerId: p['id'].toString(),
        playerName: name,
      ),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Text(city, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Text(tr('il_1cbac19546'),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(lvl.color).withValues(alpha: 0.15),
                  border: Border.all(color: Color(lvl.color).withValues(alpha: 0.5)),
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
                style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.3),
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
    final String medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
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
      style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
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
        Text(val.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

String _localizedPosition(String raw) {
  switch (raw.toLowerCase()) {
    case 'goalkeeper':
    case 'воротар':
      return tr('il_f2d20c7ee1');
    case 'defender':
    case 'захисник':
      return tr('il_157ddc59b5');
    case 'midfielder':
    case 'півзахисник':
      return tr('il_d332e47845');
    case 'forward':
    case 'нападник':
      return tr('il_f1c65e1481');
    case 'universal':
    case 'універсал':
      return tr('il_ab28eea9ef');
    default:
      return tr('il_a62e8c639a');
  }
}

String _localizedCity(String raw) {
  if (raw.trim().isEmpty) {
    return tr('il_49980d893f');
  }
  return raw;
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
  if (rating >= 3.5) return _Level(tr('il_9f088dbebd'), 0xFFFF9800);
  if (rating >= 2.5) return _Level(tr('il_3b1cfa63d7'), 0xFF2196F3);
  if (rating >= 1.5) return _Level(tr('beginner'), 0xFF4CAF50);
  return _Level(tr('il_ea0bedb7c8'), 0xFF9E9E9E);
}

String _humanPosition(String raw) {
  switch (raw) {
    case 'goalkeeper': return tr('il_f2d20c7ee1');
    case 'defender':   return tr('il_157ddc59b5');
    case 'midfielder': return tr('il_d332e47845');
    case 'forward':    return tr('il_f1c65e1481');
    default:           return raw.isEmpty ? tr('unknown') : raw;
  }
}
String _positionCodeFromUi(String ui) {
  switch (ui) {
    case 'Воротар': return 'goalkeeper';
    case 'Захисник': return 'defender';
    case 'Півзахисник': return 'midfielder';
    case 'Нападник': return 'forward';
    default: return ui;
  }
}
const Set<String> _posCodes = {'goalkeeper', 'defender', 'midfielder', 'forward'};

String _norm(String? s) => (s ?? '').trim().toLowerCase();

