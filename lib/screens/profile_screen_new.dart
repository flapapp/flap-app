import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge.dart' as app_badge;
import '../services/badge_service.dart';
import 'badges_store_screen.dart';
import '../services/friends_service.dart';
import 'friends_screen.dart';
import 'subscription_screen.dart';
import '../utils/i18n.dart';
import '../models/app_team.dart';
import '../models/team_invite.dart';
import '../services/team_service.dart';
import 'team_details_screen.dart';
import 'team_create_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BadgeService _badgeService = BadgeService();
  final FriendsService _friendsService = FriendsService();
  final TeamService _teamService = TeamService();
  
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  List<app_badge.Badge> _userBadges = [];
  int _friendsCount = 0;
  Stream<List<AppTeam>>? _teamsStream;
  Stream<List<TeamInvite>>? _teamInvitesStream;
  String? _userId;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _userId = uid;
      _userStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
      _loadUserBadges();
      _loadFriendsCount();
      _teamsStream = _teamService.watchUserTeams(uid);
      _teamInvitesStream = _teamService.watchInvites(uid);
    }
  }

  void _loadUserBadges() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final badges = await _badgeService.getUserBadgeObjects(uid);
      setState(() {
        _userBadges = badges;
      });
    }
  }

  void _loadFriendsCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final friends = await _friendsService.getUserFriends(uid);
      setState(() {
        _friendsCount = friends.length;
      });
    }
  }

  Widget _buildTeamsSection() {
    if (_teamsStream == null) return const SizedBox.shrink();
    return StreamBuilder<List<AppTeam>>(
      stream: _teamsStream,
      builder: (context, snapshot) {
        final teams = snapshot.data ?? const [];
        final canCreate = teams.length < 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    I18n.inline('Мої команди', 'My teams'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: canCreate
                        ? () async {
                            if (_userId == null) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TeamCreateScreen(existingTeams: teams.length),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      I18n.inline('Створити', 'Create'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(20),
                child: LinearProgressIndicator(),
              )
            else if (teams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.inline('У вас немає команд', 'You have no teams yet'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.inline(
                            'Створіть першу команду та запросіть друзів',
                            'Create your first team and invite friends'),
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: canCreate
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeamCreateScreen(
                                      existingTeams: teams.length,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Text(I18n.inline('Створити команду', 'Create team')),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return _TeamCard(
                      team: team,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamDetailsScreen(teamId: team.id),
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: teams.length,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTeamInvitesSection() {
    if (_teamInvitesStream == null) return const SizedBox.shrink();
    return StreamBuilder<List<TeamInvite>>(
      stream: _teamInvitesStream,
      builder: (context, snapshot) {
        final invites = snapshot.data ?? const [];
        if (invites.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                I18n.inline('Запрошення до команд', 'Team invites'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...invites.map((invite) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.groups, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invite.teamName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              I18n.inline('Вас запросили до команди',
                                  'You were invited to join'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _teamService.respondToInvite(
                            invite: invite,
                            accept: false,
                          );
                        },
                        child: Text(I18n.t('cancel')),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _teamService.respondToInvite(
                              invite: invite,
                              accept: true,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(I18n.inline(
                                    'Команду додано!', 'Joined the team!')),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        child: Text(I18n.inline('Приєднатись', 'Join')),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
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
            return Center(
              child: Text(
                'Профіль не знайдено'.i18n('Profile not found'),
                style: const TextStyle(color: Colors.white),
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
    final displayName = userData['name'] ?? userData['displayName'] ?? I18n.t('player');
    final avatarUrl = userData['avatar'] ?? userData['avatarUrl'];
    final rating = (userData['rating'] ?? 0.0).toDouble();
    final coins = userData['coins'] ?? 0;
    
    return CustomScrollView(
      slivers: [
        // App bar with gradient
        SliverAppBar(
          expandedHeight: 420,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF0f0f23),
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
          child: Column(
            children: [
  _buildStatsCards(userData),
  _buildBadgesSection(userData),
  _buildTeamsSection(),
  const SizedBox(height: 20),
  _buildTeamInvitesSection(),
  _buildActionsMenu(),
  const SizedBox(height: 20),
],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, String displayName, 
                           String? avatarUrl, double rating, int coins) {
    return Padding(
  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
  child: Column(
        children: [
          // Avatar with glow effect
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
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
              // Edit button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _editProfile(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4caf50),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0f0f23), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
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
                      rating.toStringAsFixed(1),
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
          const SizedBox(height: 6),
          
          // Win rate and recent matches
          FutureBuilder<Map<String, dynamic>>(
            future: _loadMatchStats(userData['uid'] ?? _auth.currentUser?.uid ?? ''),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              
              final stats = snapshot.data!;
              final winRate = stats['winRate'] as double;
              final recentResults = stats['recentResults'] as List<String>;
              
              return Column(
                children: [
                  // Win rate
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.percent, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${I18n.inline('Win Rate:', 'Win Rate:')} ${winRate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Recent matches (W/D/L)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: recentResults.map((result) {
                      Color color;
                      if (result == 'W') {
  color = const Color(0xFF4CAF50);
} else if (result == 'D') {
  color = Colors.grey;
} else if (result == 'L') {
  color = Colors.red;
} else {
  color = Colors.grey; // плейсхолдер '-'
}
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            result,
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> userData) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              I18n.t('matches'),
              (userData['matchesPlayed'] ?? 0).toString(),
              Icons.sports_soccer,
              const Color(0xFF4caf50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              I18n.t('videos'),
              (userData['videosUploaded'] ?? 0).toString(),
              Icons.videocam,
              const Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              I18n.t('friends'),
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

  Widget _buildBadgesSection(Map<String, dynamic> userData) {
  final String userId = userData['uid'] ?? _auth.currentUser?.uid ?? '';
  return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                I18n.t('badges'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _openBadgesStore,
                child: Text(
                  'Магазин'.i18n('Store'),
                  style: const TextStyle(color: Color(0xFF4caf50)),
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
                    'Поки немає бейджів'.i18n('No badges yet'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _userBadges.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final badge = _userBadges[index];
                  return FutureBuilder<int>(
                    future: _getBadgeEndorsementCount(userId, badge.id),
                    builder: (context, endorsementSnapshot) {
                      final endorsementCount = endorsementSnapshot.data ?? 0;

                      return SizedBox(
                        width: 220,
                        child: GestureDetector(
                          onTap: () => _endorseBadge(userId, badge),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(badge.categoryColor).withOpacity(0.15),
                                    border: Border.all(
                                      color: Color(badge.categoryColor).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      badge.emoji,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ValueListenableBuilder<String>(
                                        valueListenable: I18n.language,
                                        builder: (context, _, __) => Text(
                                          badge.localizedName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Color(badge.categoryColor).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Color(badge.categoryColor).withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          badge.rarityText,
                                          style: TextStyle(
                                            color: Color(badge.categoryColor),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1F2A44),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.thumb_up, size: 14, color: Colors.blueAccent.shade100),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$endorsementCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.greenAccent.shade200,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
  }

  Widget _buildActionsMenu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildActionItem(
            '👥 Друзі'.i18n('👥 Friends'),
            I18n.t('manage_friends'),
            Icons.people,
            () => _openFriends(),
          ),
          _buildActionItem(
            '🏆 Мої відео'.i18n('🏆 My videos'),
            I18n.t('view_uploaded_videos'),
            Icons.videocam,
            () => _openMyVideos(),
          ),
          _buildActionItem(
            '⚔️ Мої челенджі'.i18n('⚔️ My challenges'),
            I18n.t('view_challenges'),
            Icons.emoji_events,
            () => _openMyChallenges(),
          ),
          _buildActionItem(
            I18n.t('statistics_title'),
            I18n.t('detailed_statistics'),
            Icons.analytics,
            () => _openStats(),
          ),
          _buildActionItem(
            I18n.t('subscriptions_title'),
            I18n.t('manage_subscription'),
            Icons.workspace_premium,
            () => _openSubscriptions(),
          ),
          _buildActionItem(
            I18n.t('settings_title'),
            I18n.t('profile_settings'),
            Icons.settings,
            () => _showSettings(),
          ),
          _buildActionItem(
            I18n.t('logout_title'),
            I18n.t('logout_from_account'),
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
        return '🥅 Воротар'.i18n('🥅 Goalkeeper');
      case 'defender':
        return '🛡️ Захисник'.i18n('🛡️ Defender');
      case 'midfielder':
        return '⚽ Півзахисник'.i18n('⚽ Midfielder');
      case 'forward':
        return '🎯 Нападник'.i18n('🎯 Forward');
      default:
        return '⚽ ${I18n.t('player')}';
    }
  }

  Future<Map<String, dynamic>> _loadMatchStats(String userId) async {
  try {
    // Базовий запит + безпечні fallback-и (щоб не впиратись у композитний індекс)
    final base = FirebaseFirestore.instance
        .collection('matches')
        .where('participants', arrayContains: userId);

    QuerySnapshot<Map<String, dynamic>> matchesSnapshot;

    try {
      matchesSnapshot = await base
          .where('status', isEqualTo: 'finished')
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();
    } catch (_) {
      try {
        matchesSnapshot = await base
            .where('status', isEqualTo: 'finished')
            .limit(20)
            .get();
      } catch (_) {
        matchesSnapshot = await base
            .limit(20)
            .get();
      }
    }

    int wins = 0;
    int draws = 0;
    int losses = 0;
    final List<String> recentResults = [];

    for (final doc in matchesSnapshot.docs) {
      final data = doc.data();

      // 1) Зчитуємо рахунок із числових полів, інакше з текстового result
      final int? score1Opt = data['teamAScore'] as int?;
      final int? score2Opt = data['teamBScore'] as int?;
      int score1 = score1Opt ?? 0;
      int score2 = score2Opt ?? 0;

      if (score1Opt == null || score2Opt == null) {
        final String resultStr = (data['result'] as String?) ?? '';
        if (resultStr == 'teamAWins') {
          score1 = 1; score2 = 0;
        } else if (resultStr == 'teamBWins') {
          score1 = 0; score2 = 1;
        } else if (resultStr == 'draw') {
          score1 = 0; score2 = 0;
        } else {
          // немає жодної інформації про результат — пропускаємо
          continue;
        }
      }

      // 2) Визначаємо, у якій команді був користувач
      final List<String> teamAPlayers =
          List<String>.from((data['teamA']?['playerIds'] ?? const []));
      final List<String> teamBPlayers =
          List<String>.from((data['teamB']?['playerIds'] ?? const []));
      bool isTeamA = teamAPlayers.contains(userId);

      // Fallback: якщо команд немає, але є учасники — вважаємо, що перша половина = А
      if (!isTeamA && teamBPlayers.isEmpty && teamAPlayers.isEmpty) {
        final List<String> participants =
            List<String>.from(data['participants'] ?? const []);
        if (participants.isNotEmpty) {
          final half = (participants.length / 2).ceil();
          final a = participants.take(half).toList();
          isTeamA = a.contains(userId);
        }
      }

      // 3) Рахуємо W/D/L
      String playedResult;
      if (score1 == score2) {
        draws++;
        playedResult = 'D';
      } else if ((isTeamA && score1 > score2) || (!isTeamA && score2 > score1)) {
        wins++;
        playedResult = 'W';
      } else {
        losses++;
        playedResult = 'L';
      }

      if (recentResults.length < 5) {
        recentResults.add(playedResult);
      }
    }

    final total = wins + draws + losses;
    final winRate = total > 0 ? (wins / total) * 100 : 0.0;

    // Доповнюємо до 5 елементів плейсхолдерами
    while (recentResults.length < 5) {
      recentResults.add('-');
    }

    return {
      'winRate': winRate,
      'recentResults': recentResults,
      'wins': wins,
      'draws': draws,
      'losses': losses,
    };
  } catch (e) {
    print('Error loading match stats: $e');
    return {
      'winRate': 0.0,
      'recentResults': ['-', '-', '-', '-', '-'],
      'wins': 0,
      'draws': 0,
      'losses': 0,
    };
  }
}

  void _editProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Редагування профілю (буде реалізовано)'.i18n('Profile editing (coming soon)'))),
    );
  }

  Future<int> _getBadgeEndorsementCount(String userId, String badgeId) async {
    try {
      final endorsementsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badge_endorsements')
          .doc(badgeId)
          .get();
      
      if (endorsementsSnapshot.exists) {
        final data = endorsementsSnapshot.data() as Map<String, dynamic>;
        final endorsers = List<String>.from(data['endorsers'] ?? []);
        return endorsers.length;
      }
      return 0;
    } catch (e) {
      print('Error getting badge endorsement count: $e');
      return 0;
    }
  }

  Future<void> _endorseBadge(String userId, app_badge.Badge badge) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    
    if (currentUserId == userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не можна підтверджувати свої бейджі'.i18n('You cannot endorse your own badges'))),
      );
      return;
    }
    
    try {
      final endorsementRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badge_endorsements')
          .doc(badge.id);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final endorsementDoc = await transaction.get(endorsementRef);
        
        List<String> endorsers = [];
        if (endorsementDoc.exists) {
          endorsers = List<String>.from(endorsementDoc.data()?['endorsers'] ?? []);
        }
        
        if (endorsers.contains(currentUserId)) {
          throw Exception('Ви вже підтвердили цей бейдж'.i18n('You already endorsed this badge'));
        }
        
        endorsers.add(currentUserId);
        
        transaction.set(endorsementRef, {
          'endorsers': endorsers,
          'lastEndorsedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      
      // Відправляємо нотифікацію власнику бейджу
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc.data()?['displayName'] ?? currentUserDoc.data()?['name'] ?? 'Користувач'.i18n('User');
      
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'type': 'badgeEndorsed',
        'title': 'Підтвердження бейджу'.i18n('Badge endorsement'),
        'message': I18n.inline('$currentUserName підтвердив ваш бейдж "${badge.localizedName}"', '$currentUserName confirmed your badge "${badge.localizedName}"'),
        'data': {'badgeId': badge.id},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('✅ Бейдж "${badge.localizedName}" підтверджено!', '✅ Badge "${badge.localizedName}" verified!')),
          backgroundColor: Colors.green,
        ),
      );
      
      // Оновлюємо UI
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('вже підтвердили') 
              ? 'Ви вже підтвердили цей бейдж'.i18n('You already endorsed this badge')
              : 'Помилка підтвердження'.i18n('Endorsement error')),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('${I18n.t('stats')} (буде реалізовано)', '${I18n.t('stats')} (coming soon)'))),
    );
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
    ).then((_) {
      // Оновлюємо дані після повернення з магазину
      setState(() {});
    });
  }

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('${I18n.t('settings')} (буде реалізовано)', '${I18n.t('settings')} (coming soon)'))),
    );
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
  I18n.t('logout_confirm'),
  style: TextStyle(color: Colors.white),
),
        content: Text(
          'Ви впевнені, що хочете вийти?'.i18n('Are you sure you want to log out?'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              await _auth.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: Text(I18n.t('logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final AppTeam team;
  final VoidCallback? onTap;

  const _TeamCard({required this.team, this.onTap});

  @override
  Widget build(BuildContext context) {
    final winRate = team.winRate.toStringAsFixed(0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF4caf50),
                  backgroundImage:
                      team.logoUrl != null ? NetworkImage(team.logoUrl!) : null,
                  child: team.logoUrl == null
                      ? Text(
                          team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        I18n.inline('${team.memberIds.length} гравців',
                            '${team.memberIds.length} players'),
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _teamStatChip('W', team.wins, Colors.greenAccent),
                _teamStatChip('L', team.losses, Colors.redAccent),
                _teamStatChip('D', team.draws, Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              I18n.inline('Win rate: $winRate%', 'Win rate: $winRate%'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
