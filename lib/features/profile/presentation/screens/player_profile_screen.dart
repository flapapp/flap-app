import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/matches/domain/repositories/matches_repository.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/models/badge.dart' as app_badge;
import 'package:flap_app/features/badges/domain/repositories/badge_repository.dart';
import 'package:flap_app/features/friends/domain/friend_failure.dart';
import 'package:flap_app/features/friends/domain/repositories/friends_repository.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/teams/domain/repositories/teams_repository.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/features/teams/presentation/screens/team_details_screen.dart';
import 'package:flap_app/widgets/video_preview_box.dart';
import 'package:flap_app/features/videos/presentation/screens/video_player_screen.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/media/flap_cached_image.dart';
import 'package:flap_app/core/theme/app_colors.dart';
import 'package:flap_app/core/theme/app_spacing.dart';
import 'package:flap_app/shared/ui/app_button.dart';
import 'package:flap_app/shared/ui/app_card.dart';
import 'package:flap_app/shared/ui/app_scaffold.dart';
import 'package:flap_app/shared/ui/app_top_bar.dart';

/// Win/draw/loss stats from Supabase-backed [Match] rows (same rules as legacy Firestore).
Map<String, dynamic> _aggregateMatchStatsForUser(
  List<Match> userMatches,
  String userId,
) {
  final finished = userMatches
      .where((m) => m.status == MatchStatus.finished)
      .toList()
    ..sort((a, b) {
      final ta = a.finishedAt ?? a.updatedAt;
      final tb = b.finishedAt ?? b.updatedAt;
      return tb.compareTo(ta);
    });
  final docs = finished.take(20).toList();

  int wins = 0, draws = 0, losses = 0;
  final List<String> recent = [];

  for (final data in docs) {
    int? aOpt = data.teamAScore;
    int? bOpt = data.teamBScore;
    int a = aOpt ?? 0, b = bOpt ?? 0;

    if (aOpt == null || bOpt == null) {
      final r = data.result;
      if (r == MatchResult.teamAWins) {
        a = 1;
        b = 0;
      } else if (r == MatchResult.teamBWins) {
        a = 0;
        b = 1;
      } else if (r == MatchResult.draw) {
        a = 0;
        b = 0;
      } else {
        continue;
      }
    }

    final teamA = List<String>.from(data.teamA?.playerIds ?? const []);
    final teamB = List<String>.from(data.teamB?.playerIds ?? const []);
    bool isA = teamA.contains(userId);
    if (!isA && teamA.isEmpty && teamB.isEmpty) {
      final parts = List<String>.from(data.participants);
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

    if (recent.length < 5) {
      recent.add(res);
    }
  }

  final total = wins + draws + losses;
  final rate = total > 0 ? (wins / total) * 100 : 0.0;
  while (recent.length < 5) {
    recent.add('-');
  }
  return {
    'winRate': rate,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'matches': total,
    'recentResults': recent,
  };
}

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
  Map<String, dynamic>? playerData;
  List<Map<String, dynamic>> playerVideos = [];
  bool isLoading = true;
  bool _isSendingRequest = false;
  final NotificationService _notificationService = NotificationService();
  List<String> _myVideoIds = [];
  List<Map<String, dynamic>> _myVideoMapsForRequest = [];
  bool _loadingMyVideos = false;
  double _winRate = 0.0;
  int _wins = 0;
  int _draws = 0;
  int _losses = 0;
  int _matchesPlayed = 0;
  List<String> _recentResults = const ['-', '-', '-', '-', '-'];
  List<app_badge.Badge> _userBadges = [];
  List<AppTeam> _playerTeams = [];
  bool _loadingTeams = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlayerData());
  }

  Future<void> _loadPlayerData() async {
    try {
      playerData = await context
          .read<ProfileRepository>()
          .fetchLegacyUserMap(widget.playerId);
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
      } catch (_) {}

      if (!mounted) return;
      final videoRows = await context
          .read<VideosRepository>()
          .watchLibraryVideos(forUserId: widget.playerId, limit: 50)
          .first;
      final sortedVideos = [...videoRows]..sort((a, b) {
          final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
      playerVideos = sortedVideos
          .take(10)
          .map((v) => v.toLegacyCardMap())
          .toList();

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
      final teams =
          await context.read<TeamsRepository>().fetchUserTeams(widget.playerId);
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
    if (!mounted) {
      return {
        'winRate': 0.0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'matches': 0,
        'recentResults': const ['-', '-', '-', '-', '-'],
      };
    }
    try {
      final all =
          await context.read<MatchesRepository>().getUserMatches(userId).first;
      if (!mounted) {
        return {
          'winRate': 0.0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
          'matches': 0,
          'recentResults': const ['-', '-', '-', '-', '-'],
        };
      }
      return _aggregateMatchStatsForUser(all, userId);
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
      final rows = await context
          .read<VideosRepository>()
          .watchLibraryVideos(forUserId: currentUser.id, limit: 50)
          .first;
      final sorted = [...rows]..sort((a, b) {
          final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
      _myVideoIds = sorted.map((v) => v.id).toList();
      _myVideoMapsForRequest = sorted.map((v) => v.toLegacyCardMap()).toList();
    } catch (_) {}
    if (!mounted) return;
    if (mounted) {
      setState(() {
        _loadingMyVideos = false;
      });
    }
  }

  Future<void> _showRateMeDialog() async {
    if (!mounted) return;
    final parentContext = context;
    bool dialogClosed = false;

    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;

    final profileRepo = parentContext.read<UserProfileRepository>();

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

    final videos = _myVideoMapsForRequest;
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
                        final meProfile =
                            await profileRepo.loadProfile(currentUser.id);
                        if (dialogClosed) return;
                        final myName = meProfile?.resolveDisplayName().isNotEmpty ==
                                true
                            ? meProfile!.resolveDisplayName()
                            : 'Користувач'.i18n('User');
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
      return await context.read<FriendsRepository>().areUsersFriends(
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
      final outgoingRequests = await context
          .read<FriendsRepository>()
          .watchOutgoingFriendRequests()
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

      await context.read<FriendsRepository>().sendFriendRequest(widget.playerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Запрошення надіслано!'.i18n('✅ Invitation sent!')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } on FriendFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });
      }
    }
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
      return AppScaffold(
        appBar: AppTopBar(
          title: widget.playerName ?? 'Профіль гравця'.i18n('Player profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary),
        ),
      );
    }

    if (playerData == null) {
      return AppScaffold(
        appBar: AppTopBar(
          title: I18n.t('profile_not_found'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Профіль гравця не знайдено'.i18n('Player profile not found'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
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

    return AppScaffold(
      appBar: AppTopBar(
        title: widget.playerName ?? 'Профіль гравця'.i18n('Player profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppCard(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(color: AppColors.borderSubtle, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(48),
                      child: avatarUrl.isNotEmpty
                          ? FlapCachedImage(
                              imageUrl: avatarUrl,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              memCacheWidth: 192,
                              errorWidget: (_, __, ___) =>
                                  _buildDefaultAvatar(displayName),
                            )
                          : _buildDefaultAvatar(displayName),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(displayName, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  if (position.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '⚽ $position',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  if (city.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          city,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    rating.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  Text(
                    I18n.t('overall_rating'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    value: matches.toString(),
                    label: 'Матчі'.i18n('Matches'),
                    icon: Icons.sports_soccer,
                    color: AppColors.accentPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _statBox(
                    value: averageRating.toStringAsFixed(2),
                    label: 'Середня'.i18n('Average'),
                    icon: Icons.star_border,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _statBox(
                    value: '${_winRate.toStringAsFixed(0)}%',
                    label: 'Win rate',
                    icon: Icons.percent,
                    color: AppColors.accentSoft,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _statBox(
                    value: goals.toString(),
                    label: I18n.inline('Голи', 'Goals'),
                    icon: Icons.sports,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _resultChip('W', wins, AppColors.success),
                const SizedBox(width: 8),
                _resultChip('L', losses, AppColors.error),
                const SizedBox(width: 8),
                _resultChip('D', draws, AppColors.warning),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.percent,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Win Rate: ${_winRate.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
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
                      if (r == 'W') {
                        c = AppColors.success;
                      } else if (r == 'D') {
                        c = AppColors.textMuted;
                      } else if (r == 'L') {
                        c = AppColors.error;
                      } else {
                        c = AppColors.textMuted;
                      }
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
            const SizedBox(height: AppSpacing.sm),

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
                  style: Theme.of(context).textTheme.titleLarge,
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

                    return Column(
                      children: [
                        AppButton(
                          label: isFriend
                              ? I18n.t('friends')
                              : hasPendingRequest
                              ? 'Запрошення надіслано'.i18n('Invitation sent')
                              : _isSendingRequest
                              ? 'Надсилання...'.i18n('Sending...')
                              : 'Додати в друзі'.i18n('Add friend'),
                          icon: isFriend
                              ? Icons.people
                              : hasPendingRequest
                              ? Icons.schedule
                              : Icons.person_add,
                          onPressed: isFriend || hasPendingRequest || _isSendingRequest
                              ? null
                              : _sendFriendRequest,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: I18n.inline('Запросити', 'Invite'),
                                variant: AppButtonVariant.secondary,
                                icon: Icons.emoji_events,
                                onPressed: _showInviteToChallengeDialog,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: AppButton(
                                label: 'Оціни мене'.i18n('Rate me'),
                                variant: AppButtonVariant.secondary,
                                icon: Icons.star_border,
                                onPressed: _showRateMeDialog,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.t('badges'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_userBadges.isEmpty)
                    Text(
                      'Бейджів поки немає'.i18n('No badges yet'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
                                color: AppColors.bgHover,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderSubtle),
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
                                            color: AppColors.textPrimary,
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
                                          key: ValueKey('endorse-${badge.id}'),
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
                                                        : AppColors.bgElevated
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
                                                          : AppColors.borderSubtle,
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
                                                            : AppColors.textSecondary,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        count.toString(),
                                                        style: TextStyle(
                                                          color: endorsed
                                                              ? catColor
                                                              : AppColors.textPrimary,
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
                                                    color: AppColors.success,
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

            const SizedBox(height: AppSpacing.sm),

            // Відео гравця
            if (playerVideos.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  I18n.t('videos'),
                  style: Theme.of(context).textTheme.titleLarge,
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
              AppCard(
                child: Text(
                  'Поки що немає відео'.i18n('No videos yet'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
      decoration: const BoxDecoration(color: AppColors.accentPrimary),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.bgBase,
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
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? AppColors.textSecondary, size: 18),
            const SizedBox(height: 4),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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

  Future<Map<String, dynamic>> _getBadgeEndorsementInfo(
    String userId,
    String badgeId,
  ) async {
    // Badge endorsements were on Firestore; no Supabase table wired here yet.
    if (userId.isEmpty && badgeId.isEmpty) {
      return {'count': 0, 'endorsed': false};
    }
    return {'count': 0, 'endorsed': false};
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          I18n.inline(
            'Підтвердження бейджів на сервері ще не підключені.',
            'Badge endorsements are not saved to the server yet.',
          ),
        ),
      ),
    );
  }
}

class _MiniTeamCard extends StatelessWidget {
  final AppTeam team;
  final VoidCallback? onTap;

  const _MiniTeamCard({required this.team, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppTeam?>(
      stream: context.read<TeamsRepository>().watchTeam(team.id),
      builder: (context, snapshot) {
        final live = snapshot.data ?? team;
        final wins = live.wins;
        final losses = live.losses;
        final draws = live.draws;

        final total = wins + losses + draws;
        final winRate = total > 0
            ? ((wins / total) * 100).toStringAsFixed(0)
            : '0';

        return GestureDetector(
          onTap: onTap,
          child: AppCard(
            padding: const EdgeInsets.all(14),
            onTap: onTap,
            child: SizedBox(
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.accentPrimary,
                      backgroundImage:
                          live.logoUrl != null && live.logoUrl!.isNotEmpty
                          ? flapCachedImageProvider(live.logoUrl!)
                          : null,
                      child: (live.logoUrl == null || live.logoUrl!.isEmpty)
                          ? Text(
                              live.name.isNotEmpty
                                  ? live.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.bgBase,
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
                            live.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            I18n.inline(
                              '${live.memberIds.length} гравців',
                              '${live.memberIds.length} players',
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
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
