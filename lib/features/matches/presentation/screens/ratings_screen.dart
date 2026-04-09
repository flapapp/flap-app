import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flap_app/features/matches/data/rating_service.dart';
import 'package:flap_app/features/profile/presentation/screens/player_profile_screen.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
class RatingsScreen extends StatefulWidget {
  @override
  _RatingsScreenState createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen>
    with TickerProviderStateMixin {
  final RatingService _ratingService = RatingService();
  
  late TabController _tabController;
  int _currentTabIndex = 0;
  
  final List<String> _tabTitles = [
    I18n.t('overall_rating'),
    I18n.t('by_city'),
    I18n.t('by_position'),
    I18n.t('my_stats'),
  ];
  
  // Фільтри
  String _selectedCity = I18n.t('all_cities');
  String _selectedPosition = I18n.inline('Всі позиції', 'All positions');
  
  List<String> get _cityOptions => [
    I18n.t('all_cities'),
    I18n.t('kyiv'),
    I18n.t('kharkiv'),
    I18n.t('odesa'),
    I18n.t('dnipro'),
    I18n.t('lviv'),
    I18n.inline('Запоріжжя', 'Zaporizhzhia'),
  ];
  
  List<String> get _positionOptions => [
    I18n.inline('Всі позиції', 'All positions'),
    I18n.inline('Воротар', 'Goalkeeper'),
    I18n.inline('Захисник', 'Defender'),
    I18n.inline('Півзахисник', 'Midfielder'),
    I18n.inline('Нападник', 'Forward'),
  ];
  
  // Дані
  List<Map<String, dynamic>> _topPlayers = [];
  List<Map<String, dynamic>> _cityPlayers = [];
  List<Map<String, dynamic>> _positionPlayers = [];
  Map<String, dynamic> _myStats = {};
  
  bool _isLoading = false;
  bool _isCityLoading = false;
  bool _isPositionLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabTitles.length,
      vsync: this,
    );
    
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _dedupeById(List<Map<String, dynamic>> players) {
  final Map<String, Map<String, dynamic>> byId = {};
  for (final p in players) {
    final id = (p['id'] ?? '').toString();
    if (id.isEmpty) continue;
    byId[id] = p; // залишаємо останній екземпляр
  }
  return byId.values.toList();
}
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Завантажуємо топ гравців
_topPlayers = await _ratingService.getTopPlayers(limit: 50);
_topPlayers = _dedupeById(_topPlayers);

// Завантажуємо гравців за містом
if (_selectedCity != I18n.t('all_cities')) {
  _cityPlayers = await _ratingService.getTopPlayers(
    limit: 50,
    city: _selectedCity,
  );
  _cityPlayers = _dedupeById(_cityPlayers);
}
      
      // Завантажуємо гравців за позицією
if (_selectedPosition != I18n.inline('Всі позиції', 'All positions')) {
  _positionPlayers = await _ratingService.getTopPlayers(
    limit: 50,
    position: _selectedPosition,
  );
  _positionPlayers = _dedupeById(_positionPlayers);
}
      
