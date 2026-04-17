import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/badge.dart' as app_badge;
import '../services/badge_service.dart';
import 'badges_store_screen.dart';
import '../services/friends_service.dart';
import 'friends_screen.dart';
import 'subscription_screen.dart';
import '../utils/i18n.dart';
import '../models/app_team.dart';
import '../models/team_stats.dart';
import '../models/team_invite.dart';
import '../services/team_service.dart';
import 'team_details_screen.dart';
import 'team_create_screen.dart';

@RoutePage()
class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BadgeService _badgeService = BadgeService();
  final FriendsService _friendsService = FriendsService();
  final TeamService _teamService = TeamService();
  final ImagePicker _picker = ImagePicker();
  
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  List<app_badge.Badge> _userBadges = [];
  int _friendsCount = 0;
  Stream<List<AppTeam>>? _teamsStream;
  Stream<List<TeamInvite>>? _teamInvitesStream;
  String? _userId;
  Future<Map<String, dynamic>>? _matchStatsFuture;
  String? _matchStatsUserId;
  bool _donationPromptCheckStarted = false;
  bool _donationDialogVisible = false;

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
      _checkAndShowDonationPrompt(uid);
    }
  }

  Future<void> _checkAndShowDonationPrompt(String uid) async {
    if (_donationPromptCheckStarted) return;
    _donationPromptCheckStarted = true;
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final settings =
          Map<String, dynamic>.from(data['settings'] ?? const <String, dynamic>{});
      final isDismissed = settings['hideDonationPrompt'] == true;
      if (isDismissed || !mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _donationDialogVisible) return;
        _showDonationDialog();
      });
    } catch (_) {
      // If settings cannot be loaded, do not block profile rendering.
    }
  }

  _DonationConfig _getDonationConfig() {
    final isEnglish = I18n.language.value.toLowerCase().startsWith('en');
    if (isEnglish) {
      return const _DonationConfig(
        imageAssetPath: 'assets/donate/en_donate.png',
        donateUrl: 'https://www.privat24.ua/send/j1gih',
      );
    }
    return const _DonationConfig(
      imageAssetPath: 'assets/donate/ua_donate.png',
      donateUrl: 'https://www.privat24.ua/send/j1gh1',
    );
  }

  Future<void> _setDonationPromptDismissed() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'settings': {'hideDonationPrompt': true}
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _openDonationLink(String link) async {
    final uri = Uri.parse(link);
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } catch (_) {}
    }
    if (launched) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          I18n.inline(
            'Не вдалося відкрити посилання для донату',
            'Failed to open donation link',
          ),
        ),
      ),
    );
  }

  void _showDonationDialog() {
    _donationDialogVisible = true;
    final config = _getDonationConfig();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          I18n.inline('Підтримайте розвиток проєкту', 'Support project growth'),
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                I18n.inline(
                  'Ваша підтримка допомагає швидше запускати нові фішки.',
                  'Your support helps us ship new features faster.',
                ),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async => _openDonationLink(config.donateUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(config.imageAssetPath, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                I18n.inline(
                  'Натисніть на QR-код, щоб перейти до донату',
                  'Tap the QR code to open donation page',
                ),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _setDonationPromptDismissed();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text(I18n.inline('Більше не нагадувати', 'Don\'t remind again')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(I18n.inline('Закрити', 'Close')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              await _openDonationLink(config.donateUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4caf50),
              foregroundColor: Colors.white,
            ),
            child: Text(I18n.inline('Підтримати', 'Donate')),
          ),
        ],
      ),
    ).whenComplete(() {
      _donationDialogVisible = false;
    });
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
              ...invites.map(_buildInviteCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInviteCard(TeamInvite invite) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('teams').doc(invite.teamId).get(),
      builder: (context, snapshot) {
        final teamData = snapshot.data?.data();
        final logoUrl = (teamData?['logoUrl'] ?? '').toString();
        final city = (teamData?['city'] ?? '').toString();
        final motto = (teamData?['description'] ??
                I18n.inline(
                    'Команда кличе вас у склад', 'Club wants you on the roster'))
            .toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamDetailsScreen(teamId: invite.teamId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF1A2737),
                      backgroundImage:
                          logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                      child: logoUrl.isEmpty
                          ? Text(
                              invite.teamName.isNotEmpty
                                  ? invite.teamName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '📍 $city',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          motto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 320;
                  final cancelButton = TextButton(
                    onPressed: () async {
                      await _teamService.respondToInvite(
                        invite: invite,
                        accept: false,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(I18n.t('cancel')),
                  );
                  final joinButton = ElevatedButton(
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
                          SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF36D399),
                      foregroundColor: const Color(0xFF041013),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(I18n.inline('Приєднатись', 'Join')),
                  );
                  if (isTight) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cancelButton,
                        const SizedBox(height: 8),
                        joinButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      cancelButton,
                      const SizedBox(width: 12),
                      joinButton,
                    ],
                  );
                },
              ),
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

  void _ensureMatchStatsFuture(String userId) {
    if (userId.isEmpty) return;
    if (_matchStatsUserId == userId && _matchStatsFuture != null) return;
    _matchStatsUserId = userId;
    _matchStatsFuture = _loadMatchStats(userId);
  }

  Widget _buildProfileContent(Map<String, dynamic> userData) {
    final displayName = userData['name'] ?? userData['displayName'] ?? I18n.t('player');
    final avatarUrl = userData['avatar'] ?? userData['avatarUrl'];
    final rating = (userData['rating'] ?? 0.0).toDouble();
    final coins = userData['coins'] ?? 0;
    final profileUserId = userData['uid'] ?? _auth.currentUser?.uid ?? '';
    if (profileUserId.isNotEmpty) {
      _ensureMatchStatsFuture(profileUserId);
    }
    final statsFuture = _matchStatsFuture;
    
    return CustomScrollView(
      slivers: [
        // App bar with gradient
                SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: const Color(0xFF0f0f23),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: _showSettings,
            ),
          ],
        ),

                SliverToBoxAdapter(
          child: Container(
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
            child: _buildProfileHeader(
              userData,
              displayName,
              avatarUrl,
              rating,
              coins,
              statsFuture,
            ),
          ),
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
  _buildActionsMenu(userData),
  const SizedBox(height: 20),
],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
      Map<String, dynamic> userData,
      String displayName,
      String? avatarUrl,
      double rating,
      int coins,
      Future<Map<String, dynamic>>? statsFuture) {
    final userId = userData['uid'] ?? _auth.currentUser?.uid ?? '';
    return FutureBuilder<Map<String, dynamic>>(
      future: statsFuture ?? _loadMatchStats(userId),
      builder: (context, snapshot) {
        final stats = snapshot.data ??
            {
              'winRate': 0.0,
              'recentResults': ['-', '-', '-', '-', '-'],
              'wins': 0,
              'draws': 0,
              'losses': 0,
            };
        final recentResults = List<String>.from(stats['recentResults'] as List);
        final winRate = (stats['winRate'] as num).toDouble();
        final wdlText =
            '${stats['wins'] ?? 0}W · ${stats['draws'] ?? 0}D · ${stats['losses'] ?? 0}L';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF162035), Color(0xFF0F1624)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4caf50).withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildAvatarPlaceholder(displayName),
                                    )
                                  : _buildAvatarPlaceholder(displayName),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_getPositionDisplay(userData['position'])} • ${userData['city'] ?? 'Earth'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              I18n.inline('Полюй на моменти — поле запам’ятає.',
                                  'Hunt for moments — the pitch remembers.'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final pills = [
                                  _profilePill(
                                    icon: Icons.star_border_rounded,
                                    label: I18n.t('rating'),
                                    value: rating.toStringAsFixed(2),
                                    accent: const Color(0xFFFFD54F),
                                  ),
                                  _profilePill(
                                    icon: Icons.sports_soccer,
                                    label: I18n.t('matches'),
                                    value:
                                        ((userData['matchesPlayed'] ?? 0) as num)
                                            .toString(),
                                    accent: const Color(0xFF4CAF50),
                                  ),
                                  _profilePill(
                                    icon: Icons.percent,
                                    label: 'Win rate',
                                    value: '${winRate.toStringAsFixed(0)}%',
                                    accent: const Color(0xFF64B5F6),
                                  ),
                                  _profilePill(
                                    icon: Icons.sports,
                                    label: I18n.inline('Голи', 'Goals'),
                                    value:
                                        ((userData['goals'] ?? 0) as num).toString(),
                                    accent: const Color(0xFFFF7043),
                                  ),
                                ];
                                final isCompact = constraints.maxWidth < 500;
                                final columns = isCompact ? 2 : 4;
                                final spacing = 10.0;
                                final itemWidth = columns == 1
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth -
                                            spacing * (columns - 1)) /
                                        columns;
                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: pills
                                      .map(
                                        (pill) => SizedBox(
                                          width: itemWidth,
                                          child: pill,
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              I18n.inline('Серія останніх матчів',
                                  'Recent form'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              wdlText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 6,
                          children: recentResults
                              .take(5)
                              .map((result) => buildResultTile(result))
                              .toList(),
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
  }

  Widget _profilePill({
    required IconData icon,
    required String label,
    required String value,
    Color? accent,
  }) {
    final primary = accent ?? Colors.white70;
    final bg = (accent ?? Colors.white).withOpacity(0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (accent ?? Colors.white).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
              onTap: () => context.router.push(
                MatchesRoute(initialTabIndex: 1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              I18n.t('videos'),
              (userData['videosUploaded'] ?? 0).toString(),
              Icons.videocam,
              const Color(0xFFFF6B35),
              onTap: () =>
                  context.router.push(VideoMainRoute(myContent: 'videos')),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.25),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
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
                I18n.inline('Скіли', 'Skills'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _openBadgesStore,
                child: Text(
                  I18n.inline('Додати', 'Add'),
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
                    I18n.inline('Ще немає скілів', 'No skills yet'),
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

  Widget _buildActionsMenu(Map<String, dynamic> userData) {
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
     '⚽ Мої матчі'.i18n('⚽ My matches'),
     I18n.inline('Переглянути свої матчі', 'View your matches'),
     Icons.sports_soccer,
     () => _openMyMatches(),
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
            () => _openStats(userData),
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

    final orderedDocs = [...matchesSnapshot.docs]
      ..sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();
        final tsA = (dataA['finishedAt'] as Timestamp?) ??
            (dataA['updatedAt'] as Timestamp?) ??
            Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
        final tsB = (dataB['finishedAt'] as Timestamp?) ??
            (dataB['updatedAt'] as Timestamp?) ??
            Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
        return tsB.compareTo(tsA);
      });

    for (final doc in orderedDocs) {
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

  Future<String?> _uploadAvatar(String uid, XFile picked) async {
    try {
      final Uint8List bytes = await picked.readAsBytes();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref('avatars/$uid/$fileName');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await task.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Не вдалося завантажити фото: $e',
                'Failed to upload avatar: $e'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
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
    context.router.push(const FriendsRoute());
  }

     void _openMyMatches() {
     context.router.push(MatchesRoute(initialTabIndex: 1));
   }

  void _openMyVideos() {
    context.router.push(VideoMainRoute(myContent: 'videos'));
  }

  void _openMyChallenges() {
    context.router.push(VideoMainRoute(myContent: 'challenges'));
  }

  void _openStats(Map<String, dynamic> userData) {
    final statsFuture = _matchStatsFuture ??
        _loadMatchStats(userData['uid'] ?? _auth.currentUser?.uid ?? '');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileStatsPage(
          statsFuture: statsFuture,
          userData: userData,
        ),
      ),
    );
  }

  void _openSubscriptions() {
    context.router.push(const SubscriptionRoute());
  }

  void _openBadgesStore() {
    context.router.push(const BadgesStoreRoute()).then((_) {
      // Оновлюємо дані після повернення з магазину
      setState(() {});
    });
  }

  void _showSettings() {
    context.router.push(const ProfileSettingsRoute());
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
              context.router.replace(const LoginRoute());
            },
            child: Text(I18n.t('logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: Colors.white70),
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teamStats')
          .doc(team.id)
          .snapshots(),
      builder: (context, snapshot) {
        final stats = snapshot.hasData && snapshot.data!.exists
            ? TeamStats.fromDoc(snapshot.data!)
            : TeamStats.empty(team.id, name: team.name);
        return _TeamCardBody(
          team: team,
          stats: stats,
          onTap: onTap,
        );
      },
    );
  }
}

class _TeamCardBody extends StatelessWidget {
  final AppTeam team;
  final TeamStats stats;
  final VoidCallback? onTap;

  const _TeamCardBody({
    required this.team,
    required this.stats,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wins = stats.wins != 0 ? stats.wins : team.wins;
    final draws = stats.draws != 0 ? stats.draws : team.draws;
    final losses = stats.losses != 0 ? stats.losses : team.losses;
    final totalMatches = max<int>(wins + draws + losses, 0);
    final winRate =
        totalMatches > 0 ? ((wins / totalMatches) * 100).toStringAsFixed(0) : '0';

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
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _teamStatChip('W', wins, Colors.greenAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _teamStatChip('D', draws, Colors.orangeAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _teamStatChip('L', losses, Colors.redAccent),
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStatsPage extends StatelessWidget {
  final Future<Map<String, dynamic>> statsFuture;
  final Map<String, dynamic> userData;

  const ProfileStatsPage({
    super.key,
    required this.statsFuture,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final totalMatches =
        (userData['matchesPlayed'] ?? userData['totalMatches'] ?? 0) as num;
    final goalsValue = (userData['goals'] ?? 0) as num;
    final assistsValue = (userData['assists'] ?? 0) as num;
    final cleanSheetsValue = (userData['cleanSheets'] ?? 0) as num;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        title: Text(I18n.t('statistics_title')),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4caf50)),
            );
          }
          final stats = snapshot.data ??
              {
                'winRate': 0.0,
                'wins': 0,
                'draws': 0,
                'losses': 0,
                'recentResults': ['-', '-', '-', '-', '-'],
              };
          final winRate = (stats['winRate'] as num?)?.toDouble() ?? 0.0;
          final wins = (stats['wins'] ?? 0).toString();
          final draws = (stats['draws'] ?? 0).toString();
          final losses = (stats['losses'] ?? 0).toString();
          final goalsPerMatch =
              totalMatches > 0 ? (goalsValue / totalMatches).toStringAsFixed(2) : '0.0';
          final recent = List<String>.from(
              stats['recentResults'] ?? const ['-', '-', '-', '-', '-']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.inline('Загальні показники', 'Summary'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    buildPerformanceStat(
                      I18n.inline('Win rate', 'Win rate'),
                      '${winRate.toStringAsFixed(0)}%',
                      I18n.inline('W: $wins · D: $draws · L: $losses',
                          'W: $wins · D: $draws · L: $losses'),
                      Icons.pie_chart_outline,
                      const Color(0xFF4CAF50),
                    ),
                    buildPerformanceStat(
                      I18n.inline('Голи', 'Goals'),
                      goalsValue.toString(),
                      I18n.inline('за матч: $goalsPerMatch', 'per match: $goalsPerMatch'),
                      Icons.sports_soccer,
                      const Color(0xFFFF7043),
                    ),
                    buildPerformanceStat(
                      I18n.inline('Асисти', 'Assists'),
                      assistsValue.toString(),
                      I18n.inline('створено моментів', 'created chances'),
                      Icons.timeline,
                      const Color(0xFF42A5F5),
                    ),
                    buildPerformanceStat(
                      I18n.inline('Матчів', 'Matches'),
                      totalMatches.toString(),
                      I18n.inline('в кар’єрі', 'career total'),
                      Icons.calendar_month,
                      const Color(0xFF26C6DA),
                    ),
                    buildPerformanceStat(
                      I18n.inline('Сухі ігри', 'Clean sheets'),
                      cleanSheetsValue.toString(),
                      I18n.inline('для воротарів', 'keeper badge'),
                      Icons.shield,
                      const Color(0xFF8D6E63),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  I18n.inline('Форма (останні 5)', 'Form (last 5)'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: recent
                      .take(5)
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: buildResultTile(r),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DonationConfig {
  final String imageAssetPath;
  final String donateUrl;

  const _DonationConfig({
    required this.imageAssetPath,
    required this.donateUrl,
  });
}

Widget buildPerformanceStat(
    String title, String value, String caption, IconData icon, Color color) {
  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 140),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildResultTile(String result) {
  var display = result;
  Color color;
  switch (result) {
    case 'W':
      color = const Color(0xFF4CAF50);
      break;
    case 'L':
      color = const Color(0xFFE53935);
      break;
    case 'D':
      color = const Color(0xFF9E9E9E);
      break;
    default:
      color = Colors.white24;
      display = '-';
  }
  return Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color, width: 1.2),
      color: color.withOpacity(0.18),
    ),
    child: Center(
      child: Text(
        display,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

