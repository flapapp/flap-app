import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import 'create_match_screen.dart';
import 'match_details_screen.dart';
import 'video_main_screen.dart';
import '../services/match_service.dart';
import '../services/test_data.dart';
import 'ratings_screen.dart';
import '../widgets/rating_display.dart';
import '../services/rating_service.dart';
import 'match_management_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';



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

    @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabTitles.length,
      vsync: this,
    );
    
    // Створити тестові дані після авторизації
    _createTestData();
  }

  @override
void dispose() {
  _searchDebounce?.cancel();
  _tabController.dispose();
  super.dispose();
}
    // Метод для створення тестових даних
  Future<void> _createTestData() async {
    try {
      await TestDataService.createTestMatches();
    } catch (e) {
      print('❌ Помилка створення тестових даних: $e');
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
        // Ряд 1: Місто та Рівень
        Row(
          children: [
            Expanded(
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
            ),
            SizedBox(width: 16),
            Expanded(
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
            ),
          ],
        ),
        SizedBox(height: 16),
        // Ряд 2: Час та Пошук
        Row(
          children: [
            Expanded(
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
            ),
            SizedBox(width: 16),
            Expanded(
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
            ),
          ],
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
        ),
        
        // Кнопка для створення тестових матчів
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              print('DEBUG: Створення тестових матчів...');
              await _createTestData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Тестові матчі створені!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.sports_soccer, color: Colors.white),
            label: Text(
              'Створити тестові матчі',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4caf50),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
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
      // Монети з покращеним дизайном
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 18),
            SizedBox(width: 6),
            Text(
              '127',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: 12),
      // Кнопка створення матчу з градієнтом
      Container(
        width: 40,
        height: 40,
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
          icon: Icon(Icons.add, color: Colors.white, size: 20),
          onPressed: () => Navigator.pushNamed(context, '/create-match'),
          padding: EdgeInsets.zero,
        ),
      ),
      SizedBox(width: 12),
      // Аватар користувача з градієнтом
      Container(
        width: 40,
        height: 40,
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
        child: IconButton(
          icon: Icon(Icons.person, color: Colors.white, size: 20),
          onPressed: () {
            // TODO: Додати функціонал профілю
          },
          padding: EdgeInsets.zero,
        ),
      ),
      SizedBox(width: 12),
      // Рейтинг з покращеним дизайном
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
            SizedBox(width: 4),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final rating = snapshot.hasData && snapshot.data!.exists
                    ? (snapshot.data!.data()!['rating'] ?? 3.0).toDouble()
                    : 3.0;
                return Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
        tabs: _tabTitles.map((title) => Tab(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
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
      floatingActionButton: Container(
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
    );
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

  // ВКЛАДКА 4: Рейтинги
  Widget _buildRatingsTab() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: RatingsScreen(),
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
          final avg = (snap.hasData ? snap.data! : 0.0).toStringAsFixed(1);
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
                child: CircleAvatar(
  radius: 12,
  backgroundColor: Colors.transparent,
  child: CircleAvatar(
    radius: 11,
    backgroundColor: Color(0xFF4caf50),
    child: Text(
      id.length >= 2 ? id.substring(0, 2).toUpperCase() : '?',
      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  ),
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
                      Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                      SizedBox(width: 4),
                      Text(
                        role,
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
                  if (match.pendingApplications.isNotEmpty) ...[
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
              final label = id.isNotEmpty ? id.substring(0, 2).toUpperCase() : '?';
              return Container(
                margin: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
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
            content: Text('Не вдалося подати заявку. Спробуйте ще раз.'),
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
                      'Ваш рейтинг: ${rating.toStringAsFixed(1)}',
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
} 
