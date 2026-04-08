import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/i18n.dart';
import '../widgets/player_avatar_button.dart';
import '../services/notification_service.dart';
import '../core/app_auth_context.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  ModeSelectionScreenState createState() => ModeSelectionScreenState();
}

class ModeSelectionScreenState extends State<ModeSelectionScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  final Random _random = Random();
  final NotificationService _notificationService = NotificationService();

  String _currentGreeting = '';
  String _currentRatingText = '';
  String _currentInstruction = '';
  List<_NewsEntry> _newsEntries = const [];
  bool _newsLoading = true;
  Future<_HeroStats>? _heroStatsFuture;
  String? _heroStatsUserId;

  @override
  void initState() {
    super.initState();
    final uid = AppAuthContext.userId;
    if (uid != null) {
      _userStream =
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
      _primeHeroStats(uid);
    }
    _updateGreeting();
    _loadLatestNews();
  }

  void _updateGreeting() {
    final phrase = _motivationPhrases[_random.nextInt(_motivationPhrases.length)];
    final uid = AppAuthContext.userId;
    if (uid == null) {
      setState(() {
        _currentGreeting = I18n.inline(phrase.ua, phrase.en);
        _currentRatingText = I18n.inline('Гість у FLAP', 'Guest inside FLAP');
        _currentInstruction = I18n.inline(phrase.ctaUa, phrase.ctaEn);
      });
      return;
    }

    FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
      final data = doc.data();
      final name = data != null
          ? (data['displayName'] ?? data['authorName'] ?? data['name'] ?? I18n.t('player'))
          : I18n.t('player');
      final rating = data != null ? (data['rating'] ?? 3.0).toDouble() : 3.0;
      final matches = data != null ? ((data['totalMatches'] ?? data['matches'] ?? data['matchesPlayed'] ?? 0) as num).toInt() : 0;
setState(() {
  _currentGreeting = I18n.inline(
    phrase.ua.replaceAll('{name}', name),
    phrase.en.replaceAll('{name}', name),
  );
  _currentRatingText = I18n.inline(
      'Рейтинг ${rating.toStringAsFixed(2)} • $matches матчів',
      'Rating ${rating.toStringAsFixed(2)} • $matches matches');
  _currentInstruction = I18n.inline(phrase.ctaUa, phrase.ctaEn);
});
    });
  }

  Future<void> _loadLatestNews() async {
    try {
      final results = await Future.wait<_NewsEntry?>([
        _fetchLatestMatchNews(),
        _fetchLatestVideoNews(),
        _fetchLatestTeamNews(),
      ]);

      final movement = await _fetchTeamMovementNews();

      final available = <_NewsEntry>[
        ...results.whereType<_NewsEntry>(),
        ...movement,
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _newsEntries = available.isNotEmpty
            ? available.take(3).toList(growable: false)
            : <_NewsEntry>[_defaultNewsEntry()];
        _newsLoading = false;
      });
    } catch (_) {
      setState(() {
        _newsEntries = <_NewsEntry>[_defaultNewsEntry()];
        _newsLoading = false;
      });
    }
  }

  Future<_NewsEntry?> _fetchLatestMatchNews() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final teamAName = (data['teamA']?['name'] ?? data['title'] ?? I18n.inline('Матч дня', 'Match day')).toString();
      final teamBName = (data['teamB']?['name'] ?? I18n.inline('Суперник', 'Opponent')).toString();
      final status = (data['status'] ?? 'open').toString();
      final teamAScore = data['teamAScore'];
      final teamBScore = data['teamBScore'];
      final location = (data['location'] ?? 'FLAP Arena').toString();
      final time = (data['time'] ?? '').toString();
      final organizer = (data['organizerName'] ?? I18n.inline('Організатор', 'Organizer')).toString();
      final matchTitle = (data['title'] ?? '$teamAName vs $teamBName').toString();
      String subtitle;
      if (status == 'finished' && teamAScore != null && teamBScore != null) {
        subtitle = I18n.inline(
          '$organizer завершив матч "$matchTitle" • рахунок $teamAScore:$teamBScore',
          '$organizer finished "$matchTitle" • final score $teamAScore:$teamBScore',
        );
      } else {
        subtitle = I18n.inline(
          '$organizer створив матч "$matchTitle" • старт о $time',
          '$organizer created "$matchTitle" • kick-off at $time',
        );
      }
      return _NewsEntry(
        title: matchTitle,
        subtitle: subtitle,
        icon: Icons.sports_soccer,
        color: const Color(0xFF4caf50),
        timestamp: _resolveTimestamp(data, const ['updatedAt', 'createdAt']),
        route: '/matches',
        ctaLabel: I18n.inline('Відкрити матчі', 'Open matches'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<_NewsEntry>> _fetchTeamMovementNews() async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('activityFeed')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final items = <_NewsEntry>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString();
      if (type != 'joined_team' && type != 'left_team') continue;

      final userName = (data['userName'] ?? I18n.inline('Гравець', 'Player')).toString();
      final teamName = (data['teamName'] ?? I18n.inline('Команда', 'Team')).toString();

      final isJoin = type == 'joined_team';
      items.add(
        _NewsEntry(
          title: teamName,
          subtitle: isJoin
              ? I18n.inline('$userName приєднався до команди', '$userName joined the team')
              : I18n.inline('$userName покинув команду', '$userName left the team'),
          icon: isJoin ? Icons.person_add_alt_1 : Icons.exit_to_app,
          color: isJoin ? const Color(0xFF26A69A) : const Color(0xFFEF5350),
          timestamp: _resolveTimestamp(data, const ['createdAt']),
          route: '/teams',
          ctaLabel: I18n.inline('Відкрити клуби', 'Open clubs'),
        ),
      );
    }
    return items;
  } catch (_) {
    return const [];
  }
}

  Future<_NewsEntry?> _fetchLatestVideoNews() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final author = (data['authorName'] ?? I18n.inline('Гравець FLAP', 'FLAP player')).toString();
      final rawTitle = (data['title'] ?? '').toString().trim();
      final challengeTitle = (data['challengeTitle'] ?? '').toString().trim();
      final title = (rawTitle.isEmpty ||
              rawTitle == 'Відео створювача' ||
              rawTitle == 'Creator video')
          ? (challengeTitle.isNotEmpty
              ? challengeTitle
              : I18n.inline('Нове відео', 'New video'))
          : rawTitle;
      return _NewsEntry(
        title: title,
        subtitle: I18n.inline(
          '$author завантажив відео "$title"',
          '$author uploaded "$title"',
        ),
        icon: Icons.play_circle_fill,
        color: const Color(0xFFFF7043),
        timestamp: _resolveTimestamp(data, const ['createdAt', 'updatedAt']),
        route: '/video-main',
        ctaLabel: I18n.inline('Дивитись відео', 'Watch video feed'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_NewsEntry?> _fetchLatestTeamNews() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final teamName = (data['name'] ?? I18n.inline('Нова команда', 'New team')).toString();
      final city = (data['city'] ?? I18n.inline('рідному місті', 'their city')).toString();
      return _NewsEntry(
        title: teamName,
        subtitle: I18n.inline(
          'Команда з $city вже в грі',
          'A squad from $city just joined the arena',
        ),
        icon: Icons.groups,
        color: const Color(0xFF42a5f5),
        timestamp: _resolveTimestamp(data, const ['createdAt', 'updatedAt']),
        route: '/teams',
        ctaLabel: I18n.inline('Відкрити клуби', 'Open clubs'),
      );
    } catch (_) {
      return null;
    }
  }

  _NewsEntry _defaultNewsEntry() => _NewsEntry(
        title: I18n.inline('FLAP Live', 'FLAP Live'),
        subtitle: I18n.inline('Слідкуй за матчами та відео у реальному часі', 'Watch matches and videos in real time'),
        icon: Icons.flash_on,
        color: const Color(0xFF7e57c2),
        timestamp: DateTime.now(),
        route: '/matches',
        ctaLabel: I18n.inline('Дивитись розклад', 'View schedule'),
      );

  DateTime _resolveTimestamp(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) {
        return value.toDate();
      }
    }
    return DateTime.now();
  }

  Widget _buildNewsSection() {
  if (_newsLoading) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              I18n.inline('Завантажуємо новини...', 'Loading news...'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  final items = _newsEntries.isNotEmpty
      ? _newsEntries.take(3).toList(growable: false)
      : <_NewsEntry>[_defaultNewsEntry()];

  return Column(
    children: [
      for (int i = 0; i < items.length; i++) ...[
        _buildNewsCardItem(items[i], primary: i == 0),
        if (i != items.length - 1) const SizedBox(height: 12),
      ],
    ],
  );
}

Widget _buildNewsCardItem(_NewsEntry entry, {required bool primary}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      color: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [entry.color, entry.color.withValues(alpha: 0.5)],
                ),
              ),
              child: Text(
                primary
                    ? I18n.inline('Новина дня', 'News of the day')
                    : I18n.inline('Свіжа новина', 'Fresh news'),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _formatNewsTime(entry.timestamp),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          entry.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry.subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: entry.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(entry.icon, color: entry.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                I18n.inline(
                  'FLAP Live • Оновлено зі стрічки матчів, відео та клубів',
                  'FLAP Live • Pulled from matches, videos & clubs feed',
                ),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
        if (entry.ctaLabel != null && entry.route != null) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, entry.route!),
              icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 18),
              label: Text(
                entry.ctaLabel!,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF0f1923),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final rating = (data?['rating'] ?? 0.0).toDouble();
            return Row(
              children: [
                Text(
                  '⭐ ${rating.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sports_soccer, color: Colors.white),
                  onPressed: () => Navigator.pushNamed(context, '/matches'),
                ),
                IconButton(
                  icon: const Icon(Icons.video_collection, color: Colors.white),
                  onPressed: () => Navigator.pushNamed(context, '/video-main'),
                ),
                StreamBuilder<int>(
                  stream: _notificationService.getUnreadCount(),
                  builder: (context, notifSnapshot) {
                    final unreadCount = notifSnapshot.data ?? 0;
                    return Stack(
                      children: [
                        IconButton(
                          tooltip: I18n.t('notifications'),
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                          onPressed: () => Navigator.pushNamed(context, '/notifications'),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person, color: Colors.white),
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                ),
              ],
            );
          },
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            const matchColors = [Color(0xFF0f9d58), Color(0xFF0c6f3c)];
            const videoColors = [Color(0xFFc62828), Color(0xFF8e24aa)];
            const teamColors = [Color(0xFF1976d2), Color(0xFF0d47a1)];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(data),
                const SizedBox(height: 20),
                _buildNewsSection(),
                const SizedBox(height: 24),
                _ModeCard(
                  title: I18n.t('matches'),
                  subtitle: I18n.inline(
                    'Знаходь матчі поблизу, керуй командами',
                    'Find matches, manage squads',
                  ),
                  highlights: [
                    I18n.inline('Новий Team Hub', 'New Team Hub'),
                    I18n.inline('Гнучкі формати', 'Flexible formats'),
                    I18n.inline('Рейтинг гравців', 'Player rating'),
                  ],
                  icon: Icons.sports_soccer,
                  colors: matchColors,
                  badge: I18n.inline('Матч-день', 'Match day'),
                  actionLabel: I18n.inline('До матчів', 'Browse matches'),
                  illustration: _ModeArt(type: _ModeArtType.matches, colors: matchColors),
                  onTap: () => Navigator.pushNamed(context, '/matches'),
                ),
                const SizedBox(height: 16),
                _ModeCard(
                  title: I18n.t('videos'),
                  subtitle: I18n.inline(
                    'Кидай челенджі, збирай перегляди',
                    'Join challenges, grow your audience',
                  ),
                  highlights: [
                    I18n.inline('16:9 превʼю', '16:9 previews'),
                    I18n.inline('Челендж-стрічка', 'Challenge feed'),
                    I18n.inline('Запити на оцінку', 'Rating requests'),
                  ],
                  icon: Icons.video_collection,
                  colors: videoColors,
                  badge: I18n.inline('Пульс контенту', 'Content pulse'),
                  actionLabel: I18n.inline('До відео', 'Open videos'),
                  illustration: _ModeArt(type: _ModeArtType.videos, colors: videoColors),
                  onTap: () => Navigator.pushNamed(context, '/video-main'),
                ),
                const SizedBox(height: 16),
                _ModeCard(
                  title: I18n.inline('Команди', 'Teams'),
                  subtitle: I18n.inline(
                    'Створюй клуби, керуй ростером',
                    'Create clubs, manage rosters',
                  ),
                  highlights: [
                    I18n.inline('Запрошення в 1 клік', 'One-tap invites'),
                    I18n.inline('Матчі між командами', 'Team-only matches'),
                    I18n.inline('Статистика голів', 'Goal tracking'),
                  ],
                  icon: Icons.groups_2,
                  colors: teamColors,
                  badge: I18n.inline('Club DNA', 'Club DNA'),
                  actionLabel: I18n.inline('Мої команди', 'Your clubs'),
                  illustration: _ModeArt(type: _ModeArtType.teams, colors: teamColors),
                  onTap: () => Navigator.pushNamed(context, '/teams'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildHeroCard(Map<String, dynamic>? data) {
    final displayName = data?['displayName'] ??
        data?['name'] ??
        data?['authorName'] ??
        data?['email']?.toString().split('@').first ??
        I18n.t('player');
    final avatarUrl =
        (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString();
    final rating = (data?['rating'] ?? 0.0).toDouble();
    final matches = (data?['totalMatches'] ?? 0).toString();
    final coins = (data?['coins'] ?? data?['flCoins'] ?? 0).toString();
    final uid = AppAuthContext.userId;
    if (uid != null) {
      _primeHeroStats(uid);
    }
    final heroStatsFuture = _heroStatsFuture;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 560;
        final persona = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PlayerAvatarButton(
              userId: AppAuthContext.userId ?? '',
              displayName: displayName,
              avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
              size: 84,
              backgroundColor: Colors.white,
              borderColor: Colors.white.withOpacity(0.2),
              borderWidth: 2,
            ),
            const SizedBox(height: 12),
            Text(
              I18n.inline('Привіт, $displayName', 'Hey, $displayName'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentGreeting,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentRatingText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _updateGreeting,
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
              label: Text(
                I18n.inline('оновити настрій', 'refresh vibe'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        );

        final statGrid = Row(
          children: [
            Expanded(
              child: _heroPill(
                icon: Icons.star,
                value: rating.toStringAsFixed(2),
                label: I18n.inline('Рейтинг', 'Rating'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _heroPill(
                icon: Icons.sports_soccer,
                value: matches,
                label: I18n.inline('Матчів', 'Matches'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _heroPill(
                icon: Icons.monetization_on_outlined,
                value: coins,
                label: 'FL Coins',
              ),
            ),
          ],
        );

        final winRateCard = _buildWinRateCard(heroStatsFuture);

        final content = isWide
            ? Row(
                children: [
                  Expanded(child: persona),
                  Container(
                    width: 1,
                    height: 160,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statGrid,
                        const SizedBox(height: 18),
                        winRateCard,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  persona,
                  const SizedBox(height: 18),
                  statGrid,
                  const SizedBox(height: 18),
                  winRateCard,
                ],
              );

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF121F2E), Color(0xFF080E18)],
              ),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: content,
          ),
        );
      },
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildWinRateCard(Future<_HeroStats>? statsFuture) {
    final baseDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      color: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );
    if (statsFuture == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: baseDecoration,
        child: _buildWinRateContent(_HeroStats.empty),
      );
    }

    return FutureBuilder<_HeroStats>(
      future: statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? _HeroStats.empty;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: baseDecoration,
          child: _buildWinRateContent(stats),
        );
      },
    );
  }

  Widget _buildWinRateContent(_HeroStats stats) {
    final trend = '${stats.wins}W · ${stats.draws}D · ${stats.losses}L';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF1de9b6), Color(0xFF42a5f5)],
                ),
              ),
              child: const Icon(Icons.insights, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.inline('Відсоток перемог', 'Win rate'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${stats.winRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              trend,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stats.recentResults
              .take(5)
              .map((result) => _buildResultChip(result))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResultChip(String result) {
    Color color;
    String display = result;
    switch (result) {
      case 'W':
        color = const Color(0xFF4CAF50);
        break;
      case 'D':
        color = const Color(0xFFFFC107);
        break;
      case 'L':
        color = const Color(0xFFF44336);
        break;
      default:
        color = Colors.white24;
        display = '-';
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.8)),
        color: color.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Text(
          display,
          style: TextStyle(
            color: color == Colors.white24 ? Colors.white54 : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _primeHeroStats(String uid) {
    if (_heroStatsUserId == uid && _heroStatsFuture != null) return;
    _heroStatsUserId = uid;
    _heroStatsFuture = _fetchHeroStats(uid);
  }

  Future<_HeroStats> _fetchHeroStats(String userId) async {
    try {
      final base = FirebaseFirestore.instance
          .collection('matches')
          .where('participants', arrayContains: userId);
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await base
            .where('status', isEqualTo: 'finished')
            .orderBy('updatedAt', descending: true)
            .limit(20)
            .get();
      } catch (_) {
        try {
          snapshot = await base
              .where('status', isEqualTo: 'finished')
              .limit(20)
              .get();
        } catch (_) {
          snapshot = await base.limit(20).get();
        }
      }
      int wins = 0;
      int draws = 0;
      int losses = 0;
      final List<String> recentResults = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        int? scoreAOpt = data['teamAScore'] as int?;
        int? scoreBOpt = data['teamBScore'] as int?;
        var scoreA = scoreAOpt ?? 0;
        var scoreB = scoreBOpt ?? 0;
        if (scoreAOpt == null || scoreBOpt == null) {
          final result = (data['result'] as String?) ?? '';
          if (result == 'teamAWins') {
            scoreA = 1;
            scoreB = 0;
          } else if (result == 'teamBWins') {
            scoreA = 0;
            scoreB = 1;
          } else if (result == 'draw') {
            scoreA = 0;
            scoreB = 0;
          } else {
            continue;
          }
        }
        final List<String> teamAPlayers =
            List<String>.from((data['teamA']?['playerIds'] ?? const []));
        final List<String> teamBPlayers =
            List<String>.from((data['teamB']?['playerIds'] ?? const []));

        bool isTeamA = teamAPlayers.contains(userId);
        if (!isTeamA && teamAPlayers.isEmpty && teamBPlayers.isEmpty) {
          final participants =
              List<String>.from(data['participants'] ?? const []);
          if (participants.isNotEmpty) {
            final half = (participants.length / 2).ceil();
            isTeamA = participants.take(half).contains(userId);
          }
        }

        if (scoreA == scoreB) {
          draws++;
          if (recentResults.length < 5) recentResults.add('D');
        } else if ((isTeamA && scoreA > scoreB) ||
            (!isTeamA && scoreB > scoreA)) {
          wins++;
          if (recentResults.length < 5) recentResults.add('W');
        } else {
          losses++;
          if (recentResults.length < 5) recentResults.add('L');
        }
      }

      while (recentResults.length < 5) {
        recentResults.add('-');
      }
      final total = wins + draws + losses;
      final winRate = total > 0 ? (wins / total) * 100 : 0.0;
      return _HeroStats(
        winRate: winRate,
        wins: wins,
        draws: draws,
        losses: losses,
        recentResults: recentResults,
      );
    } catch (_) {
      return _HeroStats.empty;
    }
  }

  String _formatNewsTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) {
      return I18n.inline('щойно', 'just now');
    }
    if (diff.inHours < 1) {
      return I18n.inline('${diff.inMinutes} хв', '${diff.inMinutes}m ago');
    }
    if (diff.inHours < 24) {
      return I18n.inline('${diff.inHours} год', '${diff.inHours}h ago');
    }
    return '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}';
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> highlights;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final String badge;
  final String actionLabel;
  final Widget? illustration;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.highlights,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.badge = '',
    this.actionLabel = '',
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAction =
        actionLabel.isNotEmpty ? actionLabel : I18n.inline('Відкрити', 'Open');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (illustration != null)
              Positioned(
                right: -12,
                top: -12,
                child: illustration!,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                if (badge.isNotEmpty) const SizedBox(height: 12),
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.1,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: highlights
                      .map(
                        (text) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      effectiveAction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ModeArtType { matches, videos, teams }

class _ModeArt extends StatelessWidget {
  final _ModeArtType type;
  final List<Color> colors;

  const _ModeArt({required this.type, required this.colors});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case _ModeArtType.matches:
        return _buildMatchesArt();
      case _ModeArtType.videos:
        return _buildVideoArt();
      case _ModeArtType.teams:
        return _buildTeamsArt();
    }
  }

  Widget _buildMatchesArt() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        children: [
          _blurredCircle(colors.first),
          Positioned(
            right: 16,
            top: 12,
            child: Icon(
              Icons.sports_soccer,
              color: Colors.white.withValues(alpha: 0.3),
              size: 72,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 10,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArt() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        children: [
          _blurredCircle(colors.last),
          Positioned(
            right: 12,
            top: 20,
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white.withValues(alpha: 0.3),
              size: 78,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 16,
            child: Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsArt() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        children: [
          _blurredCircle(colors.first),
          Positioned(
            right: 20,
            top: 10,
            child: Icon(
              Icons.shield,
              color: Colors.white.withValues(alpha: 0.25),
              size: 70,
            ),
          ),
          Positioned(
            right: -6,
            bottom: 12,
            child: Container(
              width: 90,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  Icon(Icons.person, color: Colors.white54, size: 18),
                  Icon(Icons.person, color: Colors.white38, size: 18),
                  Icon(Icons.person, color: Colors.white24, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurredCircle(Color base) {
    return Positioned(
      right: -30,
      top: -30,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.2),
              base.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStats {
  final double winRate;
  final int wins;
  final int draws;
  final int losses;
  final List<String> recentResults;

  const _HeroStats({
    required this.winRate,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.recentResults,
  });

  static const _HeroStats empty = _HeroStats(
    winRate: 0.0,
    wins: 0,
    draws: 0,
    losses: 0,
    recentResults: ['-', '-', '-', '-', '-'],
  );
}

class _NewsEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  final String? route;
  final String? ctaLabel;

  const _NewsEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.route,
    this.ctaLabel,
  });
}

class _MotivationPhrase {
  final String ua;
  final String en;
  final String ctaUa;
  final String ctaEn;

  const _MotivationPhrase({
    required this.ua,
    required this.en,
    required this.ctaUa,
    required this.ctaEn,
  });
}

class _LocalizedPair {
  final String ua;
  final String en;
  const _LocalizedPair(this.ua, this.en);
}

final List<_MotivationPhrase> _motivationPhrases = _buildMotivationPhrases();

List<_MotivationPhrase> _buildMotivationPhrases() {
  const heads = [
    _LocalizedPair('Грай', 'Play'),
    _LocalizedPair('Тренуйся', 'Train'),
    _LocalizedPair('Створюй моменти', 'Create moments'),
    _LocalizedPair('Палаєш', 'Burn bright'),
    _LocalizedPair('Дихай грою', 'Breathe the game'),
    _LocalizedPair('Керуєш темпом', 'Command the tempo'),
  ];
  const tails = [
    _LocalizedPair('на повну — поле відповість.', 'at full volume — the pitch will answer.'),
    _LocalizedPair('без страху — FLAP прикриє тил.', 'fearless — FLAP guards your back.'),
    _LocalizedPair('як чемпіон щодня.', 'like a champion every day.'),
    _LocalizedPair('з холодною головою й гарячим серцем.', 'with a cool head and a blazing heart.'),
    _LocalizedPair('тут і зараз — без пауз.', 'here and now — no pauses.'),
    _LocalizedPair('на рівні свого майбутнього.', 'at the level of your future self.'),
    _LocalizedPair('з повнотою контролю.', 'with total control.'),
    _LocalizedPair('у ритмі міста.', 'in the rhythm of the city.'),
    _LocalizedPair('за межами комфорту.', 'beyond the comfort zone.'),
    _LocalizedPair('якщо хочеш легендарних цифр.', 'if you want legendary numbers.'),
  ];
  const ctas = [
    _LocalizedPair('Полюй на моменти', 'Hunt the moments'),
    _LocalizedPair('Запалюй гру', 'Ignite the game'),
    _LocalizedPair('Будь голосом команди', 'Be the team\'s voice'),
    _LocalizedPair('Приймай сміливі рішення', 'Make bold calls'),
    _LocalizedPair('Бий точно по цілі', 'Strike with intent'),
    _LocalizedPair('Заряджай стрічку відео', 'Charge the video feed'),
    _LocalizedPair('Кидай виклик собі', 'Challenge yourself'),
    _LocalizedPair('Грай для історії', 'Play for the story'),
    _LocalizedPair('Тримай темп лідера', 'Hold the leader tempo'),
    _LocalizedPair('Веди за собою', 'Lead the run'),
  ];

  final result = <_MotivationPhrase>[];
  var ctaIndex = 0;
  for (final head in heads) {
    for (final tail in tails) {
      final cta = ctas[ctaIndex % ctas.length];
      result.add(
        _MotivationPhrase(
          ua: '${head.ua} ${tail.ua}',
          en: '${head.en} ${tail.en}',
          ctaUa: cta.ua,
          ctaEn: cta.en,
        ),
      );
      ctaIndex++;
      if (result.length == 60) {
        return result;
      }
    }
  }
  return result;
}