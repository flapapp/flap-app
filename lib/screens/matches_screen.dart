import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import 'create_match_screen.dart';
import 'match_details_screen.dart';
import 'video_main_screen.dart';

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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Ряд 1: Місто та Рівень
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'Місто',
                    border: OutlineInputBorder(),
                  ),
                  items: _cityOptions.map((city) => 
                    DropdownMenuItem(value: city, child: Text(city))
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
                    labelText: 'Рівень',
                    border: OutlineInputBorder(),
                  ),
                  items: _levelOptions.map((level) => 
                    DropdownMenuItem(value: level, child: Text(level))
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
                    labelText: 'Час',
                    border: OutlineInputBorder(),
                  ),
                  items: _timeOptions.map((time) => 
                    DropdownMenuItem(value: time, child: Text(time))
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
                    labelText: 'Пошук',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
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
      appBar: AppBar(
        title: Text('Матчі'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController, // Використовуємо змінну класу
          tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController, // Використовуємо ту ж змінну
        children: [
          // Вкладка "Знайти матч"
          Column(
            children: [
              _buildFilters(),
              Expanded(
                child: Center(child: Text('Список матчів буде тут')),
              ),
            ],
          ),
          // Вкладка "Мої матчі" 
          Center(child: Text('Мої матчі')),
          // Вкладка "Історія"
          Center(child: Text('Історія')),
          // Вкладка "Рейтинги"
          Center(child: Text('Рейтинги')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Перехід на екран створення матчу
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Створити матч - буде реалізовано')),
          );
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        tooltip: 'Створити матч',
      ),
    );
  }
}