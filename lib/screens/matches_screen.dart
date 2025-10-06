import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import 'create_match_screen.dart';
import 'match_details_screen.dart';
import 'video_main_screen.dart';
import '../services/match_service.dart';
import 'ratings_screen.dart';
import '../widgets/rating_display.dart';
import '../services/rating_service.dart';
import 'match_management_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../widgets/user_chip.dart';
import '../services/notification_service.dart';




class MatchesScreen extends StatefulWidget {
  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with TickerProviderStateMixin {
  // Змінна для поточної вкладки
  int _currentTabIndex = 0;

  // Назви вкладок
  final List<String> _tabTitles = [
    'Знайти матч',
    'Мої матчі',
    'Історія',
    'Рейтинги'
  ];

  // Змінні для фільтрів
  String _selectedCity = 'Всі міста';
  String _selectedLevel = 'Всі рівні';
  String _selectedTime = 'Будь-коли';
  String _searchQuery = '';

  // Списки опцій для фільтрів
  final List<String> _cityOptions = [
    'Всі міста',
    'Київ',
    'Харків',
    'Одеса',
    'Дніпро',
    'Львів'
  ];

  final List<String> _levelOptions = [
    'Всі рівні',
    'Початковий',
    'Середній',
    'Високий',
    'Професійний'
  ];

  final List<String> _timeOptions = [
    'Будь-коли',
    'Сьогодні',
    'Завтра',
    'Цього тижня'
  ];

  // Змінні для "Мої матчі"
  String _selectedMyMatchesFilter = 'Всі';
  final List<String> _myMatchesFilters = ['Всі', 'Організовані', 'Участь'];

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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Підтвердити')),
        ],
      ),
    );
  }

  final MatchService _matchService = MatchService();
  final RatingService _ratingService = RatingService();
  final NotificationService _notificationService = NotificationService();
  // Стан фільтрів рейтингів (замість ValueNotifier використовуємо звичайний state)
  String _ratingsSelectedCity = 'Всі міста';
  String _ratingsSelectedPosition = 'Всі позиції';
  Future<List<Map<String, dynamic>>>? _ratingsTopPlayersFuture;

    @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabTitles.length,
      vsync: this,
    );
    
    // Завантажуємо топ гравців один раз
    _ratingsTopPlayersFuture = _ratingService.getTopPlayers(limit: 300);
  }
  @override
void dispose() {
  _searchDebounce?.cancel();
  _tabController.dispose();
  super.dispose();
}

@override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['initialTabIndex'] is int) {
      final idx = args['initialTabIndex'] as int;
      if (idx >= 0 && idx < _tabController.length && _tabController.index != idx) {
        _tabController.index = idx;
      }
    }
  }

