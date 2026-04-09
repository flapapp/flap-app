import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'package:flap_app/core/storage/supabase_avatar_storage.dart';
import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/models/badge.dart' as app_badge;
import 'package:flap_app/features/badges/domain/repositories/badge_repository.dart';
import 'package:flap_app/features/friends/data/friends_service.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/teams/data/team_service.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/features/teams/presentation/screens/team_details_screen.dart';
import 'package:flap_app/widgets/video_preview_box.dart';
import 'package:flap_app/features/videos/presentation/screens/video_player_screen.dart';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final String? playerName;

  const PlayerProfileScreen({Key? key, required this.playerId, this.playerName})
    : super(key: key);

  @override
  _PlayerProfileScreenState createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final TeamService _teamService = TeamService();
  Map<String, dynamic>? playerData;
  List<Map<String, dynamic>> playerVideos = [];
  bool isLoading = true;
  final FriendsService _friendsService = FriendsService();
  bool _isSendingRequest = false;
  // Пікер та локальний буфер аватару
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedAvatar; // web-safe файл
  bool _uploadingAvatar = false;
  final NotificationService _notificationService = NotificationService();
  List<String> _myVideoIds = [];
  bool _loadingMyVideos = false;
  double _winRate = 0.0;
  int _wins = 0;
  int _draws = 0;
  int _losses = 0;
  int _matchesPlayed = 0;
  List<String> _recentResults = const ['-', '-', '-', '-', '-'];
  List<String> _userBadgeIds = [];
  List<app_badge.Badge> _userBadges = [];
  int _badgeEndorseVersion = 0;
  List<AppTeam> _playerTeams = [];
  bool _loadingTeams = false;
  // Опції як у реєстрації
  List<String> get _positions => [
    'Воротар'.i18n('Goalkeeper'),
    'Захисник'.i18n('Defender'),
    'Півзахисник'.i18n('Midfielder'),
    'Нападник'.i18n('Forward'),
    'Універсал'.i18n('Utility player'),
  ];
  List<String> get _experiences => [
    'Початківець'.i18n('Beginner'),
    'Аматор'.i18n('Amateur'),
    'Досвідчений'.i18n('Experienced'),
    'Професіонал'.i18n('Professional'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlayerData());
  }

  Future<void> _loadPlayerData() async {
    try {
      // Завантажити дані гравця
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.playerId)
          .get();

      if (userDoc.exists) {
        playerData = userDoc.data();
      }
      // Win Rate + останні 5 результатів
      final stats = await _loadMatchStats(widget.playerId);
      _winRate = (stats['winRate'] as num?)?.toDouble() ?? 0.0;
      _wins = (stats['wins'] as num?)?.toInt() ?? 0;
      _draws = (stats['draws'] as num?)?.toInt() ?? 0;
      _losses = (stats['losses'] as num?)?.toInt() ?? 0;
      _matchesPlayed = (stats['matches'] as num?)?.toInt() ?? 0;
      _recentResults = List<String>.from(
        stats['recentResults'] ?? const ['-', '-', '-', '-', '-'],
      );

      // Бейджі гравця
      try {
        if (!mounted) return;
        final badgeObjects = await context
            .read<BadgeRepository>()
            .getUserBadgeObjects(widget.playerId);
        _userBadges = badgeObjects;
        _userBadgeIds = badgeObjects.map((b) => b.id).toList();
      } catch (_) {}

      // Завантажити відео гравця (simplified query to avoid index issues)
      final videosQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: widget.playerId)
          .limit(10)
          .get();

      playerVideos = videosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort on client side to avoid index requirement
      playerVideos.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      await _loadPlayerTeams();

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading player data: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadPlayerTeams() async {
    if (!mounted) return;
    setState(() => _loadingTeams = true);
    try {
      final teams = await _teamService.fetchUserTeams(widget.playerId);
      if (mounted) {
        setState(() => _playerTeams = teams);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _playerTeams = []);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingTeams = false);
      }
    }
  }

  Future<Map<String, dynamic>> _loadMatchStats(String userId) async {
    try {
      final base = FirebaseFirestore.instance
          .collection('matches')
          .where('participants', arrayContains: userId);

      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await base
            .where('status', isEqualTo: 'finished')
            .orderBy('updatedAt', descending: true)
            .limit(20)
            .get();
      } catch (_) {
        try {
          snap = await base
              .where('status', isEqualTo: 'finished')
              .limit(20)
              .get();
        } catch (_) {
          snap = await base.limit(20).get();
        }
      }

      int wins = 0, draws = 0, losses = 0;
      final List<String> recent = [];

      final docs = [...snap.docs]
        ..sort((a, b) {
          final dataA = a.data();
          final dataB = b.data();
          final tsA =
              (dataA['finishedAt'] as Timestamp?) ??
              (dataA['updatedAt'] as Timestamp?) ??
              Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
          final tsB =
              (dataB['finishedAt'] as Timestamp?) ??
              (dataB['updatedAt'] as Timestamp?) ??
              Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
          return tsB.compareTo(tsA);
        });

      for (final d in docs) {
        final data = d.data();

        int? aOpt = data['teamAScore'] as int?;
        int? bOpt = data['teamBScore'] as int?;
        int a = aOpt ?? 0, b = bOpt ?? 0;

        if (aOpt == null || bOpt == null) {
          final r = (data['result'] ?? '').toString();
          if (r == 'teamAWins') {
            a = 1;
            b = 0;
          } else if (r == 'teamBWins') {
            a = 0;
            b = 1;
          } else if (r == 'draw') {
            a = 0;
            b = 0;
          } else {
            continue;
          }
        }

        final teamA = List<String>.from(
          (data['teamA']?['playerIds'] ?? const []),
        );
        final teamB = List<String>.from(
          (data['teamB']?['playerIds'] ?? const []),
        );
        bool isA = teamA.contains(userId);
        if (!isA && teamA.isEmpty && teamB.isEmpty) {
          final parts = List<String>.from(data['participants'] ?? const []);
          if (parts.isNotEmpty) {
            final half = (parts.length / 2).ceil();
            isA = parts.take(half).contains(userId);
          }
        }

        String res;
        if (a == b) {
          draws++;
          res = 'D';
        } else if ((isA && a > b) || (!isA && b > a)) {
          wins++;
          res = 'W';
        } else {
          losses++;
          res = 'L';
        }

        if (recent.length < 5) recent.add(res);
      }

      final total = wins + draws + losses;
      final rate = total > 0 ? (wins / total) * 100 : 0.0;
      while (recent.length < 5) recent.add('-');
      return {
        'winRate': rate,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'matches': total,
        'recentResults': recent,
      };
    } catch (_) {
      return {
        'winRate': 0.0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'matches': 0,
        'recentResults': const ['-', '-', '-', '-', '-'],
      };
    }
  }

  Future<void> _loadMyVideosForRequest() async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;
    if (!mounted) return;
    setState(() {
      _loadingMyVideos = true;
    });
    try {
      final qs = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: currentUser.id)
          .limit(50)
          .get();
      _myVideoIds = qs.docs.map((d) => d.id).toList();
    } catch (_) {}
    if (!mounted) return;
    if (mounted) {
      setState(() {
        _loadingMyVideos = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        if (!mounted) return;
        setState(() => _pickedAvatar = image);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Помилка вибору фото: $e', 'Photo selection error: $e'),
          ),
        ),
      );
    }
  }

  Future<String?> _uploadAvatarToStorage(String userId, XFile file) async {
    if (!mounted) return null; // guard перед setState
    if (_uploadingAvatar && !mounted) return null;

    try {
      setState(() => _uploadingAvatar = true);

      final Uint8List bytes = await file.readAsBytes();
      final url = await SupabaseAvatarStorage.uploadAvatar(
        userId: userId,
        bytes: bytes,
      );
      return url;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Помилка завантаження: $e', 'Upload error: $e'),
          ),
        ),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _showRateMeDialog() async {
    if (!mounted) return;
    final parentContext = context;
    bool dialogClosed = false;

    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;

    await _loadMyVideosForRequest();
    if (_myVideoIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
            'Немає ваших відео для запиту оцінки'.i18n(
              'No videos available for a rating request',
            ),
          ),
        ),
      );
      return;
    }

    final qs = await FirebaseFirestore.instance
        .collection('videos')
        .where('userId', isEqualTo: currentUser.id)
        .limit(50)
        .get();
    final videos = qs.docs
        .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
        .toList();
    final selected = <String>{};

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          void safeDialogSetState(VoidCallback fn) {
            if (dialogClosed) return;
            setStateDialog(fn);
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: Text(
              'Оберіть мої відео для оцінки'.i18n('Select my videos to rate'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _loadingMyVideos
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4caf50),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final v = videos[index];
                        final id = (v['id'] ?? '').toString();
                        final title = (v['title'] ?? 'Відео'.i18n('Video'))
                            .toString();
                        final isSel = selected.contains(id);
                        return CheckboxListTile(
                          value: isSel,
                          onChanged: (val) => safeDialogSetState(() {
                            if (val == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                          title: Text(
                            title,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dialogClosed = true;
                  Navigator.pop(ctx, false);
                },
                child: Text(
                  I18n.t('cancel'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        final meDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.id)
                            .get();
                        if (dialogClosed) return;
                        final myName =
                            (meDoc.data()?['displayName'] ??
                                    meDoc.data()?['name'] ??
                                    'Користувач'.i18n('User'))
                                .toString();
                        await _notificationService.sendRatingRequest(
                          toUserIds: [widget.playerId],
                          fromUserName: myName,
                          videoIds: selected.toList(),
                        );
                        if (!mounted || dialogClosed) return;
                        dialogClosed = true;
                        Navigator.pop(ctx, true);
                        if (!mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Запит на оцінку надіслано'.i18n(
                                '✅ Rating request sent',
                              ),
                            ),
                          ),
                        );
                      },
                child: Text('Надіслати'.i18n('Send')),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      dialogClosed = true;
    });
  }

  Future<bool> _areFriends() async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return false;

    try {
      return await _friendsService.areUsersFriends(
        currentUser.id,
        widget.playerId,
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasPendingRequest() async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return false;

    try {
      // Check outgoing requests
      final outgoingRequests = await _friendsService
          .getOutgoingFriendRequests()
          .first;
      return outgoingRequests.any(
        (request) => request.toUserId == widget.playerId,
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendFriendRequest() async {
    try {
      if (!mounted) return;
      setState(() {
        _isSendingRequest = true;
      });

      await _friendsService.sendFriendRequest(widget.playerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Запрошення надіслано!'.i18n('✅ Invitation sent!')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isSendingRequest = false;
      });
    }
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          rating > index
              ? (rating > index + 0.5 ? Icons.star : Icons.star_half)
              : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  String _localizedPosition(String? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();

    switch (value) {
      case 'воротар':
      case 'goalkeeper':
        return I18n.inline('Воротар', 'Goalkeeper');

      case 'захисник':
      case 'defender':
        return I18n.inline('Захисник', 'Defender');

      case 'півзахисник':
      case 'midfielder':
        return I18n.inline('Півзахисник', 'Midfielder');

      case 'нападник':
      case 'forward':
        return I18n.inline('Нападник', 'Forward');

      case 'універсал':
      case 'utility player':
        return I18n.inline('Універсал', 'Utility player');

      default:
        return (raw ?? '').toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.playerName ?? 'Профіль гравця'.i18n('Player profile'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
        ),
      );
    }

    if (playerData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            I18n.t('profile_not_found'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Text(
            'Профіль гравця не знайдено'.i18n('Player profile not found'),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final displayName =
        (playerData!['displayName'] ??
                playerData!['name'] ??
                playerData!['authorName'] ??
                playerData!['email']?.toString().split('@').first ??
                I18n.t('player'))
            .toString();
    final position = _localizedPosition(playerData!['position']?.toString());
    final experience = playerData!['experience'] ?? '';
    final city = playerData!['city'] ?? '';
    final rating = (playerData!['rating'] ?? 0.0).toDouble();
    final matchesFromProfile =
        ((playerData!['totalMatches'] ??
                    playerData!['matches'] ??
                    playerData!['matchesPlayed'] ??
                    0)
                as num)
            .toInt();
    final averageRating = (playerData!['averageRating'] ?? rating).toDouble();
    final winsFromProfile =
        ((playerData!['wins'] ?? playerData!['wonMatches'] ?? 0) as num)
            .toInt();
    final lossesFromProfile =
        ((playerData!['losses'] ?? playerData!['lostMatches'] ?? 0) as num)
            .toInt();
    final drawsFromProfile =
        ((playerData!['draws'] ?? playerData!['drawMatches'] ?? 0) as num)
            .toInt();
    final goals = ((playerData!['goals'] ?? 0) as num).toInt();
    final avatarUrl =
        (playerData!['avatarUrl'] ??
                playerData!['avatar'] ??
                playerData!['photoUrl'] ??
                '')
            .toString();

    final wins = _wins > 0 ? _wins : winsFromProfile;
    final draws = _draws > 0 ? _draws : drawsFromProfile;
    final losses = _losses > 0 ? _losses : lossesFromProfile;
    final matches = _matchesPlayed > 0 ? _matchesPlayed : matchesFromProfile;

    final me = AppAuthContext.userId;
    final isOwnProfile = me != null && widget.playerId == me;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.playerName ?? 'Профіль гравця'.i18n('Player profile'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Аватар
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                child: avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildDefaultAvatar(displayName),
                      )
                    : _buildDefaultAvatar(displayName),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (position.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚽ $position',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 12),
            if (city.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(city, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            const SizedBox(height: 20),

            // Рейтинг
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    rating.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    I18n.t('overall_rating'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    value: matches.toString(),
                    label: 'Матчі'.i18n('Matches'),
                    icon: Icons.sports_soccer,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    value: averageRating.toStringAsFixed(2),
                    label: 'Середня'.i18n('Average'),
                    icon: Icons.star_border,
                    color: const Color(0xFFFFD54F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    value: '${_winRate.toStringAsFixed(0)}%',
                    label: 'Win rate',
                    icon: Icons.percent,
                    color: const Color(0xFF64B5F6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    value: goals.toString(),
                    label: I18n.inline('Голи', 'Goals'),
                    icon: Icons.sports,
                    color: const Color(0xFFFF7043),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _resultChip('W', wins, Colors.greenAccent),
                const SizedBox(width: 8),
                _resultChip('L', losses, Colors.redAccent),
                const SizedBox(width: 8),
                _resultChip('D', draws, Colors.orangeAccent),
              ],
            ),

            // Win Rate + останні 5
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.percent,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Win Rate: ${_winRate.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _recentResults.map((r) {
                      Color c;
                      if (r == 'W')
                        c = const Color(0xFF4CAF50);
                      else if (r == 'D')
                        c = Colors.grey;
                      else if (r == 'L')
                        c = Colors.red;
                      else
                        c = Colors.grey;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: c, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            r,
                            style: TextStyle(
                              color: c,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_loadingTeams)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_playerTeams.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  I18n.inline('Команди', 'Teams'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _playerTeams.length,
                  itemBuilder: (context, index) {
                    final team = _playerTeams[index];
                    return _MiniTeamCard(
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
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Кнопки (приховані на власному профілі)
            Builder(
              builder: (context) {
                final me = AppAuthContext.userId;
                final isOwnProfile = me != null && widget.playerId == me;
                if (isOwnProfile) return const SizedBox.shrink();

                return FutureBuilder<Map<String, bool>>(
                  future: Future.wait([_areFriends(), _hasPendingRequest()])
                      .then((results) {
                        return {
                          'isFriend': results[0],
                          'hasPendingRequest': results[1],
                        };
                      }),
                  builder: (context, snapshot) {
                    final data =
                        snapshot.data ??
                        {'isFriend': false, 'hasPendingRequest': false};
                    final isFriend = data['isFriend']!;
                    final hasPendingRequest = data['hasPendingRequest']!;

                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                isFriend ||
                                    hasPendingRequest ||
                                    _isSendingRequest
                                ? null
                                : () => _sendFriendRequest(),
                            icon: Icon(
                              isFriend
                                  ? Icons.people
                                  : hasPendingRequest
                                  ? Icons.schedule
                                  : Icons.person_add,
                            ),
                            label: Text(
                              isFriend
                                  ? I18n.t('friends')
                                  : hasPendingRequest
                                  ? 'Запрошення надіслано'.i18n(
                                      'Invitation sent',
                                    )
                                  : _isSendingRequest
                                  ? 'Надсилання...'.i18n('Sending...')
                                  : 'Додати в друзі'.i18n('Add friend'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4caf50),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: hasPendingRequest
                                  ? Colors.orange.withOpacity(0.4)
                                  : Colors.grey.withOpacity(0.4),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _showInviteToChallengeDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.12),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Icon(Icons.emoji_events, size: 16),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _showRateMeDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4caf50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text('Оціни мене'.i18n('Rate me')),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            // Бейджі
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.t('badges'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_userBadges.isEmpty)
                    Text(
                      'Бейджів поки немає'.i18n('No badges yet'),
                      style: const TextStyle(color: Colors.white54),
                    )
                  else
                    SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _userBadges.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final badge = _userBadges[i];
                          final catColor = Color(badge.categoryColor);
                          return GestureDetector(
                            onTap: () => _endorseBadge(widget.playerId, badge),
                            child: Container(
                              width: 160,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: catColor.withOpacity(0.2),
                                      border: Border.all(
                                        color: catColor.withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        badge.emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          badge.localizedName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: catColor.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: catColor.withOpacity(0.45),
                                            ),
                                          ),
                                          child: Text(
                                            badge.rarityText,
                                            style: TextStyle(
                                              color: catColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FutureBuilder<Map<String, dynamic>>(
                                          key: ValueKey(
                                            'endorse-${badge.id}-$_badgeEndorseVersion',
                                          ),
                                          future: _getBadgeEndorsementInfo(
                                            widget.playerId,
                                            badge.id,
                                          ),
                                          builder: (context, snapshot) {
                                            final count =
                                                snapshot.data?['count']
                                                    as int? ??
                                                0;
                                            final endorsed =
                                                snapshot.data?['endorsed']
                                                    as bool? ??
                                                false;
                                            return Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: endorsed
                                                        ? catColor.withOpacity(
                                                            0.25,
                                                          )
                                                        : Colors.white
                                                              .withOpacity(
                                                                0.12,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: endorsed
                                                          ? catColor
                                                          : Colors.white24,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.thumb_up,
                                                        size: 11,
                                                        color: endorsed
                                                            ? catColor
                                                            : Colors.white70,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        count.toString(),
                                                        style: TextStyle(
                                                          color: endorsed
                                                              ? catColor
                                                              : Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (endorsed) ...[
                                                  const SizedBox(width: 3),
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.greenAccent,
                                                    size: 13,
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Відео гравця
            if (playerVideos.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  I18n.t('videos'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: playerVideos.length,
                  itemBuilder: (context, index) {
                    final v = playerVideos[index];
                    final thumb = (v['thumbnailUrl'] ?? '').toString();
                    final vUrl = (v['videoUrl'] ?? '').toString();
                    final title = (v['title'] ?? 'Відео'.i18n('Video'))
                        .toString();
                    return SizedBox(
                      width: 170,
                      child: VideoPreviewBox(
                        videoUrl: vUrl,
                        thumbnailUrl: thumb.isNotEmpty ? thumb : null,
                        borderRadius: 12,
                        onTap: () {
                          if (vUrl.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(
                                videoUrl: vUrl,
                                title: title,
                                authorName: displayName,
                                videoId: (v['id'] ?? '').toString(),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Поки що немає відео'.i18n('No videos yet'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _statBox({
    required String value,
    required String label,
    IconData? icon,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? Colors.white70, size: 18),
            const SizedBox(height: 4),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
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
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWebVideoPreview(String videoUrl) {
    return FutureBuilder<VideoPlayerController>(
      future: _createVideoController(videoUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.value.isInitialized) {
          final controller = snapshot.data!;
          return AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );
        }
        return Container(
          color: Colors.black54,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4caf50),
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }

  Future<VideoPlayerController> _createVideoController(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();
    await controller.seekTo(const Duration(seconds: 1));
    await controller.pause();
    return controller;
  }

  Future<void> _showInviteToChallengeDialog() async {
    if (!mounted) return;
    final parentContext = context;
    bool dialogClosed = false;

    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;

    try {
      final repo = parentContext.read<ChallengeRepository>();
      final streamed = await repo.watchChallenges(limit: 200).first;

      final all = streamed
          .where((c) => c.creatorId == currentUser.id)
          .where((c) => !c.participants.contains(widget.playerId))
          .toList();

      if (all.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'Немає доступних ваших челенджів для запрошення.'.i18n(
                'No available challenges to invite.',
              ),
            ),
          ),
        );
        return;
      }

      int selectedIndex = -1;
      await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            void safeDialogSetState(VoidCallback fn) {
              if (dialogClosed) return;
              setStateDialog(fn);
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              title: Text(
                'Запросити до челенджу'.i18n('Invite to challenge'),
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: all.length,
                  itemBuilder: (context, index) {
                    final c = all[index];
                    return RadioListTile<int>(
                      value: index,
                      groupValue: selectedIndex,
                      onChanged: (v) =>
                          safeDialogSetState(() => selectedIndex = v ?? -1),
                      title: Text(
                        c.title.isNotEmpty
                            ? c.title
                            : 'Челендж'.i18n('Challenge'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Учасників: ${c.participants.length}'.i18n(
                          'Participants: ${c.participants.length}',
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogClosed = true;
                    Navigator.pop(ctx, false);
                  },
                  child: Text(
                    I18n.t('cancel'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedIndex < 0
                      ? null
                      : () async {
                          final me = AppAuthContext.userId;
                          if (me == null || widget.playerId == me) return;
                          final selected = all[selectedIndex];
                          final ok = await _notificationService
                              .sendChallengeInvitation(
                                toUserId: widget.playerId,
                                challengeId: selected.id,
                                challengeTitle: selected.title.isNotEmpty
                                    ? selected.title
                                    : 'Челендж'.i18n('Challenge'),
                                creatorName:
                                    (playerData?['displayName'] ??
                                            'Користувач'.i18n('User'))
                                        .toString(),
                                challengeType:
                                    challengeTypeToSlug(selected.type),
                              );
                          if (!mounted || dialogClosed) return;
                          dialogClosed = true;
                          Navigator.pop(ctx, true);
                          if (!mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '✅ Запрошення надіслано'.i18n(
                                        '✅ Invitation sent',
                                      )
                                    : '❌ Не вдалося надіслати'.i18n(
                                        '❌ Failed to send',
                                      ),
                              ),
                            ),
                          );
                        },
                  child: Text('Запросити'.i18n('Invite')),
                ),
              ],
            );
          },
        ),
      ).whenComplete(() {
        dialogClosed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
      );
    }
  }

  // Універсальний текстовий інпут для форм модалки
  Widget _textField(
    String label,
    TextEditingController c, {
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4caf50)),
        ),
      ),
      validator: requiredField
          ? (v) => (v == null || v.trim().isEmpty)
                ? 'Обов’язкове поле'.i18n('This field is required')
                : null
          : null,
    );
  }

  Future<Map<String, dynamic>> _getBadgeEndorsementInfo(
    String userId,
    String badgeId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badge_endorsements')
          .doc(badgeId)
          .get();
      final currentUid = AppAuthContext.userId;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final endorsers = List<String>.from(data['endorsers'] ?? []);
        final endorsed = currentUid != null && endorsers.contains(currentUid);
        return {'count': endorsers.length, 'endorsed': endorsed};
      }
      return {'count': 0, 'endorsed': false};
    } catch (_) {
      return {'count': 0, 'endorsed': false};
    }
  }

  Future<void> _endorseBadge(String ownerId, app_badge.Badge badge) async {
    final currentUserId = AppAuthContext.userId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Увійдіть, щоб підтверджувати бейджі'.i18n(
              'Sign in to endorse badges',
            ),
          ),
        ),
      );
      return;
    }
    if (currentUserId == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не можна підтверджувати власні бейджі'.i18n(
              'You cannot endorse your own badges',
            ),
          ),
        ),
      );
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('badge_endorsements')
        .doc(badge.id);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        List<String> endorsers = [];
        if (snap.exists) {
          endorsers = List<String>.from(snap.data()?['endorsers'] ?? []);
        }
        if (endorsers.contains(currentUserId)) {
          throw Exception('already-endorsed');
        }
        endorsers.add(currentUserId);
        tx.set(ref, {
          'endorsers': endorsers,
          'lastEndorsedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentName =
          currentUserDoc.data()?['displayName'] ??
          currentUserDoc.data()?['name'] ??
          'Користувач'.i18n('User');

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': ownerId,
        'type': 'badgeEndorsed',
        'title': 'Підтвердження бейджу'.i18n('Badge endorsement'),
        'message': I18n.inline(
          '$currentName підтвердив ваш бейдж "${badge.localizedName}"',
          '$currentName confirmed your badge "${badge.localizedName}"',
        ),
        'data': {'badgeId': badge.id},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              '✅ Ви підтвердили бейдж "${badge.localizedName}"',
              '✅ You endorsed the badge "${badge.localizedName}"',
            ),
          ),
        ),
      );
      setState(() {
        _badgeEndorseVersion++;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('already-endorsed')
          ? 'Ви вже підтвердили цей бейдж'.i18n(
              'You already endorsed this badge',
            )
          : 'Помилка підтвердження'.i18n('Endorsement error');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _MiniTeamCard extends StatelessWidget {
  final AppTeam team;
  final VoidCallback? onTap;

  const _MiniTeamCard({required this.team, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teamStats')
          .doc(team.id)
          .snapshots(),
      builder: (context, snapshot) {
        final stats = snapshot.data?.data() ?? const <String, dynamic>{};

        final wins = (stats['wins'] as num?)?.toInt() ?? team.wins;
        final losses = (stats['losses'] as num?)?.toInt() ?? team.losses;
        final draws = (stats['draws'] as num?)?.toInt() ?? team.draws;

        final total = wins + losses + draws;
        final winRate = total > 0
            ? ((wins / total) * 100).toStringAsFixed(0)
            : '0';

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 190,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF4caf50),
                      backgroundImage:
                          team.logoUrl != null && team.logoUrl!.isNotEmpty
                          ? NetworkImage(team.logoUrl!)
                          : null,
                      child: (team.logoUrl == null || team.logoUrl!.isEmpty)
                          ? Text(
                              team.name.isNotEmpty
                                  ? team.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            I18n.inline(
                              '${team.memberIds.length} гравців',
                              '${team.memberIds.length} players',
                            ),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
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
                    _teamChip('W', wins, Colors.greenAccent),
                    _teamChip('L', losses, Colors.redAccent),
                    _teamChip('D', draws, Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  I18n.inline('Win rate: $winRate%', 'Win rate: $winRate%'),
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _teamChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
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
