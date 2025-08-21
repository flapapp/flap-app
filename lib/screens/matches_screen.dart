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
                  content: Text('��️ Тестові дані видалені!'),
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
            // TODO: Перехід на екран створення матчу
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Створити матч - буде реалізовано'),
                backgroundColor: Color(0xFF4caf50),
              ),
            );
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
                    // Список доступних матчів
          StreamBuilder<List<Match>>(
            stream: _matchService.getAvailableMatches(),
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
            'Мої матчі',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Тут будуть ваші матчі та команди',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ВКЛАДКА 3: Історія
  Widget _buildHistoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.white54,
          ),
          SizedBox(height: 16),
          Text(
            'Історія матчів',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Тут буде історія завершених матчів',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ВКЛАДКА 4: Рейтинги
  Widget _buildRatingsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard,
            size: 64,
            color: Colors.white54,
          ),
          SizedBox(height: 16),
          Text(
            'Рейтинги',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Тут будуть рейтинги топ гравців та команд',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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
                        '${match.level.toString().split('.').last} рівень',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today, 
                            size: 16, 
                            color: Colors.white70
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatDateTime(match.date),
                            style: TextStyle(
                              color: Colors.white70, 
                              fontSize: 14
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(
                            Icons.location_on, 
                            size: 16, 
                            color: Colors.white70
                          ),
                          SizedBox(width: 8),
                          Text(
                            match.city,
                            style: TextStyle(
                              color: Colors.white70, 
                              fontSize: 14
                            ),
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
                    border: Border.all(
                      color: _getStatusColor(match.status).withOpacity(0.3),
                    ),
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
                      Icon(
                        Icons.people, 
                        size: 16, 
                        color: Colors.white70
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${match.participants.length}/${match.maxPlayers}',
                        style: TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.w600
                        ),
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
                      Icon(
                        Icons.sports_soccer, 
                        size: 16, 
                        color: Colors.white70
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${match.maxPlayers - match.participants.length} місць',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
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
                        colors: [
                          Color(0xFF4caf50),
                          Color(0xFF66bb6a),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Приєднатися до матчу
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Приєднатися до матчу - буде реалізовано'),
                            backgroundColor: Color(0xFF4caf50),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add, 
                            color: Colors.white, 
                            size: 18
                          ),
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
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Перехід на деталі матчу
                      Navigator.pushNamed(context, '/match-details', arguments: match);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline, 
                          color: Colors.white70, 
                          size: 18
                        ),
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
        return 'Відкрито'; // Матч відкритий для участі
      case MatchStatus.full:
        return 'Заповнено'; // Матч заповнений гравцями
      case MatchStatus.inProgress:
        return 'В процесі'; // Матч зараз грається
      case MatchStatus.finished:
        return 'Завершено'; // Матч закінчено
      case MatchStatus.cancelled:
        return 'Скасовано'; // Матч скасовано
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
}