void _resetFindFilters() {
  setState(() {
    _selectedCity = 'Всі міста';
    _selectedLevel = 'Всі рівні';
    _selectedTime = 'Будь-коли';
    _searchQuery = '';
  });
}
// Метод для створення фільтрів
Widget _buildFilters() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      children: [
        LayoutBuilder(
  builder: (context, constraints) {
    final bool narrow = constraints.maxWidth < 380;
    final city = Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(
                  labelText: '🏙️ Місто',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.location_city, color: Colors.white70, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF4caf50)),
                  ),
                ),
                dropdownColor: Color(0xFF1a1a2e),
                style: TextStyle(color: Colors.white),
                items: _cityOptions.map((city) =>
                  DropdownMenuItem(
                    value: city,
                    child: Text(city, style: TextStyle(color: Colors.white)),
                  )
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value ?? 'Всі міста';
                  });
                },
              ),
            );
    final level = Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedLevel,
                decoration: InputDecoration(
                  labelText: '📊 Рівень',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.star, color: Colors.white70, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
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
                    _selectedLevel = value ?? 'Всі рівні';
                  });
                },
              ),
            );
    return narrow
      ? Column(children: [city, SizedBox(height: 12), level])
      : Row(children: [city, SizedBox(width: 16), level]);
  },
),
        SizedBox(height: 16),
        LayoutBuilder(
  builder: (context, constraints) {
    final bool narrow = constraints.maxWidth < 380;
    final time = Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedTime,
                decoration: InputDecoration(
                  labelText: '⏰ Час',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.access_time, color: Colors.white70, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
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
                    _selectedTime = value ?? 'Будь-коли';
                  });
                },
              ),
            );
    final search = Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: '🔍 Пошук',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'Пошук матчів...',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
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
      : Row(children: [time, SizedBox(width: 16), search]);
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
              label: Text('Скинути фільтри', style: TextStyle(color: Colors.white70)),
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
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
      ),
    ),
  ),
  title: Row(
    children: [
      // Логотип з MVP (PNG з assets)
Container(
  width: 34,
  height: 34,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: Offset(0, 2)),
    ],
  ),
  clipBehavior: Clip.antiAlias,
  child: Image.asset('assets/logo/flap_logo.jpg', fit: BoxFit.cover, filterQuality: FilterQuality.high),
),
      SizedBox(width: 16),
      Text(
        'FLAP',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      Spacer(),
         // Монети: живий баланс + перехід у "Мої монети"
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final coins = snapshot.hasData && snapshot.data!.exists
              ? (snapshot.data!.data()?['coins'] ?? 0) as int
              : 0;
          return GestureDetector(
            onTap: () => _showCoinsSheet(coins),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: isCompact ? 4 : 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFD700).withOpacity(0.2),
                    Color(0xFFFFA000).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(0xFFFFD700).withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFFD700).withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: isCompact ? 16 : 18),
                  SizedBox(width: 6),
                  Text(
                    coins.toString(),
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: isCompact ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
            ),
      SizedBox(width: 12),
      // Кнопка сповіщень
      StreamBuilder<int>(
        stream: _notificationService.getUnreadCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return Stack(
            children: [
              Container(
                width: isCompact ? 36 : 40,
                height: isCompact ? 36 : 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_outlined, 
                    color: Colors.white, 
                    size: isCompact ? 18 : 20
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/notifications'),
                  padding: EdgeInsets.zero,
                  tooltip: 'Сповіщення',
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
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
      SizedBox(width: 12),
      // Кнопка створення матчу з градієнтом
      Container(
        width: isCompact ? 36 : 40,
        height: isCompact ? 36 : 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4caf50).withOpacity(0.4),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.add, color: Colors.white, size: isCompact ? 18 : 20),
          onPressed: () => Navigator.pushNamed(context, '/create-match'),
          padding: EdgeInsets.zero,
        ),
      ),
      SizedBox(width: 12),
      // Аватар користувача з градієнтом
       Container(
        width: isCompact ? 36 : 40,
        height: isCompact ? 36 : 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4caf50).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String avatarUrl = '';
            String displayName = '';
            if (snapshot.hasData && snapshot.data!.exists) {
              final d = snapshot.data!.data()!;
              avatarUrl = (d['avatarUrl'] ?? d['photoUrl'] ?? '') as String? ?? '';
              displayName = (d['displayName'] ?? d['name'] ?? d['authorName'] ?? '') as String? ?? '';
            }
            return IconButton(
  padding: EdgeInsets.zero,
  onPressed: () => Navigator.pushNamed(context, '/profile'),
  icon: CircleAvatar(
    radius: isCompact ? 18 : 20,
    backgroundColor: const Color(0xFF4caf50),
    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
    child: avatarUrl.isEmpty
        ? Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          )
        : null,
  ),
);
          },
        ),
      ),
      SizedBox(width: 12),
      // Рейтинг з покращеним дизайном
           // Рейтинг (стиль як у відео: зелений чип)
 Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showRatingModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4caf50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4caf50), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Color(0xFF4caf50), size: 16),
              const SizedBox(width: 4),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final rating = snapshot.hasData && snapshot.data!.exists
                      ? (snapshot.data!.data()?['rating'] ?? 3.0).toDouble()
                      : 3.0;
                  return Text(
                    rating.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Color(0xFF4caf50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    )
    ],
  ),
  actions: [
    // Перемикач режимів з покращеним дизайном
    Container(
      margin: EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: IconButton(
        tooltip: 'Перейти до відео',
        icon: Icon(Icons.video_library, color: Colors.white, size: 20),
        onPressed: () => Navigator.pushNamed(context, '/video-main'),
      ),
    ),
  ],
  
  bottom: PreferredSize(
    preferredSize: Size.fromHeight(70),
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TabBar(
  controller: _tabController,
  isScrollable: true,
  labelPadding: EdgeInsets.symmetric(horizontal: 8),
  tabs: _tabTitles.map((title) => Tab(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8),
      child: Text(
        title,
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.all(5),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Кнопка переходу до відео (як в MVP)
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  // Перехід до відео режиму
                  Navigator.pushNamed(context, '/video-main');
                },
                child: const Center(
                  child: Text(
                    '📹',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          
          // Основна FAB кнопка створення матчу
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4caf50),
                  Color(0xFF66bb6a),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF4caf50).withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create-match');
              },
              child: Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.transparent,
              elevation: 0,
              tooltip: 'Створити матч',
            ),
          ),
        ],
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
            border: Border.all(color: Colors.white.withOpacity(0.08)),
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
            color: const Color(0xFF4caf50).withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.star, color: Colors.white, size: 18),
    ),
    const SizedBox(width: 12),
    const Expanded(
      child: Text(
        'Мій рейтинг',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
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
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final rating = snapshot.hasData && snapshot.data!.exists
                            ? ((snapshot.data!.data()?['rating'] ?? 0.0) as num).toDouble()
                            : 0.0;
                        return RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Поточний рейтинг: ',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
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
  color: const Color(0xFF1e7d32).withOpacity(0.20),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: const Color(0xFF1e7d32).withOpacity(0.40)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF4caf50).withOpacity(0.25),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Center(
                        child: Text(
                          'Як формується рейтинг?',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      SizedBox(height: 10),

                      // Формула
                      Text('Формула', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(
                        'Загальний рейтинг = (Рейтинг матчів × 0.7) + (Рейтинг відео × 0.3)',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      SizedBox(height: 10),
                      // Ваги
                      Text('Ваги', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('• Матчі — 70%', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('• Відео/Челенджі — 30%', style: TextStyle(color: Colors.white70, fontSize: 13)),

                      SizedBox(height: 10),
                      // Матчі
                      Text('Рейтинг матчів', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('• Критерії (по 25%): Техніка, Фізика, Тактика, Командна гра', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('• Після матчу гравці оцінюють один одного', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('• Самооцінка заборонена', style: TextStyle(color: Colors.white70, fontSize: 13)),

                      SizedBox(height: 10),
                      // Відео/челенджі
                      Text('Рейтинг відео', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(
                        '• Критерії: Технічне виконання (40%), Креативність (30%), Складність (20%), Якість відео (10%)',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      SizedBox(height: 10),
                      // Захист
                      Text('Захист від накручувань', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('• Діапазон 0.0–5.0, валідація та перевірка аномалій', style: TextStyle(color: Colors.white70, fontSize: 13)),

                      SizedBox(height: 10),
                      // Рівні гравців
                      Text('Рівні гравців', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(
                        '0.0–1.5 Новачок • 1.5–2.5 Початковий • 2.5–3.5 Середній • 3.5–4.5 Високий • 4.5–5.0 Професійний',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Історія змін рейтингу (нове)
StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .snapshots(),
  builder: (context, snap) {
    if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
    final data = snap.data!.data() ?? {};
    final List<Map<String, dynamic>> history =
        List<Map<String, dynamic>>.from(data['ratingHistory'] ?? []);
    if (history.isEmpty) return const SizedBox.shrink();

    // нові зверху
    history.sort((a, b) {
      final ta = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    return Column(
      children: history.asMap().entries.map((e) {
        final i = e.key;
        final h = e.value;
        final dt = (h['timestamp'] as Timestamp?)?.toDate();
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
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Оцінка після матчу', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                          const Text('Мої монети',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          Text('Поточний баланс: $currentCoins монет',
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Історія транзакцій',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                    }
                    final txDocs = snapshot.data!.docs.toList();
                    txDocs.sort((a, b) {
                      final ad = a.data() as Map<String, dynamic>;
                      final bd = b.data() as Map<String, dynamic>;
                      final at = ad['timestamp'] as Timestamp?;
                      final bt = bd['timestamp'] as Timestamp?;
                      if (at == null && bt == null) return 0;
                      if (at == null) return 1;
                      if (bt == null) return -1;
                      return bt.compareTo(at);
                    });
                    if (txDocs.isEmpty) {
                      return const Center(
                        child: Text('Поки немає транзакцій', style: TextStyle(color: Colors.white70)),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: txDocs.length,
                      itemBuilder: (context, index) {
                        final t = txDocs[index].data() as Map<String, dynamic>;
                        final amount = t['amount'] ?? 0;
                        final description = t['description'] ?? '';
                        final timestamp = t['timestamp'] as Timestamp?;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: amount > 0 ? const Color(0xFF4caf50).withOpacity(0.2) : Colors.red.withOpacity(0.2),
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
                                    if (timestamp != null)
                                      Text(_formatTransactionTime(timestamp.toDate()),
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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

  String _formatTransactionTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7) {
      const months = ['січ','лют','бер','квіт','трав','черв','лип','серп','вер','жовт','лист','груд'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} дн. тому';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} год. тому';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} хв. тому';
    } else {
      return 'Щойно';
    }
  }

  // ВКЛАДКА 1: Знайти матч
  Widget _buildFindMatchTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Фільтри
          _buildFilters(),

          // Список доступних матчів
          StreamBuilder<List<Match>>(
            stream: _getFilteredMatches(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Помилка завантаження: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
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
                      Icon(
                        Icons.sports_soccer,
                        size: 64,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Немає доступних матчів',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Створіть новий матч або зачекайте',
                        style: TextStyle(
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
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text('Знайдено: ${items.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          TextButton(
            onPressed: _resetFindFilters,
            child: const Text('Скинути', style: TextStyle(color: Colors.white70)),
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
                label: const Text('Всі'),
                selected: _selectedMyMatchesFilter == 'Всі',
                onSelected: (_) => setState(() => _selectedMyMatchesFilter = 'Всі'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Організовані'),
                selected: _selectedMyMatchesFilter == 'Організовані',
                onSelected: (_) => setState(() => _selectedMyMatchesFilter = 'Організовані'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Участь'),
                selected: _selectedMyMatchesFilter == 'Участь',
                onSelected: (_) => setState(() => _selectedMyMatchesFilter = 'Участь'),
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
                    'Помилка завантаження: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
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
                        'У вас поки немає матчів',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Створіть новий матч або приєднайтеся до існуючого',
                        style: TextStyle(
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
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              List<Match> filtered = all;
              if (_selectedMyMatchesFilter == 'Організовані' && currentUserId != null) {
                filtered = all.where((m) => m.organizerId == currentUserId).toList();
              } else if (_selectedMyMatchesFilter == 'Участь' && currentUserId != null) {
                filtered = all.where((m) => m.participants.contains(currentUserId) && m.organizerId != currentUserId).toList();
              }
              // Найближчі зверху
              filtered.sort((a, b) => a.date.compareTo(b.date));

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
          return Center(child: Text('Помилка: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
        }
        final matches = snapshot.data!;
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.history, size: 64, color: Colors.white54),
                SizedBox(height: 12),
                Text('Історія матчів порожня', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Заголовок секції як у MVP
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: const Text(
                '📊 Історія матчів',
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

  // Локальні хелпери для фільтрації (не залежать від наявності зовнішніх функцій)
  String norm(String? s) => (s ?? '').trim().toLowerCase();

  // Синоніми міст для надійного матчінгу
  final Map<String, List<String>> cityAliases = <String, List<String>>{
    'Київ':   ['київ', 'kyiv', 'kiev'],
    'Харків': ['харків', 'kharkiv'],
    'Одеса':  ['одеса', 'odesa', 'odessa'],
    'Дніпро': ['дніпро', 'dnipro', 'dnepr', 'dnepropetrovsk'],
    'Львів':  ['львів', 'lviv', 'lwow', 'lwów'],
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
    // Побудова вузького дропдауна без підпису
  Widget narrowDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    Key? key,
  }) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        key: key,
        value: value,
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
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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
              const Text('Рейтинги',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
            ],
          ),
        ),

        // Підтаби
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Загальний рейтинг'),
              Tab(text: 'За містом'),
              Tab(text: 'За позицією'),
              Tab(text: 'Моя статистика'),
            ],
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
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Text('🏆 Топ гравці',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
                              options: const ['Всі міста', 'Київ', 'Харків', 'Одеса', 'Дніпро', 'Львів'],
                              onChanged: (v) {
                                setState(() {
                                  _ratingsSelectedCity = v ?? 'Всі міста';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Text('🏆 Топ гравці',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: () {
                          final String? cityFilter = (_ratingsSelectedCity == 'Всі міста') ? null : _ratingsSelectedCity;
                          final list = (cityFilter == null)
                              ? all
                              : all.where((p) => cityMatches((p['city'] ?? '').toString(), cityFilter)).toList();
                          if (list.isEmpty) {
                            return const Center(
                              child: Text('Пусто для вибраного міста',
                                  style: TextStyle(color: Colors.white70)),
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
                              options: const ['Всі позиції', 'Воротар', 'Захисник', 'Півзахисник', 'Нападник'],
                              onChanged: (v) {
                                setState(() {
                                  _ratingsSelectedPosition = v ?? 'Всі позиції';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Text('🏆 Топ гравці',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: () {
                          final String? positionFilter =
                              (_ratingsSelectedPosition == 'Всі позиції') ? null : toCode(_ratingsSelectedPosition);
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
                            return const Center(
                              child: Text('Пусто для вибраної позиції',
                                  style: TextStyle(color: Colors.white70)),
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
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) {
                        return const Center(
                          child: Text('Увійдіть, щоб побачити статистику',
                              style: TextStyle(color: Colors.white70)),
                        );
                      }
                      return FutureBuilder<Map<String, dynamic>>(
                        future: _ratingService.getUserRatingStats(uid),
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
                              _statTile('Поточний рейтинг', current),
                              const SizedBox(height: 8),
                              _statTile('Рейтинг з матчів (70%)', m),
                              const SizedBox(height: 8),
                              _statTile('Рейтинг з відео/челенджів (30%)', v),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _chipStat(Icons.sports_soccer, 'Матчі', tm),
                                  const SizedBox(width: 8),
                                  _chipStat(Icons.videocam, 'Відео', tv),
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
  // Метод для розрахунку середнього рейтингу учасників
  Future<double> _calculateAverageRating(List<String> participantIds) async {
    try {
      if (participantIds.isEmpty) return 3.0; // Початковий рейтинг

      double totalRating = 0.0;
      int ratedParticipants = 0;

      for (final participantId in participantIds) {
        final rating = await RatingService().getUserRating(participantId);
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return SizedBox.shrink();

    final userStatus = match.getUserStatus(currentUser.uid);
    final isOrganizer = userStatus == 'organizer';
    final isParticipant = userStatus == 'participant';
    final isFinished = match.status == MatchStatus.finished;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок та статус
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  match.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isFinished)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Завершено',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Деталі матчу
          _buildMatchDetails(match),
          
          SizedBox(height: 16),
          
          // Кнопки дій
          _buildActionButtons(match, currentUser.uid),
        ],
      ),
    );
  }

// ... existing code ...

Widget _buildMatchDetails(Match match) {
  // Діагностика
  print('DEBUG: Building match details for ${match.title}');
  print('DEBUG: Participants count: ${match.participants.length}');
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
            'Рівень: ${_getLevelText(match.level)}',
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
                'Середній рейтинг: $avg',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          );
        },
      ),
      
      SizedBox(height: 8),
      
      // Кількість гравців з аватарками
      Row(
        children: [
          Icon(Icons.people, color: Colors.white70, size: 16),
          SizedBox(width: 8),
          Text(
            '${match.participants.length}/${match.maxPlayers} учасників',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Spacer(),
          // Аватарки учасників
          if (match.participants.isNotEmpty) ...[
            ...match.participants.take(5).map((id) {
  return Container(
    margin: EdgeInsets.only(right: 4),
    child: UserChip(
      userId: id,
      size: 22,
      showName: false,
    ),
  );
}).toList(),
            if (match.participants.length > 5)
              Container(
                margin: EdgeInsets.only(left: 4),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    '+${match.participants.length - 5}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ] else ...[
            // Якщо немає учасників, показуємо порожні круги
            ...List.generate(3, (index) {
              return Container(
                margin: EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  child: Icon(
                    Icons.person_add,
                    color: Colors.white.withOpacity(0.5),
                    size: 12,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
      
      SizedBox(height: 8),
      
      // Організатор
      Row(
        children: [
          Icon(Icons.person, color: Colors.white70, size: 16),
          SizedBox(width: 8),
          Text(
            'Організатор: ${match.organizerName}',
            style: TextStyle(color: Colors.white70, fontSize: 14),
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

  // Приватний матч — лише за запрошенням
  if (match.isPrivate && !match.invitedFriends.contains(currentUserId)) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock, color: Colors.white70, size: 16),
          SizedBox(width: 8),
          Text('Приватний матч: доступ за запрошенням', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // Відкритий матч і користувач не учасник — показати три компактні кнопки
  if (userStatus == 'Подати заявку' && match.status == MatchStatus.open) {
    return Row(
      children: [
        // Приєднатися (градієнт)
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4caf50).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () => _applyForMatch(match.id),
              child: const Text(
                'Приєднатися',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Деталі (outline)
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/match-details', arguments: match),
              child: const Text(
                'Деталі',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Поділитися (outline)
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: TextButton(
              onPressed: () {
                final url = 'https://flap.app/match/${match.id}';
                Share.share('Приєднуйся до матчу: $url');
              },
              child: const Text(
                'Поділитися',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
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
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/match-details', arguments: match);
            },
            child: const Text(
              'Деталі',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Поділитися (зелена)
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4caf50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: () {
              final url = 'https://flap.app/match/${match.id}';
              Share.share('Приєднуйся до матчу: $url');
            },
            child: const Text(
              'Поділитися',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ],
  );
}



 Stream<List<Match>> _getFilteredMatches() {
  return _matchService.getAvailableMatches().map((matches) {
    final filtered = matches.where((match) {
      // Фільтр по місту
      if (_selectedCity != 'Всі міста' && match.city != _selectedCity) return false;
      // Фільтр по рівню
      if (_selectedLevel != 'Всі рівні' && _getLevelText(match.level) != _selectedLevel) return false;
      // Фільтр по часу
      if (_selectedTime != 'Будь-коли') {
        final now = DateTime.now();
        final matchDate = match.date;
        switch (_selectedTime) {
          case 'Сьогодні':
            if (!_isSameDay(matchDate, now)) return false;
            break;
          case 'Завтра':
            final tomorrow = now.add(const Duration(days: 1));
            if (!_isSameDay(matchDate, tomorrow)) return false;
            break;
          case 'Цього тижня':
            final weekEnd = now.add(const Duration(days: 7));
            if (matchDate.isBefore(now) || matchDate.isAfter(weekEnd)) return false;
            break;
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
    // Сортування: найближчі матчі зверху
    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  });
}
  // Метод для отримання матчів користувача
  Stream<List<Match>> _getUserMatches() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);
    return _matchService.getUserMatches(currentUser.uid);
  }

  // ІСТОРІЯ: завершені матчі користувача (новіші зверху)
  Stream<List<Match>> _getHistoryMatches() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);
    return _matchService.getUserMatches(currentUser.uid).map((list) {
      final finished = list.where((m) => m.status == MatchStatus.finished).toList();
      finished.sort((a, b) => b.date.compareTo(a.date));
      return finished;
    });
  }

  // Метод для отримання кольору статусу
Color _getStatusColor(MatchStatus status) {
  switch (status) {
    case MatchStatus.open:
      return Color(0xFF4caf50); // Зелений як в MVP
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

String _getStatusText(MatchStatus status) {
  switch (status) {
    case MatchStatus.open:
      return 'Відкрито';
    case MatchStatus.full:
      return 'Заповнено';
    case MatchStatus.inProgress:
      return 'В процесі';
    case MatchStatus.finished:
      return 'Завершено';
    case MatchStatus.cancelled:
      return 'Скасовано';
    default:
      return 'Невідомо';
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
      return 'Сьогодні ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Завтра ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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
        return 'Початковий';
      case MatchLevel.intermediate:
        return 'Середній';
      case MatchLevel.advanced:
        return 'Високий';
      case MatchLevel.professional:
        return 'Професійний';
      default:
        return 'Невідомо';
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
            '⚽ Мої матчі',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/create-match'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4caf50),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Створити матч',
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
  final currentUser = FirebaseAuth.instance.currentUser;
  final isOrganizer = currentUser?.uid == match.organizerId;
  final role = isOrganizer ? 'Організатор' : 'Учасник';

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.02),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок та статус + бейдж заявок
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '${match.date.day}.${match.date.month} о ${match.time}',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(width: 15),
                      Icon(Icons.location_on, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        match.location,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(width: 15),
                      
                    ],
                  ),
                  const SizedBox(height: 6),
Row(
  children: [
    isOrganizer
        ? Text('👑', style: TextStyle(fontSize: 16)) // корона для організатора
        : Icon(Icons.person, color: Colors.white70, size: 16),
    SizedBox(width: 4),
    Text(
      role, // 'Організатор' або 'Учасник'
      style: TextStyle(color: Colors.white70, fontSize: 14),
    ),
  ],
),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(match.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getStatusText(match.status),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (match.pendingApplications.isNotEmpty &&
    match.status != MatchStatus.finished &&
    match.status != MatchStatus.cancelled) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${match.pendingApplications.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        // Кількість гравців
        Row(
          children: [
            Icon(Icons.people, color: Colors.white70, size: 16),
            SizedBox(width: 4),
            Text(
              '${match.currentPlayers}/${match.maxPlayers}',
              style: TextStyle(color: Colors.white70, fontSize: 14),
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
    if (isOrganizer && match.status != MatchStatus.finished)
      ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/match_management',
            arguments: match,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4caf50),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Управління',
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
        Navigator.pushNamed(
          context,
          '/match-details',
          arguments: match,
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        'Деталі',
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
            currentUser != null &&
            match.participants.contains(currentUser.uid)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isLeaving
                    ? null
                    : () async {
                        final sure = await _confirm('Вийти з матчу?', 'Ви впевнені, що хочете вийти?');
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
                  _isLeaving ? 'Вихід…' : 'Вийти з матчу',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],

        // Швидкі дії для організатора
        if (isOrganizer) ...[
          const SizedBox(height: 12),
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
                  onPressed: () async {
                    final sure = await _confirm('Почати матч?', 'Після початку рахунок стане доступним і дії зміняться.');
                    if (sure != true) return;
                    await _onStartMatch(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196f3),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Почати матч',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (match.status != MatchStatus.inProgress && match.hasTeams)
                const SizedBox(width: 8),
              if (match.status == MatchStatus.inProgress)
                ElevatedButton(
                  onPressed: () async {
                    final sure = await _confirm('Завершити матч?', 'Потрібно ввести рахунок команд.');
                    if (sure != true) return;
                    await _onFinishMatch(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Завершити',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
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
                  'Лише організатор може формувати команди, розпочати або завершити матч.',
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
    final ok = await _matchService.startMatch(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Матч розпочато' : 'Не вдалося розпочати матч'),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }


  // Метод для подачі заявки на матч
  Future<void> _applyForMatch(String matchId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Потрібно увійти в систему'), backgroundColor: Colors.red),
        );
        return;
      }

      final success = await _matchService.applyForMatch(matchId, currentUser.uid);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Заявку подано! Очікуйте відповіді організатора.'),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ви вже подали заявку на участь у цьому матчі.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // Вихід з матчу
Future<void> _onLeaveMatch(Match match) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Потрібно увійти в систему'), backgroundColor: Colors.red),
      );
      return;
    }

    final ok = await _matchService.leaveMatch(match.id, currentUser.uid);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Ви вийшли з матчу' : 'Не вдалося вийти з матчу'),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
    );
  }
}
    // Дії організатора
  Future<void> _onAutoBalance(Match match) async {
    final ok = await _matchService.autoBalanceTeams(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Команди сформовано' : 'Не вдалося сформувати команди'),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }

  Future<void> _onStartMatch(Match match) async {
    final ok = await _matchService.startMatch(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Матч розпочато' : 'Не вдалося розпочати матч'),
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

    final ok = await _matchService.finishMatch(match.id, result, a, b);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Матч завершено' : 'Не вдалося завершити матч'),
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
        title: const Text('Завершити матч'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Голи команди A')),
            TextField(controller: bCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Голи команди B')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () {
              final int? a = int.tryParse(aCtrl.text);
              final int? b = int.tryParse(bCtrl.text);
              if (a == null || b == null || a < 0 || b < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введіть коректні рахунки'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx, {'teamAScore': a, 'teamBScore': b});
            },
            child: const Text('Підтвердити'),
          ),
        ],
      ),
    );
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
      return 'Управління';
    case 'participant':
      return 'Учасник';
    case 'pending':
      return 'Заявка подана';
    case 'rejected':
      return 'Відхилено';
    case 'none':
      return 'Подати заявку';
    default:
      return 'Подати заявку';
  }
}

  // Картка матчу для історії (детальна як у MVP)
  Widget _buildHistoryMatchCard(Match match) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                    color: resultColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: resultColor.withOpacity(0.4)),
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
                Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${match.date.day}.${match.date.month}.${match.date.year}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.people, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${match.teamA?.name ?? 'Команда A'} vs ${match.teamB?.name ?? 'Команда B'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                    'Рахунок: ${match.teamAScore}:${match.teamBScore}',
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
              future: _ratingService.getUserRating(currentUserId),
              builder: (context, snapshot) {
                final rating = snapshot.hasData ? snapshot.data! : 0.0;
                return Row(
                  children: [
                    Icon(Icons.star, color: const Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Ваш рейтинг: ${rating.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            // Кнопка деталей
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/match-details', arguments: match),
                  child: const Text(
                    'Деталі матчу',
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
                      Navigator.pushNamed(
                        context,
                        '/match_rating',
                        arguments: match,
                      );
                    },
                    child: const Text(
                      'Оцінити гравців',
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
        return 'Перемога';
      case 'loss':
        return 'Поразка';
      case 'draw':
        return 'Нічия';
      default:
        return 'Завершено';
    }
  }

  void _navigateToMatchDetails(Match match) {
    Navigator.pushNamed(context, '/match-details', arguments: match);
  }

  void _navigateToMatchManagement(Match match) {
    Navigator.pushNamed(context, '/match-management', arguments: match);
  }
  // Додати цей метод після рядка 1812 (після _getLevelText)

Widget _buildLevelChip(MatchLevel level) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getLevelColor(level).withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _getLevelColor(level).withOpacity(0.5),
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
        ?? 'Невідомий').toString();

  final double rating = ((p['rating'] ?? 0) as num).toDouble();
  final String rawPosition = (p['position'] ?? '').toString();
  final String position = _humanPosition(rawPosition);
  final String city = (p['city'] ?? 'Невідомо').toString();
  final String avatar = (p['avatarUrl'] ?? p['photoUrl'] ?? '').toString();
  final _Level lvl = _levelFor(rating);
  final int matchesCount = ((p['totalMatches'] ?? p['matches'] ?? p['matchesPlayed'] ?? 0) as num).toInt();

  return InkWell(
    onTap: () => Navigator.pushNamed(
      context,
      '/player-profile',
      arguments: {'playerId': p['id'], 'playerName': name},
    ),
    child: Container(
  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.04),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.08)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _rankBadge(rank),
      const SizedBox(width: 14),
            Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white12,
        ),
        clipBehavior: Clip.antiAlias,
        child: avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Якщо помилка завантаження - показуємо літеру
                  return Container(
                    color: Colors.white12,
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
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
                    fontSize: 20,
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Row(
  children: [
    Text(
      position.isNotEmpty ? position : 'Невідомо',
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    ),
    const SizedBox(width: 6),
    const Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
    const SizedBox(width: 6),
    Text(city, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    const SizedBox(width: 6),
    const Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
    const SizedBox(width: 6),
    Text('$matchesCount матчів', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(lvl.color).withOpacity(0.15),
              border: Border.all(color: Color(lvl.color).withOpacity(0.5)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(lvl.label, style: TextStyle(color: Color(lvl.color), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Text('РЕЙТИНГ', style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.4)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(2),
                style: const TextStyle(color: Color(0xFF4caf50), fontWeight: FontWeight.w800, fontSize: 16),
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
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
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

Widget _chipStat(IconData icon, String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
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
  const _Level(this.label, this.color);
}

_Level _levelFor(double rating) {
  if (rating >= 4.5) return const _Level('Професійний', 0xFF9C27B0);
  if (rating >= 3.5) return const _Level('Високий', 0xFFFF9800);
  if (rating >= 2.5) return const _Level('Середній', 0xFF2196F3);
  if (rating >= 1.5) return const _Level('Початковий', 0xFF4CAF50);
  return const _Level('Новачок', 0xFF9E9E9E);
}

String _humanPosition(String raw) {
  switch (raw) {
    case 'goalkeeper': return 'Воротар';
    case 'defender':   return 'Захисник';
    case 'midfielder': return 'Півзахисник';
    case 'forward':    return 'Нападник';
    default:           return raw.isEmpty ? 'Невідомо' : raw;
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
