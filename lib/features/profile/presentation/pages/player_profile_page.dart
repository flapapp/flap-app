import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/football_position.dart';
import '../../../../utils/city_catalog.dart';
import '../../../teams/data/models/app_team.dart';
import '../../../badges/data/models/badge.dart' as app_badge;
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../domain/repositories/current_user_profile_avatar_repository.dart';
import '../../domain/repositories/player_badge_endorsement_repository.dart';
import '../../domain/repositories/player_challenge_invite_repository.dart';
import '../../domain/repositories/player_notification_actions_repository.dart';
import '../../domain/repositories/player_social_repository.dart';
import '../../../friends/domain/entities/friendship_state.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import '../../domain/repositories/player_videos_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/team_stats_repository.dart';
import '../../domain/usecases/commit_profile_avatar_urls_usecase.dart';
import '../../domain/usecases/load_player_profile_dashboard_usecase.dart';
import '../../../teams/presentation/pages/team_details_screen.dart';
import '../../../video/presentation/pages/video_player_screen.dart';
import '../../../../widgets/video_preview_box.dart';

@RoutePage()
class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final String? playerName;

  const PlayerProfileScreen({
    Key? key,
    required this.playerId,
    this.playerName,
  }) : super(key: key);

  @override
  _PlayerProfileScreenState createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Map<String, dynamic>? playerData;
  List<Map<String, dynamic>> playerVideos = [];
  bool isLoading = true;
  bool _isSendingRequest = false;
  int _friendshipUiEpoch = 0;
  bool _friendshipActionBusy = false;
  // Пікер та локальний буфер аватару
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedAvatar; // web-safe файл
  bool _uploadingAvatar = false;
  List<String> _myVideoIds = [];
  bool _loadingMyVideos = false;
  double _winRate = 0.0;
  int _wins = 0;
  int _draws = 0;
  int _losses = 0;
  int _matchesPlayed = 0;
  List<String> _recentResults = const ['-', '-', '-', '-', '-'];
  List<app_badge.Badge> _userBadges = [];
  int _badgeEndorseVersion = 0;
  List<AppTeam> _playerTeams = [];
  // Опції як у реєстрації
  List<String> get _positions => [
        bilingual('Воротар', 'Goalkeeper'),
        bilingual('Захисник', 'Defender'),
        bilingual('Півзахисник', 'Midfielder'),
        bilingual('Нападник', 'Forward'),
        bilingual('Універсал', 'Utility player'),
      ];
  List<String> get _experiences => [
        bilingual('Початківець', 'Beginner'),
        bilingual('Аматор', 'Amateur'),
        bilingual('Досвідчений', 'Experienced'),
        bilingual('Професіонал', 'Professional'),
      ];

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    try {
      final result = await sl<LoadPlayerProfileDashboardUseCase>()(
        LoadPlayerProfileDashboardParams(playerId: widget.playerId),
      );
      result.when(
        success: (data) {
          final profile = data.profile;
          playerData = profile?.legacyUserData;
          final stats = data.matchStats;
          _winRate = (stats['winRate'] as num?)?.toDouble() ?? 0.0;
          _wins = (stats['wins'] as num?)?.toInt() ?? 0;
          _draws = (stats['draws'] as num?)?.toInt() ?? 0;
          _losses = (stats['losses'] as num?)?.toInt() ?? 0;
          _matchesPlayed = (stats['matches'] as num?)?.toInt() ?? 0;
          _recentResults = List<String>.from(
            stats['recentResults'] ?? const ['-', '-', '-', '-', '-'],
          );
          _userBadges = data.badges;
          playerVideos = data.videos;
          _playerTeams = data.teams;
        },
        failure: (f) {
          // ignore: avoid_print
          print('Error loading player data: $f');
          playerData = null;
        },
      );
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading player data: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMyVideosForRequest() async {
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (uid == null) return;
    if (!mounted) return;
    setState(() {
      _loadingMyVideos = true;
    });
    try {
      _myVideoIds = await sl<PlayerVideosRepository>().listMyVideoIds(50);
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
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (image != null) {
      if (!mounted) return;
      setState(() => _pickedAvatar = image);
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('il_a5c2eb690c', namedArgs: {'e': e.toString()})),
      ),
    );
  }
}

  Future<String?> _uploadAvatarToStorage(XFile file) async {
    if (!mounted) return null;
    if (_uploadingAvatar) return null;

    try {
      setState(() => _uploadingAvatar = true);

      final Uint8List bytes = await file.readAsBytes();
      final uploadResult =
          await sl<CurrentUserProfileAvatarRepository>().uploadAvatarJpeg(bytes);
      final url = uploadResult.when(
        success: (u) => u,
        failure: (f) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  f.when(
                    cache: () => '',
                    network: (m) => m ?? '',
                    unexpected: (m) => m ?? '',
                    auth: (_, m) => m ?? '',
                  ),
                ),
              ),
            );
          }
          return null;
        },
      );
      if (url == null) return null;

      final commitResult = await sl<CommitProfileAvatarUrlsUseCase>()(
        CommitProfileAvatarUrlsParams(downloadUrl: url),
      );
      return commitResult.when(
        success: (_) => url,
        failure: (f) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  f.when(
                    cache: () => '',
                    network: (m) => m ?? '',
                    unexpected: (m) => m ?? '',
                    auth: (_, m) => m ?? '',
                  ),
                ),
              ),
            );
          }
          return null;
        },
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_7e1f7f4eb9', namedArgs: {'e': e.toString()}),
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

    final currentUid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (currentUid == null) return;

    await _loadMyVideosForRequest();
    if (_myVideoIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text(bilingual('Немає ваших відео для запиту оцінки', 'No videos available for a rating request'))),
      );
      return;
    }

    final videos =
        await sl<PlayerVideosRepository>().listMyVideos(50);
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
            title: Text(bilingual('Оберіть мої відео для оцінки', 'Select my videos to rate'), style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: _loadingMyVideos
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final v = videos[index];
                        final id = (v['id'] ?? '').toString();
                        final title = (v['title'] ?? bilingual('Відео', 'Video')).toString();
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
                          title: Text(title, style: const TextStyle(color: Colors.white)),
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
                child: Text(tr('cancel'), style: const TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        final meProfile =
                            await sl<ProfileRepository>().fetchUserProfile(currentUid);
                        if (dialogClosed) return;
                        final myName = (meProfile?.displayName.isNotEmpty == true
                                ? meProfile!.displayName
                                : null) ??
                            bilingual('Користувач', 'User');
                        await sl<PlayerNotificationActionsRepository>().sendRatingRequest(
                          toUserIds: [widget.playerId],
                          fromUserName: myName,
                          videoIds: selected.toList(),
                        );
                        if (!mounted || dialogClosed) return;
                        dialogClosed = true;
                        Navigator.pop(ctx, true);
                        if (!mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(content: Text(bilingual('✅ Запит на оцінку надіслано', '✅ Rating request sent'))),
                        );
                      },
                child: Text(bilingual('Надіслати', 'Send')),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      dialogClosed = true;
    });
  }

  Future<FriendshipState> _friendshipState() =>
      sl<PlayerSocialRepository>().friendshipStateWith(widget.playerId);

  Future<void> _respondToFriendRequestFromProfile(
    String requestId,
    bool accept,
  ) async {
    setState(() => _friendshipActionBusy = true);
    try {
      await sl<FriendsRepository>().respondToFriendRequest(requestId, accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? bilingual('✅ Запрошення прийнято!', '✅ Invitation accepted!')
                : bilingual('❌ Запрошення відхилено', '❌ Invitation declined'),
          ),
          backgroundColor: accept ? Colors.green : Colors.red,
        ),
      );
      setState(() => _friendshipUiEpoch++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _friendshipActionBusy = false);
    }
  }

  Future<void> _cancelOutgoingFromProfile(String requestId) async {
    setState(() => _friendshipActionBusy = true);
    try {
      await sl<FriendsRepository>().cancelFriendRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bilingual('✅ Запрошення скасовано', '✅ Invitation cancelled'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _friendshipUiEpoch++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _friendshipActionBusy = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    try {
      if (!mounted) return;
      setState(() {
        _isSendingRequest = true;
      });

      await sl<PlayerSocialRepository>().sendFriendRequest(widget.playerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bilingual('✅ Запрошення надіслано!', '✅ Invitation sent!')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _friendshipUiEpoch++);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}))),
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
          rating > index ? (rating > index + 0.5 ? Icons.star : Icons.star_half) : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
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
            widget.playerName ?? bilingual('Профіль гравця', 'Player profile'),
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
            tr('profile_not_found'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Text(
            bilingual('Профіль гравця не знайдено', 'Player profile not found'),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final displayName = (playerData!['displayName'] ?? 
                         playerData!['name'] ?? 
                         playerData!['authorName'] ?? 
                         playerData!['email']?.toString().split('@').first ?? 
                         tr('player')).toString();
    final position = positionLabelForDisplay(
      playerData!['position']?.toString(),
    );
    final cityLabel = CityCatalog.labelForDisplay(
      (playerData!['city'] ?? '').toString(),
    );
    final rating = (playerData!['rating'] ?? 0.0).toDouble();
    final matchesFromProfile = ((playerData!['totalMatches'] ?? playerData!['matches'] ?? playerData!['matchesPlayed'] ?? 0) as num).toInt();
    final averageRating = (playerData!['averageRating'] ?? rating).toDouble();
    final winsFromProfile   = ((playerData!['wins'] ?? playerData!['wonMatches']  ?? 0) as num).toInt();
    final lossesFromProfile = ((playerData!['losses'] ?? playerData!['lostMatches'] ?? 0) as num).toInt();
    final drawsFromProfile  = ((playerData!['draws'] ?? playerData!['drawMatches']  ?? 0) as num).toInt();
    final goals  = ((playerData!['goals'] ?? 0) as num).toInt();
    final avatarUrl = (playerData!['avatarUrl'] ?? playerData!['avatar'] ?? playerData!['photoUrl'] ?? '').toString();

    final wins = _wins > 0 ? _wins : winsFromProfile;
    final draws = _draws > 0 ? _draws : drawsFromProfile;
    final losses = _losses > 0 ? _losses : lossesFromProfile;
    final matches = _matchesPlayed > 0 ? _matchesPlayed : matchesFromProfile;

      return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.playerName ?? bilingual('Профіль гравця', 'Player profile'), style: const TextStyle(color: Colors.white)),
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
                    ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultAvatar(displayName))
                    : _buildDefaultAvatar(displayName),
              ),
            ),
            const SizedBox(height: 12),
            Text(displayName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (position.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('⚽ $position', style: const TextStyle(color: Colors.white)),
              ),
            const SizedBox(height: 12),
            if (cityLabel.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(cityLabel, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            const SizedBox(height: 20),

            // Рейтинг
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(rating.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                Text(tr('overall_rating'), style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statBox(value: matches.toString(), label: bilingual('Матчі', 'Matches'), icon: Icons.sports_soccer, color: const Color(0xFF4CAF50))),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: averageRating.toStringAsFixed(2), label: bilingual('Середня', 'Average'), icon: Icons.star_border, color: const Color(0xFFFFD54F))),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: '${_winRate.toStringAsFixed(0)}%', label: 'Win rate', icon: Icons.percent, color: const Color(0xFF64B5F6))),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: goals.toString(), label: tr('il_116cd3982a'), icon: Icons.sports, color: const Color(0xFFFF7043))),
            ]),
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
          const Icon(Icons.percent, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(tr('win_rate_percent', args: [_winRate.toStringAsFixed(0)]),
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _recentResults.map((r) {
          Color c;
          if (r == 'W') c = const Color(0xFF4CAF50);
          else if (r == 'D') c = Colors.grey;
          else if (r == 'L') c = Colors.red;
          else c = Colors.grey;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: c.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c, width: 1.5),
            ),
            child: Center(child: Text(r, style: TextStyle(color: c, fontWeight: FontWeight.bold))),
          );
        }).toList(),
      ),
    ],
  ),
),
const SizedBox(height: 12),

            if (_playerTeams.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('il_1e1a1c078a'),
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
                      teamStatsStream:
                          sl<TeamStatsRepository>().watchTeamStats(team.id),
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
                final me = sl<AuthSessionRepository>().peekCurrentUser?.uid;
                final isOwnProfile = me != null && widget.playerId == me;
                if (isOwnProfile) return const SizedBox.shrink();

                return FutureBuilder<FriendshipState>(
                  key: ValueKey(_friendshipUiEpoch),
                  future: _friendshipState(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Color(0xFF4caf50),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }

                    final state = snapshot.data ??
                        const FriendshipState(isFriend: false);
                    final isFriend = state.isFriend;
                    final hasOutgoing = state.hasPendingOutgoing;
                    final hasIncoming = state.hasPendingIncoming;
                    final busy = _friendshipActionBusy || _isSendingRequest;

                    Widget primaryFriendAction;
                    if (isFriend) {
                      primaryFriendAction = ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.people),
                        label: Text(tr('friends')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.grey.withOpacity(0.4),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      );
                    } else if (hasIncoming) {
                      final rid = state.incomingPendingRequestId!;
                      primaryFriendAction = Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      _respondToFriendRequestFromProfile(rid, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: Text(tr('reject')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      _respondToFriendRequestFromProfile(rid, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4caf50),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(tr('accept')),
                            ),
                          ),
                        ],
                      );
                    } else if (hasOutgoing) {
                      final rid = state.outgoingPendingRequestId!;
                      primaryFriendAction = Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                bilingual(
                                  'Запрошення надіслано',
                                  'Invitation sent',
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4caf50),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.orange.withOpacity(0.4),
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
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed:
                                busy ? null : () => _cancelOutgoingFromProfile(rid),
                            child: Text(
                              tr('cancel'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      );
                    } else {
                      primaryFriendAction = ElevatedButton.icon(
                        onPressed: busy ? null : () => _sendFriendRequest(),
                        icon: const Icon(Icons.person_add),
                        label: Text(
                          _isSendingRequest
                              ? bilingual('Надсилання...', 'Sending...')
                              : bilingual('Додати в друзі', 'Add friend'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.withOpacity(0.4),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: primaryFriendAction),
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
                          child: Text(bilingual('Оціни мене', 'Rate me')),
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
                  Text(tr('badges'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_userBadges.isEmpty)
                    Text(bilingual('Бейджів поки немає', 'No badges yet'), style: const TextStyle(color: Colors.white54))
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                      border: Border.all(color: catColor.withOpacity(0.5), width: 1.5),
                                    ),
                                    child: Center(child: Text(badge.emoji, style: const TextStyle(fontSize: 24))),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          badge.localizedName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: catColor.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: catColor.withOpacity(0.45)),
                                          ),
                                          child: Text(
                                            badge.rarityText,
                                            style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FutureBuilder<BadgeEndorsementInfo>(
                                          key: ValueKey('endorse-${badge.id}-$_badgeEndorseVersion'),
                                          future: sl<PlayerBadgeEndorsementRepository>().getEndorsementInfo(
                                            ownerUserId: widget.playerId,
                                            badgeId: badge.id,
                                            currentUserId: sl<AuthSessionRepository>().peekCurrentUser?.uid,
                                          ),
                                          builder: (context, snapshot) {
                                            final count = snapshot.data?.count ?? 0;
                                            final endorsed = snapshot.data?.endorsedByCurrentUser ?? false;
                                            return Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: endorsed ? catColor.withOpacity(0.25) : Colors.white.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: endorsed ? catColor : Colors.white24),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.thumb_up, size: 11, color: endorsed ? catColor : Colors.white70),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        count.toString(),
                                                        style: TextStyle(
                                                          color: endorsed ? catColor : Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (endorsed) ...[
                                                  const SizedBox(width: 3),
                                                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 13),
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
                child: Text(tr('videos'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
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
                    final title = (v['title'] ?? bilingual('Відео', 'Video')).toString();
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
                child: Text(bilingual('Поки що немає відео', 'No videos yet'), style: const TextStyle(color: Colors.white54)),
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
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(value.toString(), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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

  Widget _statBox({required String value, required String label, IconData? icon, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
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
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
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
            child: CircularProgressIndicator(color: Color(0xFF4caf50), strokeWidth: 2),
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

    final currentUid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (currentUid == null) return;

    try {
      final all = await sl<PlayerChallengeInviteRepository>()
          .listInvitableChallenges(
        creatorUserId: currentUid,
        targetPlayerId: widget.playerId,
      );

      if (all.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text(bilingual('Немає доступних ваших челенджів для запрошення.', 'No available challenges to invite.'))),
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
              title: Text(bilingual('Запросити до челенджу', 'Invite to challenge'), style: const TextStyle(color: Colors.white)),
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
                      onChanged: (v) => safeDialogSetState(() => selectedIndex = v ?? -1),
                      title: Text(c['title'] ?? bilingual('Челендж', 'Challenge'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        bilingual(
                          'Учасників: ${(c['participants'] as List?)?.length ?? 0}',
                          'Participants: ${(c['participants'] as List?)?.length ?? 0}',
                        ),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                  child: Text(tr('cancel'), style: const TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: selectedIndex < 0
                      ? null
                      : () async {
                          final me = sl<AuthSessionRepository>().peekCurrentUser?.uid;
                          if (me == null || widget.playerId == me) return;
                          final selected = all[selectedIndex];
                          final ok = await sl<PlayerNotificationActionsRepository>()
                              .sendChallengeInvitation(
                            toUserId: widget.playerId,
                            challengeId: (selected['id'] ?? '').toString(),
                            challengeTitle: (selected['title'] ?? bilingual('Челендж', 'Challenge')).toString(),
                            creatorName: (playerData?['displayName'] ?? bilingual('Користувач', 'User')).toString(),
                            challengeType: (selected['type'] ?? 'goal').toString(),
                          );
                          if (!mounted || dialogClosed) return;
                          dialogClosed = true;
                          Navigator.pop(ctx, true);
                          if (!mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(content: Text(ok ? bilingual('✅ Запрошення надіслано', '✅ Invitation sent') : bilingual('❌ Не вдалося надіслати', '❌ Failed to send'))),
                          );
                        },
                  child: Text(bilingual('Запросити', 'Invite')),
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
        SnackBar(content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}))),
      );
    }
  }
  // Універсальний текстовий інпут для форм модалки
  Widget _textField(String label, TextEditingController c, {bool requiredField = true}) {
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
          ? (v) => (v == null || v.trim().isEmpty) ? bilingual('Обов’язкове поле', 'This field is required') : null
          : null,
    );
  }

  Future<void> _endorseBadge(String ownerId, app_badge.Badge badge) async {
    final currentUserId = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bilingual('Увійдіть, щоб підтверджувати бейджі', 'Sign in to endorse badges'))),
      );
      return;
    }
    if (currentUserId == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bilingual('Не можна підтверджувати власні бейджі', 'You cannot endorse your own badges'))),
      );
      return;
    }

    final result = await sl<PlayerBadgeEndorsementRepository>().endorseBadge(
      ownerUserId: ownerId,
      badgeId: badge.id,
      badgeLocalizedName: badge.localizedName,
      endorserUserId: currentUserId,
    );

    result.when(
      success: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('il_67089ac557', args: [badge.localizedName]),
            ),
          ),
        );
        setState(() {
          _badgeEndorseVersion++;
        });
      },
      failure: (f) {
        if (!mounted) return;
        final message = f.when(
          cache: () => bilingual('Помилка підтвердження', 'Endorsement error'),
          network: (m) => m ?? bilingual('Помилка мережі', 'Network error'),
          unexpected: (m) =>
              m ?? bilingual('Помилка підтвердження', 'Endorsement error'),
          auth: (_, m) => m ?? bilingual('Помилка авторизації', 'Auth error'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }
}

class _MiniTeamCard extends StatelessWidget {
  final AppTeam team;
  final Stream<Map<String, dynamic>?> teamStatsStream;
  final VoidCallback? onTap;

  const _MiniTeamCard({
    required this.team,
    required this.teamStatsStream,
    this.onTap,
  });

 @override
Widget build(BuildContext context) {
  return StreamBuilder<Map<String, dynamic>?>(
    stream: teamStatsStream,
    builder: (context, snapshot) {
      final stats = snapshot.data ?? const <String, dynamic>{};

      final wins = (stats['wins'] as num?)?.toInt() ?? team.wins;
      final losses = (stats['losses'] as num?)?.toInt() ?? team.losses;
      final draws = (stats['draws'] as num?)?.toInt() ?? team.draws;

      final total = wins + losses + draws;
      final winRate = total > 0 ? ((wins / total) * 100).toStringAsFixed(0) : '0';

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
                    backgroundImage: team.logoUrl != null && team.logoUrl!.isNotEmpty
                        ? NetworkImage(team.logoUrl!)
                        : null,
                    child: (team.logoUrl == null || team.logoUrl!.isEmpty)
                        ? Text(
                            team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tr('il_3ac75e6772', args: ['${team.memberIds.length}']),
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
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
                tr('il_6eba3c021d', namedArgs: {'winRate': winRate}),
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
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(value.toString(), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}