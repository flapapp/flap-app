import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/auth_sign_out_helper.dart';
import 'package:flap_app/models/badge.dart' as app_badge;
import 'package:flap_app/features/badges/domain/repositories/badge_repository.dart';
import 'package:flap_app/features/friends/data/friends_service.dart';
import 'package:flap_app/features/badges/presentation/screens/badges_store_screen.dart';
import 'package:flap_app/features/friends/presentation/screens/friends_screen.dart';
import 'profile_screen_sparkline.dart';
import 'package:flap_app/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:flap_app/features/videos/presentation/screens/video_player_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flap_app/utils/i18n.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final FriendsService _friendsService = FriendsService();
  
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  List<app_badge.Badge> _userBadges = [];
  int _friendsCount = 0;
  List<Map<String, dynamic>> _ratingHistory7 = [];
  List<Map<String, dynamic>> _ratingHistory30 = [];
  List<Map<String, dynamic>> _topVideos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final uid = AppAuthContext.userId;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserBadges());
      _loadFriendsCount();
      _loadRatingDynamics(uid);
      _loadTopVideos(uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserBadges();
    }
  }

  Future<void> _loadUserBadges() async {
    final uid = AppAuthContext.userId;
    if (uid == null || !mounted) return;
    final badges = await context.read<BadgeRepository>().getUserBadgeObjects(uid);
    if (!mounted) return;
    setState(() {
      _userBadges = badges;
    });
  }

  void _loadFriendsCount() async {
    final uid = AppAuthContext.userId;
    if (uid != null) {
      final friends = await _friendsService.getUserFriends(uid);
      setState(() {
        _friendsCount = friends.length;
      });
    }
  }

  Future<void> _loadRatingDynamics(String uid) async {
    try {
      // Завантажуємо останні записи історії рейтингу з окремої колекції
      final snap = await FirebaseFirestore.instance
          .collection('rating_history')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      final all = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      final now = DateTime.now();

      List<Map<String, dynamic>> filterByDays(int days) {
        final from = now.subtract(Duration(days: days));
        final filtered = all.where((h) {
          final ts = h['timestamp'];
          final dt = ts is Timestamp ? ts.toDate() : null;
          return dt != null && dt.isAfter(from);
        }).toList();
        // Сортуємо за часом зростаюче, щоб лінія йшла зліва направо
        filtered.sort((a, b) {
          final at = a['timestamp'];
          final bt = b['timestamp'];
          if (at is Timestamp && bt is Timestamp) return at.compareTo(bt);
          return 0;
        });
        return filtered;
      }

      _ratingHistory7 = filterByDays(7);
      _ratingHistory30 = filterByDays(30);

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadTopVideos(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: uid)
          .limit(50)
          .get();
      final vids = snap.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        m['id'] = d.id;
        return m;
      }).toList();
      vids.sort((a, b) {
        final av = (a['views'] ?? 0) as int;
        final bv = (b['views'] ?? 0) as int;
        return bv.compareTo(av);
      });
      _topVideos = vids.take(5).toList();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4caf50)),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text(
                  'Профіль не знайдено',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final userData = snapshot.data!.data()!;
          return _buildProfileContent(userData);
        },
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> userData) {
    final displayName = userData['displayName'] ?? userData['name'] ?? userData['authorName'] ?? userData['email']?.toString().split('@').first ?? 'Гравець';
    final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? userData['photoUrl'] ?? '';
    final rating = (userData['rating'] ?? 0.0).toDouble();
    final coins = userData['coins'] ?? 0;
    
    return CustomScrollView(
      slivers: [
        // App bar with gradient
        SliverAppBar(
          expandedHeight: 300,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF0f0f23),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f0f23),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: _buildProfileHeader(userData, displayName, avatarUrl, rating, coins),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: _showSettings,
            ),
          ],
        ),
        
        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatsCards(userData),
                _buildBadgesSection(),
                _buildRatingDynamicsSection(),
                _buildTopVideosSection(),
                _buildActionsMenu(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, String displayName, 
                           String? avatarUrl, double rating, int coins) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with glow effect
          Stack(
                children: [
                  Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4caf50).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildAvatarPlaceholder(displayName),
                        )
                      : _buildAvatarPlaceholder(displayName),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
                        
          // Name
                        Text(
                          displayName,
                          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
                            fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          
          // Rating and coins row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getRatingColor(rating).withOpacity(0.2),
                      _getRatingColor(rating).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getRatingColor(rating), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      color: _getRatingColor(rating),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                        Text(
                      rating.toStringAsFixed(2),
                          style: TextStyle(
                        color: _getRatingColor(rating),
                            fontSize: 14,
                        fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(width: 12),

              // Coins
                  Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFFA500),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      coins.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                            fontWeight: FontWeight.bold,
                      ),
                    ),
                      ],
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 12),
          
          // Position and city
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getPositionDisplay(userData['position']),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              if (userData['city'] != null) ...[
              Text(
                  ' • ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '📍 ${userData['city']}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> userData) {
    final int matchesCount = ((userData['totalMatches'] ?? userData['matches'] ?? userData['matchesPlayed'] ?? 0) as num).toInt();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
  'Матчі',
  matchesCount.toString(),
  Icons.sports_soccer,
  const Color(0xFF4caf50),
),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Відео',
              (userData['videosUploaded'] ?? 0).toString(),
              Icons.videocam,
              const Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Друзі',
              _friendsCount.toString(),
              Icons.people,
              const Color(0xFF2196F3),
              onTap: () => _openFriends(),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Бейджі',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _openBadgesStore,
                child: const Text(
                  'Магазин',
                  style: TextStyle(color: Color(0xFF4caf50)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_userBadges.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Поки немає бейджів',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _userBadges.length,
                itemBuilder: (context, index) {
                  final badge = _userBadges[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(badge.categoryColor).withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          badge.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.localizedName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingDynamicsSection() {
    if (_ratingHistory7.isEmpty && _ratingHistory30.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: const Text('Поки що немає історії змін рейтингу', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Динаміка рейтингу', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildSparklineCard('Останні 7 днів', _ratingHistory7),
          const SizedBox(height: 8),
          _buildSparklineCard('Останні 30 днів', _ratingHistory30),
        ],
      ),
    );
  }

  Widget _buildSparklineCard(String title, List<Map<String, dynamic>> history) {
    // Малюємо по значенню newRating з історії
    final points = history.map<double>((h) => ((h['newRating'] ?? 0.0) as num).toDouble()).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              if (points.isNotEmpty)
                Text(points.last.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: CustomPaint(
              painter: SparklinePainter(points),
              size: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopVideosSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(I18n.t('top_videos_by_views'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_topVideos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Text('Поки що немає відео', style: TextStyle(color: Colors.white70)),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _topVideos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final v = _topVideos[index];
                  final thumb = (v['thumbnailUrl'] ?? '') as String;
                  final title = (v['title'] ?? 'Відео') as String;
                  final views = (v['views'] ?? 0).toString();
                  return SizedBox(
                    width: 160,
                    child: GestureDetector(
                      onTap: () {
                        final videoUrl = (v['videoUrl'] ?? '') as String;
                        if (videoUrl.isEmpty) return;
                        final authorNameArg = (v['authorName'] ?? 'Невідомий') as String;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              videoUrl: videoUrl,
                              title: title,
                              authorName: authorNameArg,
                              videoId: v['id'] as String,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: () {
                                final videoUrl = (v['videoUrl'] ?? '') as String;
                                if (kIsWeb) {
                                  if (thumb.isNotEmpty && thumb != videoUrl) {
                                    return Image.network(
                                      thumb,
                                      width: 160,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.low,
                                      cacheWidth: 320,
                                      errorBuilder: (_, __, ___) => _videoThumbFallback(title),
                                    );
                                  }
                                  return _videoThumbFallback(title);
                                } else {
                                  if (thumb.isNotEmpty) {
                                    return Image.network(
                                      thumb,
                                      width: 160,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.low,
                                      cacheWidth: 320,
                                      errorBuilder: (_, __, ___) => _videoThumbFallback(title),
                                    );
                                  }
                                  return _videoThumbFallback(title);
                                }
                              }(),
                            ),
                            Positioned(
                              left: 6,
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.visibility, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text(views, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _videoThumbFallback(String title) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  

  Widget _buildActionsMenu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildActionItem(
            '👥 Друзі',
            'Керування друзями',
            Icons.people,
            () => _openFriends(),
          ),
          _buildActionItem(
            '⚽ Мої матчі',
            'Перейти до моїх матчів',
            Icons.sports_soccer,
            () => Navigator.pushNamed(context, '/matches', arguments: {'initialTabIndex': 1}),
          ),
          _buildActionItem(
            '🏆 Мої відео',
            'Переглянути завантажені відео',
            Icons.videocam,
            () => _openMyVideos(),
          ),
          _buildActionItem(
            '⚔️ Мої челенджі',
            'Переглянути створені челенджі',
            Icons.emoji_events,
            () => _openMyChallenges(),
          ),
          _buildActionItem(
            '📊 Статистика',
            'Детальна статистика гравця',
            Icons.analytics,
            () => _openStats(),
          ),
          _buildActionItem(
            '👑 Підписки',
            'Керувати підпискою та планами',
            Icons.workspace_premium,
            () => _openSubscriptions(),
          ),
          _buildActionItem(
            '⚙️ Налаштування',
            'Налаштування профілю',
            Icons.settings,
            () => _showSettings(),
          ),
          _buildActionItem(
            '🚪 Вийти',
            'Вийти з акаунту',
            Icons.logout,
            () => _signOut(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDestructive 
                ? Colors.red.withOpacity(0.2)
                : const Color(0xFF4caf50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFF4caf50),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.5),
          size: 16,
        ),
        tileColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return const Color(0xFF4CAF50);
    if (rating >= 3.5) return const Color(0xFF8BC34A);
    if (rating >= 2.5) return const Color(0xFFFFC107);
    if (rating >= 1.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getPositionDisplay(String? position) {
    switch (position?.toLowerCase()) {
      case 'goalkeeper':
        return '🥅 Воротар';
      case 'defender':
        return '🛡️ Захисник';
      case 'midfielder':
        return '⚽ Півзахисник';
      case 'forward':
        return '🎯 Нападник';
      default:
        return '⚽ Гравець';
    }
  }

  void _editProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Редагування профілю (буде реалізовано)', 'Profile editing (coming soon)'))),
    );
  }

  void _openFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FriendsScreen()),
    );
  }

  void _openMyVideos() {
    Navigator.pushNamed(
      context,
      '/video-main',
      arguments: {'myContent': 'videos'},
    );
  }

  void _openMyChallenges() {
    Navigator.pushNamed(
      context,
      '/video-main',
      arguments: {'myContent': 'challenges'},
    );
  }

  void _openStats() {
    Navigator.pushNamed(context, '/stats');
  }

  void _openSubscriptions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionScreen(),
      ),
    );
  }

  void _openBadgesStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BadgesStoreScreen(),
      ),
    ).then((_) async {
      await _loadUserBadges();
    });
  }

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Налаштування (буде реалізовано)', 'Settings (coming soon)'))),
    );
  }

  void _signOut() {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Вийти з акаунту?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Ви впевнені, що хочете вийти?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Скасувати', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await signOutViaBlocAndWait(parentContext);
              if (!parentContext.mounted) return;
              Navigator.of(parentContext).pushReplacementNamed('/login');
            },
            child: const Text('Вийти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}



