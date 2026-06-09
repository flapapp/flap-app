import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../router/app_router.dart';
import '../../domain/repositories/ratings_repository.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/city_localization.dart';

@RoutePage()
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen>
    with TickerProviderStateMixin {
  RatingsRepository get _ratingRepo => sl<RatingsRepository>();

  late TabController _tabController;

  final List<String> _tabTitles = [
    tr('overall_rating'),
    tr('by_city'),
    tr('by_position'),
    tr('my_stats'),
  ];

  // Filters
  String _selectedCity = tr('all_cities');
  String _selectedPosition = tr('il_0e333190c1');

  List<String> get _cityOptions => [
    tr('all_cities'),
    tr('kyiv'),
    tr('kharkiv'),
    tr('odesa'),
    tr('dnipro'),
    tr('lviv'),
    tr('il_d13f986228'),
  ];

  List<String> get _positionOptions => [
    tr('il_0e333190c1'),
    tr('il_f2d20c7ee1'),
    tr('il_157ddc59b5'),
    tr('il_d332e47845'),
    tr('il_f1c65e1481'),
  ];

  // Data
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
    _tabController = TabController(length: _tabTitles.length, vsync: this);

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
      byId[id] = p; // keep last instance
    }
    return byId.values.toList();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load top players
      _topPlayers = await _ratingRepo.getTopPlayers(limit: 50);
      _topPlayers = _dedupeById(_topPlayers);

      // Load players by city
      if (_selectedCity != tr('all_cities')) {
        _cityPlayers = await _ratingRepo.getTopPlayers(
          limit: 50,
          city: _selectedCity,
        );
        _cityPlayers = _dedupeById(_cityPlayers);
      }

      // Load players by position
      if (_selectedPosition != tr('il_0e333190c1')) {
        _positionPlayers = await _ratingRepo.getTopPlayers(
          limit: 50,
          position: _selectedPosition,
        );
        _positionPlayers = _dedupeById(_positionPlayers);
      }

      // Load my stats
      await _loadMyStats();
    } catch (e) {
      print('Error loading ratings data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e4fdc41fe4', namedArgs: {'e': e.toString()})),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMyStats() async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      setState(() => _myStats = {});
      return;
    }
    try {
      final stats = await _ratingRepo.getUserRatingStats(currentUser.id);
      setState(() => _myStats = stats);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_4cb10b7873', namedArgs: {'e': e.toString()})),
        ),
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
            // Flap logo
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
                  tr('ratings'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  tr('il_bc93181f0a'),
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
            tooltip: tr('ratings_refresh_tooltip'),
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
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
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

  // Overall rating
  Widget _buildOverallRatingsTab() {
    if (_isLoading) {
      return const FlapLoadingList(
        itemCount: 6,
        itemHeight: 76,
        radius: 16,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _topPlayers.length,
      itemBuilder: (context, index) {
        final player = _topPlayers[index];
        final rating = player['rating'] as double;
        final level = _ratingRepo.getPlayerLevel(rating);
        final levelColor = Color(_ratingRepo.getPlayerLevelColor(rating));

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
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: levelColor.withOpacity(0.2),
                  backgroundImage:
                      (player['avatarUrl'] ?? '').toString().isNotEmpty
                      ? NetworkImage(player['avatarUrl'])
                      : null,
                  child: (player['avatarUrl'] ?? '').toString().isEmpty
                      ? Text(
                          (player['name'] ?? 'U').toString().isNotEmpty
                              ? (player['name'] as String)[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: levelColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    player['name'] ?? tr('unknown'),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                  '${player['position'] ?? tr('unknown')} • ${localizeCity((player['city'] ?? '').toString())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    'ratings_matches_played_line',
                    namedArgs: {'count': '${player['totalMatches'] ?? 0}'},
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE7C25A)),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            onTap: () {
              context.router.push(
                PlayerProfileRoute(
                  playerId: player['id'],
                  playerName: player['name'] ?? tr('unknown'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Rating by city
  Widget _buildCityRatingsTab() {
    return Column(
      children: [
        // City filter
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('ratings_pick_city_heading'),
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
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFFFFD700)),
                  ),
                ),
                dropdownColor: const Color(0xFF1a1a2e),
                style: const TextStyle(color: Colors.white),
                items: _cityOptions.map((city) {
                  return DropdownMenuItem(value: city, child: Text(city));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value ?? tr('all_cities');
                  });
                  if (value != null && value != tr('all_cities')) {
                    _loadCityPlayers(value);
                  }
                },
              ),
            ],
          ),
        ),

        // Player list
        Expanded(
          child: _selectedCity == tr('all_cities')
              ? Center(
                  child: Text(
                    tr('ratings_pick_city_hint'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                )
              : _isCityLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF4caf50)),
                      SizedBox(height: 16),
                      Text(
                        tr('ratings_loading_players'),
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

  // Rating by position
  Widget _buildPositionRatingsTab() {
    return Column(
      children: [
        // Position filter
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('ratings_pick_position_heading'),
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
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
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
                    _selectedPosition = value ?? tr('il_0e333190c1');
                  });
                  if (value != null && value != tr('il_0e333190c1')) {
                    _loadPositionPlayers(value);
                  }
                },
              ),
            ],
          ),
        ),

        // Player list
        // Player list
        Expanded(
          child: _selectedPosition == tr('il_0e333190c1')
              ? Center(
                  child: Text(
                    tr('ratings_pick_position_hint'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                )
              : _isPositionLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF4caf50)),
                      SizedBox(height: 16),
                      Text(
                        tr('ratings_loading_players'),
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

  // My statistics
  Widget _buildMyStatsTab() {
    if (_myStats.isEmpty) {
      return const FlapLoadingList(
        itemCount: 5,
        itemHeight: 90,
        radius: 16,
      );
    }

    final currentRating = (_myStats['currentRating'] ?? 3.0).toDouble();
    final matchRating = (_myStats['matchRating'] ?? 3.0).toDouble();
    final videoRating = (_myStats['videoRating'] ?? 3.0).toDouble();
    final totalMatches = (_myStats['totalMatches'] ?? 0) as int;
    final totalVideos = (_myStats['totalVideos'] ?? 0) as int;

    final level = _ratingRepo.getPlayerLevel(currentRating);
    final levelColor = Color(_ratingRepo.getPlayerLevelColor(currentRating));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          // Primary rating
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
              border: Border.all(color: levelColor.withOpacity(0.3), width: 2),
            ),
            child: Column(
              children: [
                Text(
                  tr('my_rating'),
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
                    const Icon(Icons.star_rounded, size: 48, color: Color(0xFFE7C25A)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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

          // Detailed stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  tr('matches'),
                  '${matchRating.toStringAsFixed(2)}',
                  tr('rating_weight_match_percent'),
                  Icons.sports_soccer,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  tr('videos'),
                  '${videoRating.toStringAsFixed(2)}',
                  tr('rating_weight_video_percent'),
                  Icons.videocam,
                  const Color(0xFFFF9800),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Match and video counts
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  tr('ratings_stat_matches_played'),
                  '$totalMatches',
                  tr('ratings_stat_total'),
                  Icons.emoji_events,
                  const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  tr('ratings_stat_videos_uploaded'),
                  '$totalVideos',
                  tr('ratings_stat_total'),
                  Icons.video_library,
                  const Color(0xFF9C27B0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress chart (placeholder)
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
                  tr('ratings_progress_heading'),
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
                        tr('ratings_chart_placeholder'),
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

  // Stat card
  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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

  // Player list
  Widget _buildPlayersList(List<Map<String, dynamic>> players) {
    if (players.isEmpty) {
      return Center(
        child: Text(
          tr('ratings_no_players_found'),
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final rating = player['rating'] as double;
        final level = _ratingRepo.getPlayerLevel(rating);
        final levelColor = Color(_ratingRepo.getPlayerLevelColor(rating));

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
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: levelColor.withOpacity(0.2),
                  backgroundImage:
                      (player['avatarUrl'] ?? '').toString().isNotEmpty
                      ? NetworkImage(player['avatarUrl'])
                      : null,
                  child: (player['avatarUrl'] ?? '').toString().isEmpty
                      ? Text(
                          (player['name'] ?? 'U').toString().isNotEmpty
                              ? (player['name'] as String)[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: levelColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    player['name'] ?? tr('unknown'),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
              '${player['position'] ?? tr('unknown')} • ${localizeCity((player['city'] ?? '').toString())}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE7C25A)),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            onTap: () {
              context.router.push(
                PlayerProfileRoute(
                  playerId: player['id'],
                  playerName: player['name'] ?? tr('unknown'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Loading players by city
  Future<void> _loadCityPlayers(String city) async {
    setState(() {
      _isCityLoading = true;
    });

    try {
      print('[ratings] Loading players for city: $city');
      final players = await _ratingRepo.getTopPlayers(limit: 50, city: city);
      print('[ratings] Loaded ${players.length} players for city: $city');

      setState(() {
        _cityPlayers = _dedupeById(players);
        _isCityLoading = false;
      });
    } catch (e) {
      print('[ratings] ERROR loading city players: $e');
      setState(() {
        _isCityLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_c487fc4cab', namedArgs: {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Loading players by position
  Future<void> _loadPositionPlayers(String position) async {
    setState(() {
      _isPositionLoading = true;
    });

    try {
      print('[ratings] Loading players for position: $position');
      final players = await _ratingRepo.getTopPlayers(
        limit: 50,
        position: position,
      );
      print('[ratings] Loaded ${players.length} players for position: $position');

      setState(() {
        _positionPlayers = _dedupeById(players);
        _isPositionLoading = false;
      });
    } catch (e) {
      print('[ratings] ERROR loading position players: $e');
      setState(() {
        _isPositionLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_c487fc4cab', namedArgs: {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
