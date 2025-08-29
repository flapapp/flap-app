import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import '../services/match_service.dart';

class MatchManagementScreen extends StatefulWidget {
  final Match match;
  
  const MatchManagementScreen({Key? key, required this.match}) : super(key: key);
  
  @override
  _MatchManagementScreenState createState() => _MatchManagementScreenState();
}

class _MatchManagementScreenState extends State<MatchManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final MatchService _matchService = MatchService();
  
  // Змінні для управління
  List<String> _pendingApplications = [];
  List<String> _participants = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMatchData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);
    
    try {
      // Отримуємо актуальні дані матчу
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id)
          .get();
      
      if (matchDoc.exists) {
        final updatedMatch = Match.fromFirestore(matchDoc);
        setState(() {
          _pendingApplications = updatedMatch.pendingApplications;
          _participants = updatedMatch.participants;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завантаження: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Text(
          'Управління матчем',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF1a1a1a),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Color(0xFF4caf50),
          tabs: [
            Tab(text: 'Заявки'),
            Tab(text: 'Команди'),
            Tab(text: 'Налаштування'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationsTab(),
          _buildTeamsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }
  
  // Вкладка заявок
  Widget _buildApplicationsTab() {
    return _isLoading 
      ? Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)))
      : RefreshIndicator(
          onRefresh: _loadMatchData,
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _pendingApplications.length,
            itemBuilder: (context, index) {
              final userId = _pendingApplications[index];
              return _buildApplicationCard(userId);
            },
          ),
        );
  }
  
  // Вкладка команд
  Widget _buildTeamsTab() {
    return Center(
      child: Text(
        'Управління командами буде додано пізніше',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
  
  // Вкладка налаштувань
  Widget _buildSettingsTab() {
    return Center(
      child: Text(
        'Налаштування матчу будуть додано пізніше',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
  
  // Картка заявки
  Widget _buildApplicationCard(String userId) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF4caf50),
                child: Text(
                  userId.substring(0, 2).toUpperCase(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Гравець ID: $userId',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Очікує відповіді',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptApplication(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4caf50),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Прийняти',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _rejectApplication(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Відхилити',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Прийняття заявки
  Future<void> _acceptApplication(String userId) async {
    try {
      final success = await _matchService.acceptApplication(widget.match.id, userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Гравця прийнято!'),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        _loadMatchData(); // Оновлюємо дані
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не вдалося прийняти гравця'),
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
  
  // Відхилення заявки
  Future<void> _rejectApplication(String userId) async {
    try {
      final success = await _matchService.rejectApplication(widget.match.id, userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Заявку відхилено'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadMatchData(); // Оновлюємо дані
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не вдалося відхилити заявку'),
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
}