      // Завантажуємо мою статистику
      await _loadMyStats();
      
    } catch (e) {
      print('Error loading ratings data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка завантаження даних: $e', 'Error loading data: $e'))),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadMyStats() async {
  final currentUser = AppAuthContext.currentUser;
  if (currentUser == null) {
    setState(() => _myStats = {});
    return;
  }
  try {
    final stats = await _ratingService.getUserRatingStats(currentUser.id);
    setState(() => _myStats = stats);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Помилка завантаження статистики: $e', 'Error loading statistics: $e'))),
    );
  }
}
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23).withOpacity(0.95),
        elevation: 0,
        title: Row(
          children: [
            // Логотип FLAP
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'F',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t('ratings'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  )),
                Text(
                  I18n.inline('Топ гравців FLAP', 'FLAP Top Players'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Оновити',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
              onTap: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
              },
              tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
            ),
          ),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverallRatingsTab(),
                _buildCityRatingsTab(),
                _buildPositionRatingsTab(),
                _buildMyStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Загальний рейтинг
  Widget _buildOverallRatingsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _topPlayers.length,
      itemBuilder: (context, index) {
        final player = _topPlayers[index];
        final rating = player['rating'] as double;
        final level = _ratingService.getPlayerLevel(rating);
        final levelColor = Color(_ratingService.getPlayerLevelColor(rating));
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: levelColor.withOpacity(0.2),
                  backgroundImage: (player['avatarUrl'] ?? '').toString().isNotEmpty
                      ? NetworkImage(player['avatarUrl'])
                      : null,
                  child: (player['avatarUrl'] ?? '').toString().isEmpty
                      ? Text(
                          (player['name'] ?? 'U').toString().isNotEmpty ? (player['name'] as String)[0].toUpperCase() : 'U',
                          style: TextStyle(color: levelColor, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    player['name'] ?? 'Невідомий',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: levelColor, width: 1),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${player['position'] ?? 'Невідомо'} • ${player['city'] ?? 'Невідомо'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${player['totalMatches'] ?? 0} матчів зіграно',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⭐', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(2), style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerProfileScreen(
                    playerId: player['id'],
                    playerName: player['name'] ?? 'Невідомий',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  // Рейтинг за містом
  Widget _buildCityRatingsTab() {
    return Column(
      children: [
        // Фільтр міста
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🏙️ Оберіть місто',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFFFFD700)),
                  ),
                ),
                dropdownColor: const Color(0xFF1a1a2e),
                style: const TextStyle(color: Colors.white),
                items: _cityOptions.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value ?? I18n.t('all_cities');
                  });
                  if (value != null && value != I18n.t('all_cities')) {
                    _loadCityPlayers(value);
                  }
                },
              ),
            ],
          ),
        ),
        
        // Список гравців
        Expanded(
          child: _selectedCity == I18n.t('all_cities')
              ? Center(
                  child: Text(
                    'Оберіть місто для перегляду рейтингу',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                )
              : _isCityLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF4caf50)),
                          SizedBox(height: 16),
                          Text(
                            'Завантаження гравців...',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : _buildPlayersList(_cityPlayers),
        ),
      ],
    );
  }
  
  // Рейтинг за позицією
  Widget _buildPositionRatingsTab() {
    return Column(
      children: [
        // Фільтр позиції
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚽ Оберіть позицію',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFFFFD700)),
                  ),
                ),
                dropdownColor: const Color(0xFF1a1a2e),
                style: const TextStyle(color: Colors.white),
                items: _positionOptions.map((position) {
                  return DropdownMenuItem(
                    value: position,
                    child: Text(position),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPosition = value ?? I18n.inline('Всі позиції', 'All positions');
                  });
                  if (value != null && value != I18n.inline('Всі позиції', 'All positions')) {
                    _loadPositionPlayers(value);
                  }
                },
              ),
            ],
          ),
        ),
        
        // Список гравців
                // Список гравців
        Expanded(
          child: _selectedPosition == I18n.inline('Всі позиції', 'All positions')
              ? Center(
                  child: Text(
                    'Оберіть позицію для перегляду рейтингу',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                )
              : _isPositionLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF4caf50)),
                          SizedBox(height: 16),
                          Text(
                            'Завантаження гравців...',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : _buildPlayersList(_positionPlayers),
        ),
      ],
    );
  }
  
  // Моя статистика
  Widget _buildMyStatsTab() {
    if (_myStats.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    final currentRating = (_myStats['currentRating'] ?? 3.0).toDouble();
    final matchRating = (_myStats['matchRating'] ?? 3.0).toDouble();
    final videoRating = (_myStats['videoRating'] ?? 3.0).toDouble();
    final totalMatches = (_myStats['totalMatches'] ?? 0) as int;
    final totalVideos = (_myStats['totalVideos'] ?? 0) as int;
    
    final level = _ratingService.getPlayerLevel(currentRating);
    final levelColor = Color(_ratingService.getPlayerLevelColor(currentRating));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          // Основний рейтинг
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  levelColor.withOpacity(0.2),
                  levelColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: levelColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Ваш рейтинг',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 48)),
                    const SizedBox(width: 16),
                    Text(
                      currentRating.toStringAsFixed(2),
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: levelColor, width: 1),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Детальна статистика
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Матчі',
                  '${matchRating.toStringAsFixed(2)} ⭐',
                  '70% ваги',
                  Icons.sports_soccer,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Відео',
                  '${videoRating.toStringAsFixed(2)} ⭐',
                  '30% ваги',
                  Icons.videocam,
                  const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Кількість матчів та відео
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Зіграно матчів',
                  '$totalMatches',
                  'Загалом',
                  Icons.emoji_events,
                  const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Завантажено відео',
                  '$totalVideos',
                  'Загалом',
                  Icons.video_library,
                  const Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Графік прогресу (заглушка)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📈 Прогрес рейтингу',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 200,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Графік буде додано\nв наступному оновленні',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Картка статистики
  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Список гравців
  Widget _buildPlayersList(List<Map<String, dynamic>> players) {
    if (players.isEmpty) {
      return Center(
        child: Text(
          'Гравців не знайдено',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final rating = player['rating'] as double;
        final level = _ratingService.getPlayerLevel(rating);
        final levelColor = Color(_ratingService.getPlayerLevelColor(rating));
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: levelColor.withOpacity(0.2),
                  backgroundImage: (player['avatarUrl'] ?? '').toString().isNotEmpty
                      ? NetworkImage(player['avatarUrl'])
                      : null,
                  child: (player['avatarUrl'] ?? '').toString().isEmpty
                      ? Text(
                          (player['name'] ?? 'U').toString().isNotEmpty ? (player['name'] as String)[0].toUpperCase() : 'U',
                          style: TextStyle(color: levelColor, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    player['name'] ?? 'Невідомий',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: levelColor, width: 1),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${player['position'] ?? 'Невідомо'} • ${player['city'] ?? 'Невідомо'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⭐', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(2), style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerProfileScreen(
                    playerId: player['id'],
                    playerName: player['name'] ?? 'Невідомий',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
    // Завантаження гравців за містом
  Future<void> _loadCityPlayers(String city) async {
    setState(() {
      _isCityLoading = true;
    });
    
    try {
      print('🔍 Loading players for city: $city');
      final players = await _ratingService.getTopPlayers(
        limit: 50,
        city: city,
      );
      print('✅ Loaded ${players.length} players for city: $city');
      
      setState(() {
        _cityPlayers = _dedupeById(players);
        _isCityLoading = false;
      });
    } catch (e) {
      print('❌ Error loading city players: $e');
      setState(() {
        _isCityLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Помилка завантаження: $e', 'Error loading: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
    // Завантаження гравців за позицією
  Future<void> _loadPositionPlayers(String position) async {
    setState(() {
      _isPositionLoading = true;
    });
    
    try {
      print('🔍 Loading players for position: $position');
      final players = await _ratingService.getTopPlayers(
        limit: 50,
        position: position,
      );
      print('✅ Loaded ${players.length} players for position: $position');
      
      setState(() {
        _positionPlayers = _dedupeById(players);
        _isPositionLoading = false;
      });
    } catch (e) {
      print('❌ Error loading position players: $e');
      setState(() {
        _isPositionLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Помилка завантаження: $e', 'Error loading: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
