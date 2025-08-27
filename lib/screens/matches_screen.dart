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

  final MatchService _matchService = MatchService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabTitles.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Метод для створення фільтрів
  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Ряд 1: Місто та Рівень
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: '🏙️ Місто',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Color(0xFF1a1a2e),
                    style: TextStyle(color: Colors.white),
                    items: _cityOptions.map((city) =>
                      DropdownMenuItem(
                        value: city,
                        child: Text(
                          city,
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCity = value ?? 'Всі міста';
                      });
                    },
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedLevel,
                    decoration: InputDecoration(
                      labelText: '📊 Рівень',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Color(0xFF1a1a2e),
                    style: TextStyle(color: Colors.white),
                    items: _levelOptions.map((level) =>
                      DropdownMenuItem(
                        value: level,
                        child: Text(
                          level,
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value ?? 'Всі рівні';
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Ряд 2: Час та Пошук
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedTime,
                    decoration: InputDecoration(
                      labelText: '⏰ Час',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Color(0xFF1a1a2e),
                    style: TextStyle(color: Colors.white),
                    items: _timeOptions.map((time) =>
                      DropdownMenuItem(
                        value: time,
                        child: Text(
                          time,
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTime = value ?? 'Будь-коли';
                      });
                    },
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '🔍 Пошук',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    style: TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ],
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
        title: Text(
          '⚽ МАТЧІ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1a1a2e),
                Color(0xFF16213e),
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          // Перемикач режимів: Матчі ↔ Відео
          IconButton(
            tooltip: 'Перейти до відео',
            icon: const Icon(Icons.video_library, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/video-main'),
          ),
          // Рейтинг у хедері
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final rating = snapshot.hasData && snapshot.data!.exists
                  ? (snapshot.data!.data()!['rating'] ?? 3.0).toDouble()
                  : 3.0;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '⭐ ${rating.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.data_usage),
            onPressed: () async {
              await TestDataService.createTestMatches();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Тестові матчі створені!'),
                  backgroundColor: Color(0xFF4caf50),
                ),
              );
            },
            tooltip: 'Створити тестові дані',
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep),
            onPressed: () async {
              await TestDataService.clearTestData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ Тестові дані видалені!'),
                  backgroundColor: Color(0xFFFF9800),
                ),
              );
            },
            tooltip: 'Видалити тестові дані',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                ],
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: _tabTitles.map((title) => Tab(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              )).toList(),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Color(0xFF4caf50),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
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

              // Список матчів
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final match = snapshot.data![index];
                  return _buildMatchCard(match);
                },
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
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final m = matches[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.check_circle, color: Color(0xFF9E9E9E)),
              title: Text(
                m.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${m.date.day}.${m.date.month}.${m.date.year} • ${m.city}',
                style: TextStyle(color: Colors.white.withOpacity(0.75)),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9E9E9E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9E9E9E).withOpacity(0.3)),
                ),
                child: const Text('Завершено', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              onTap: () => Navigator.pushNamed(context, '/match-details', arguments: m),
            );
          },
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
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок та статус
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getLevelText(match.level)} рівень',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          _formatDateTime(match.date),
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.location_on, size: 16, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          match.city,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(match.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(match.status).withOpacity(0.3)),
                ),
                child: Text(
                  _getStatusText(match.status),
                  style: TextStyle(
                    color: _getStatusColor(match.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Інформація про гравців
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.white70),
                    SizedBox(width: 8),
                    Text(
                      '${match.currentPlayers}/${match.maxPlayers}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 12),
                    // Середній рейтинг учасників
                    if (match.participants.isNotEmpty)
                      FutureBuilder<double>(
                        future: _calculateAverageRating(match.participants),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Row(
                              children: [
                                const Text('⭐', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  snapshot.data!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sports_soccer, size: 16, color: Colors.white70),
                    SizedBox(width: 8),
                    Text(
                      '${match.maxPlayers - match.currentPlayers} місць',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
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

          SizedBox(height: 20),

          // Кнопки дій
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Builder(
                    builder: (context) {
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      final bool canJoin =
                          match.status == MatchStatus.open &&
                          currentUserId != null &&
                          !match.participants.contains(currentUserId) &&
                          match.currentPlayers < match.maxPlayers;
                      return ElevatedButton(
                        onPressed: canJoin ? () { _joinMatch(match.id); } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          disabledForegroundColor: Colors.white70,
                          disabledBackgroundColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Приєднатися',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/match-details', arguments: match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Деталі',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
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

  Stream<List<Match>> _getFilteredMatches() {
    return _matchService.getAvailableMatches().map((matches) {
      return matches.where((match) {
        // Фільтр по місту
        if (_selectedCity != 'Всі міста' && match.city != _selectedCity) {
          return false;
        }

        // Фільтр по рівню
        if (_selectedLevel != 'Всі рівні' && _getLevelText(match.level) != _selectedLevel) {
          return false;
        }

        // Фільтр по часу
        if (_selectedTime != 'Будь-коли') {
          DateTime now = DateTime.now();
          DateTime matchDate = match.date;

          switch (_selectedTime) {
            case 'Сьогодні':
              if (!_isSameDay(matchDate, now)) return false;
              break;
            case 'Завтра':
              DateTime tomorrow = now.add(Duration(days: 1));
              if (!_isSameDay(matchDate, tomorrow)) return false;
              break;
            case 'Цього тижня':
              DateTime weekEnd = now.add(Duration(days: 7));
              if (matchDate.isBefore(now) || matchDate.isAfter(weekEnd)) return false;
              break;
            case 'Цього місяця':
              DateTime monthEnd = now.add(Duration(days: 30));
              if (matchDate.isBefore(now) || matchDate.isAfter(monthEnd)) return false;
              break;
          }
        }

        // Фільтр по пошуку
        if (_searchQuery.isNotEmpty) {
          String query = _searchQuery.toLowerCase();
          return match.title.toLowerCase().contains(query) ||
                 match.description.toLowerCase().contains(query) ||
                 match.location.toLowerCase().contains(query) ||
                 match.city.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
  }

  Future<void> _joinMatch(String matchId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Потрібно увійти в систему'), backgroundColor: Colors.red),
        );
        return;
      }

      final success = await _matchService.joinMatch(matchId, currentUser.uid);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ви успішно приєдналися до матчу!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не вдалося приєднатися до матчу'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
      );
    }
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
        return Color(0xFF4caf50); // Зелений - матч відкритий для участі
      case MatchStatus.full:
        return Color(0xFFFF9800); // Помаранчевий - матч заповнений
      case MatchStatus.inProgress:
        return Color(0xFF2196F3); // Синій - матч в процесі
      case MatchStatus.finished:
        return Color(0xFF9E9E9E); // Сірий - матч завершено
      case MatchStatus.cancelled:
        return Color(0xFFF44336); // Червоний - матч скасовано
    }
  }

  // Метод для отримання тексту статусу
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
        // Заголовок та статус
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
              child: Text(
                _getStatusText(match.status),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
            if (isOrganizer)
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Управління матчем буде додано пізніше')),
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
            if (isOrganizer) SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/match-details', arguments: match),
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
      ],
    ),
  );
}
}