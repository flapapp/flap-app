import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/football_position.dart';
import 'package:flap_app/city_localization.dart';
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
import '../../../../theme/flap_tokens.dart';

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
  // Avatar picker and local buffer
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedAvatar; // web-safe file
  bool _uploadingAvatar = false;
  List<String> _myVideoIds = [];
  bool _loadingMyVideos = false;
  double _winRate = 0.0;
  int _wins = 0;
  int _draws = 0;
  int _losses = 0;
  int _matchesPlayed = 0;
  int _totalGoals = 0;
  List<String> _recentResults = const ['-', '-', '-', '-', '-'];
  List<app_badge.Badge> _userBadges = [];
  int _badgeEndorseVersion = 0;
  List<AppTeam> _playerTeams = [];

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
          _totalGoals = (stats['totalGoals'] as num?)?.toInt() ?? 0;
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
        SnackBar(content: Text(tr('player_rate_me_no_videos'))),
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
            backgroundColor: const Color(0xFF10160F),
            title: Text(tr('player_rate_me_pick_videos_title'), style: const TextStyle(color: Colors.white)),
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
                        final title = (v['title'] ?? tr('il_d534be829e')).toString();
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
                            tr('il_b512d97e7c');
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
                          SnackBar(content: Text(tr('player_rating_request_sent'))),
                        );
                      },
                child: Text(tr('send')),
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
                ? tr('player_invitation_accepted')
                : tr('player_invitation_declined'),
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
            tr('player_invitation_cancelled'),
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
            content: Text(tr('player_invitation_sent_snackbar')),
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

  /// Challenge invite + rate-me actions; adapts to width (stacked vs row).
  Widget _buildVisitorSecondaryActions({required bool useCompactLayout}) {
    final challengeBtn = _flapButton(
      label: useCompactLayout ? tr('player_invite_to_challenge_title') : null,
      icon: Icons.emoji_events_rounded,
      onTap: _showInviteToChallengeDialog,
      tone: _FlapBtnTone.neutral,
    );

    final rateBtn = _flapButton(
      label: tr('player_rate_me_button'),
      onTap: _showRateMeDialog,
      tone: _FlapBtnTone.primary,
    );

    if (useCompactLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          challengeBtn,
          const SizedBox(height: 8),
          rateBtn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 54, child: challengeBtn),
        const SizedBox(width: 8),
        Expanded(child: rateBtn),
      ],
    );
  }

  /// Left-aligned small-caps section header (Flap `.setlabel`).
  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: FlapText.sora(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: FlapColors.muted2,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Vertical badge card: category-tinted medallion + floating endorsement
  /// pill + name + rarity; tap to endorse, endorsed state shows a green ring.
  Widget _buildBadgeTile(dynamic badge) {
    final c = Color(badge.categoryColor);
    return FutureBuilder<BadgeEndorsementInfo>(
      key: ValueKey('endorse-${badge.id}-$_badgeEndorseVersion'),
      future: sl<PlayerBadgeEndorsementRepository>().getEndorsementInfo(
        ownerUserId: widget.playerId,
        badgeId: badge.id,
        currentUserId: sl<AuthSessionRepository>().peekCurrentUser?.uid,
      ),
      builder: (context, snap) {
        final count = snap.data?.count ?? 0;
        final endorsed = snap.data?.endorsedByCurrentUser ?? false;
        return GestureDetector(
          onTap: () => _endorseBadge(widget.playerId, badge),
          child: Container(
            width: 120,
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            decoration: BoxDecoration(
              color: FlapColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: endorsed
                    ? FlapColors.greenBright.withValues(alpha: 0.55)
                    : FlapColors.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: c.withValues(alpha: 0.4)),
                      ),
                      child: Text(badge.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                    if (count > 0)
                      Positioned(
                        top: -7,
                        right: -9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: endorsed ? FlapColors.greenBright : FlapColors.blue,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: FlapColors.bg, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.thumb_up,
                                  size: 9,
                                  color: endorsed ? FlapColors.onGreen : Colors.white),
                              const SizedBox(width: 2),
                              Text('$count',
                                  style: FlapText.sora(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: endorsed ? FlapColors.onGreen : Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    if (endorsed)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: FlapColors.bg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle,
                              color: FlapColors.greenBright, size: 17),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  badge.localizedName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.sora(
                      fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badge.rarityText.toString().toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlapText.sora(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: c,
                        letterSpacing: 0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 9:16 video card (design `.vcard`): cover thumbnail + legibility scrim +
  /// play glyph + title caption.
  Widget _buildVideoTile(Map<String, dynamic> v, String authorName) {
    final thumb = (v['thumbnailUrl'] ?? '').toString();
    final vUrl = (v['videoUrl'] ?? '').toString();
    final title = (v['title'] ?? tr('il_d534be829e')).toString();
    return GestureDetector(
      onTap: () {
        if (vUrl.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: vUrl,
              title: title,
              authorName: authorName,
              videoId: (v['id'] ?? '').toString(),
            ),
          ),
        );
      },
      child: SizedBox(
        width: 110,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPreviewBox(
                videoUrl: vUrl,
                thumbnailUrl: thumb.isNotEmpty ? thumb : null,
                aspectRatio: 9 / 16,
                borderRadius: 14,
                showPlayIcon: false,
                placeholderColor: const Color(0xFF0D1A15),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF070A08).withValues(alpha: 0.85),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.sora(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Design action button (Flap `.btn`). [label] null → icon-only.
  Widget _flapButton({
    String? label,
    IconData? icon,
    VoidCallback? onTap,
    _FlapBtnTone tone = _FlapBtnTone.primary,
    bool disabled = false,
  }) {
    final bool isPrimary = tone == _FlapBtnTone.primary;
    final Color fg = isPrimary ? FlapColors.onGreen : FlapColors.text;
    final children = <Widget>[
      if (icon != null)
        Icon(icon, size: 18, color: fg),
      if (icon != null && label != null) const SizedBox(width: 8),
      if (label != null)
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: FlapText.sora(
                fontSize: 14, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
    ];
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: isPrimary ? FlapColors.primaryButton : null,
            color: isPrimary ? null : FlapColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: isPrimary
                ? null
                : Border.all(color: FlapColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }

  /// Outlined danger/neutral button.
  Widget _flapOutlineButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
                fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }

  /// Disabled state pill (friends / pending), surface tone with an icon.
  Widget _flapStatePill({required IconData icon, required String label, Color? accent}) {
    final c = accent ?? FlapColors.greenBright;
    return Container(
      height: 48,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: c),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlapText.sora(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c),
            ),
          ),
        ],
      ),
    );
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
        backgroundColor: FlapColors.bg,
        appBar: _flapAppBar(widget.playerName ?? tr('player_profile_title')),
        body: const Center(
          child: CircularProgressIndicator(color: FlapColors.green),
        ),
      );
    }

    if (playerData == null) {
      return Scaffold(
        backgroundColor: FlapColors.bg,
        appBar: _flapAppBar(tr('profile_not_found')),
        body: Center(
          child: Text(
            tr('player_profile_not_found_body'),
            style: FlapText.sora(fontSize: 14, color: FlapColors.muted),
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
    final cityLabel = localizeCity((playerData!['city'] ?? '').toString());
    final rating = (playerData!['rating'] ?? 0.0).toDouble();
    final matchesFromProfile = ((playerData!['totalMatches'] ?? playerData!['matches'] ?? playerData!['matchesPlayed'] ?? 0) as num).toInt();
    final averageRating = (playerData!['averageRating'] ?? rating).toDouble();
    final winsFromProfile   = ((playerData!['wins'] ?? playerData!['wonMatches']  ?? 0) as num).toInt();
    final lossesFromProfile = ((playerData!['losses'] ?? playerData!['lostMatches'] ?? 0) as num).toInt();
    final drawsFromProfile  = ((playerData!['draws'] ?? playerData!['drawMatches']  ?? 0) as num).toInt();
    final goalsFallback = ((playerData!['goals'] ?? 0) as num).toInt();
    final avatarUrl = (playerData!['avatarUrl'] ?? playerData!['avatar'] ?? playerData!['photoUrl'] ?? '').toString();

    final wins =
        _matchesPlayed > 0 ? _wins : winsFromProfile;
    final draws =
        _matchesPlayed > 0 ? _draws : drawsFromProfile;
    final losses =
        _matchesPlayed > 0 ? _losses : lossesFromProfile;
    final matches = _matchesPlayed > 0 ? _matchesPlayed : matchesFromProfile;
    final goalsDisplay =
        _matchesPlayed > 0 ? _totalGoals : goalsFallback;

      return Scaffold(
      backgroundColor: FlapColors.bg,
      appBar: _flapAppBar(widget.playerName ?? tr('player_profile_title')),
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with green glow ring
            Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    FlapColors.green,
                    FlapColors.greenBright,
                    FlapColors.green,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: FlapColors.green.withValues(alpha: 0.30),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlapColors.bg,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultAvatar(displayName))
                      : _buildDefaultAvatar(displayName),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(displayName,
                textAlign: TextAlign.center,
                style: FlapText.cond(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            const SizedBox(height: 8),
            if (position.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: FlapColors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: FlapColors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_soccer_rounded, color: FlapColors.greenBright, size: 13),
                    const SizedBox(width: 5),
                    Text(position, style: FlapText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: FlapColors.greenBright)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (cityLabel.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.place_outlined, color: FlapColors.muted, size: 15),
                  const SizedBox(width: 4),
                  Text(cityLabel, style: FlapText.sora(fontSize: 13, color: FlapColors.muted)),
                ],
              ),
            const SizedBox(height: 20),

            // Rating
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: FlapColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: FlapColors.borderStrong),
              ),
              child: Column(children: [
                Text(rating.toStringAsFixed(2),
                    style: FlapText.cond(fontSize: 40, fontWeight: FontWeight.w800, color: FlapColors.greenBright)),
                const SizedBox(height: 2),
                Text(tr('overall_rating').toUpperCase(),
                    style: FlapText.sora(fontSize: 11.5, fontWeight: FontWeight.w600, color: FlapColors.muted, letterSpacing: 0.6)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statBox(value: matches.toString(), label: tr('matches'), icon: Icons.sports_soccer, color: const Color(0xFF4CAF50))),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: averageRating.toStringAsFixed(2), label: tr('player_stat_average_rating'), icon: Icons.star_border, color: const Color(0xFFFFD54F))),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: '${_winRate.toStringAsFixed(0)}%', label: tr('profile_win_rate_label'), icon: Icons.percent, color: const Color(0xFF64B5F6))),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: goalsDisplay.toString(), label: tr('il_116cd3982a'), icon: Icons.sports, color: const Color(0xFFFF7043))),
            ]),
            const SizedBox(height: 20),

            const SizedBox(height: 10),

            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _resultChip('W', wins, FlapColors.greenBright),
                const SizedBox(width: 8),
                _resultChip('L', losses, FlapColors.red),
                const SizedBox(width: 8),
                _resultChip('D', draws, FlapColors.amber),
              ],
            ),
            const SizedBox(height: 12),

            // Win rate + last 5
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  decoration: BoxDecoration(
    color: FlapColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: FlapColors.border),
  ),
  child: Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.percent, color: FlapColors.muted, size: 15),
          const SizedBox(width: 6),
          Text(tr('win_rate_percent', args: [_winRate.toStringAsFixed(0)]),
              style: FlapText.sora(fontSize: 13, fontWeight: FontWeight.w600, color: FlapColors.muted)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _recentResults.map((r) {
          Color c;
          if (r == 'W') c = FlapColors.greenBright;
          else if (r == 'D') c = FlapColors.amber;
          else if (r == 'L') c = FlapColors.red;
          else c = FlapColors.muted;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Center(child: Text(r, style: FlapText.sora(fontSize: 12, fontWeight: FontWeight.w800, color: c))),
          );
        }).toList(),
      ),
    ],
  ),
),
const SizedBox(height: 12),

            if (_playerTeams.isNotEmpty) ...[
              _sectionLabel(tr('il_1e1a1c078a')),
              const SizedBox(height: 10),
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

            // Buttons (hidden on own profile)
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

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        final compact = maxW < 420;
                        final stackIncomingActions = maxW < 360;

                        Widget primaryFriendAction;
                        if (isFriend) {
                          primaryFriendAction = _flapStatePill(
                            icon: Icons.people_alt_rounded,
                            label: tr('friends'),
                          );
                        } else if (hasIncoming) {
                          final rid = state.incomingPendingRequestId!;
                          final reject = _flapOutlineButton(
                            label: tr('reject'),
                            color: FlapColors.red,
                            disabled: busy,
                            onTap: () => _respondToFriendRequestFromProfile(
                                rid, false),
                          );
                          final accept = _flapButton(
                            label: tr('accept'),
                            tone: _FlapBtnTone.primary,
                            disabled: busy,
                            onTap: () => _respondToFriendRequestFromProfile(
                                rid, true),
                          );
                          if (stackIncomingActions) {
                            primaryFriendAction = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                reject,
                                const SizedBox(height: 8),
                                accept,
                              ],
                            );
                          } else {
                            primaryFriendAction = Row(
                              children: [
                                Expanded(child: reject),
                                const SizedBox(width: 8),
                                Expanded(child: accept),
                              ],
                            );
                          }
                        } else if (hasOutgoing) {
                          final rid = state.outgoingPendingRequestId!;
                          final pending = _flapStatePill(
                            icon: Icons.schedule_rounded,
                            label: tr('player_invitation_pending_label'),
                            accent: FlapColors.amber,
                          );
                          final cancel = _flapOutlineButton(
                            label: tr('cancel'),
                            color: FlapColors.muted,
                            disabled: busy,
                            onTap: () => _cancelOutgoingFromProfile(rid),
                          );
                          if (compact) {
                            primaryFriendAction = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                pending,
                                const SizedBox(height: 8),
                                cancel,
                              ],
                            );
                          } else {
                            primaryFriendAction = Row(
                              children: [
                                Expanded(child: pending),
                                const SizedBox(width: 8),
                                SizedBox(width: 120, child: cancel),
                              ],
                            );
                          }
                        } else {
                          primaryFriendAction = _flapButton(
                            label: _isSendingRequest
                                ? tr('player_add_friend_sending')
                                : tr('add_friend'),
                            icon: Icons.person_add_alt_1_rounded,
                            tone: _FlapBtnTone.primary,
                            disabled: busy,
                            onTap: () => _sendFriendRequest(),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            primaryFriendAction,
                            const SizedBox(height: 10),
                            _buildVisitorSecondaryActions(
                              useCompactLayout: compact,
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            // Badges
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlapColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: FlapColors.borderStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(tr('badges')),
                  const SizedBox(height: 10),
                  if (_userBadges.isEmpty)
                    Text(tr('player_no_badges_yet'), style: FlapText.sora(fontSize: 13, color: FlapColors.muted))
                  else
                    SizedBox(
                      height: 152,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _userBadges.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) => _buildBadgeTile(_userBadges[i]),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Player videos
            if (playerVideos.isNotEmpty) ...[
              _sectionLabel(tr('videos')),
              const SizedBox(height: 10),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: playerVideos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _buildVideoTile(playerVideos[index], displayName),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FlapColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FlapColors.border),
                ),
                child: Text(tr('no_videos_yet'), style: FlapText.sora(fontSize: 13, color: FlapColors.muted)),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  /// Shared Flap app bar: glass chevron-back + Sora title.
  PreferredSizeWidget _flapAppBar(String title) {
    return AppBar(
      backgroundColor: FlapColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 66,
      leadingWidth: 60,
      titleSpacing: 0,
      leading: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlapColors.surface2,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: FlapColors.border),
              ),
              child: const Icon(Icons.chevron_left, color: FlapColors.text, size: 19),
            ),
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _resultChip(String label, int value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: FlapText.sora(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 5),
        Text(value.toString(), style: FlapText.sora(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    ),
  );
}

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [FlapColors.green, FlapColors.greenBright],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: FlapText.cond(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: FlapColors.onGreen,
          ),
        ),
      ),
    );
  }

  Widget _statBox({required String value, required String label, IconData? icon, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? FlapColors.muted, size: 18),
            const SizedBox(height: 7),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlapText.cond(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: FlapText.sora(fontSize: 11, color: FlapColors.muted),
            textAlign: TextAlign.center,
            maxLines: 1,
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
          SnackBar(content: Text(tr('player_invite_to_challenge_none'))),
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
              backgroundColor: const Color(0xFF10160F),
              title: Text(tr('player_invite_to_challenge_title'), style: const TextStyle(color: Colors.white)),
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
                      title: Text(c['title'] ?? tr('il_27cf1792f7'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        tr(
                          'player_challenge_participants_count',
                          namedArgs: {
                            'count':
                                '${(c['participants'] as List?)?.length ?? 0}',
                          },
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
                            challengeTitle:
                                (selected['title'] ?? tr('il_27cf1792f7'))
                                    .toString(),
                            creatorName: (playerData?['displayName'] ??
                                    tr('il_b512d97e7c'))
                                .toString(),
                            challengeType: (selected['type'] ?? 'goal').toString(),
                          );
                          if (!mounted || dialogClosed) return;
                          dialogClosed = true;
                          Navigator.pop(ctx, true);
                          if (!mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? tr('player_invitation_sent_snackbar')
                                    : tr('player_invite_challenge_send_failed'),
                              ),
                            ),
                          );
                        },
                  child: Text(tr('player_invite_challenge_cta')),
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
  // Shared text field for modal forms
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
          ? (v) => (v == null || v.trim().isEmpty) ? tr('field_required') : null
          : null,
    );
  }

  Future<void> _endorseBadge(String ownerId, app_badge.Badge badge) async {
    final currentUserId = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('player_endorse_sign_in'))),
      );
      return;
    }
    if (currentUserId == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_472d788d72'))),
      );
      return;
    }

    final result = await sl<PlayerBadgeEndorsementRepository>().endorseBadge(
      ownerUserId: ownerId,
      badgeId: badge.id,
      badgeLocalizedName: badge.localizedName,
      endorserUserId: currentUserId,
      badgeCategory: badge.category,
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
          cache: () => tr('something_went_wrong'),
          network: (m) => m ?? tr('connection_error'),
          unexpected: (m) => m ?? tr('something_went_wrong'),
          auth: (_, m) => m ?? tr('login_error'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }
}

enum _FlapBtnTone { primary, neutral }

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
            color: FlapColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: FlapColors.card2,
                    backgroundImage: team.logoUrl != null && team.logoUrl!.isNotEmpty
                        ? NetworkImage(team.logoUrl!)
                        : null,
                    child: (team.logoUrl == null || team.logoUrl!.isEmpty)
                        ? Text(
                            team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                            style: FlapText.cond(fontSize: 18, fontWeight: FontWeight.w700, color: FlapColors.greenBright),
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
                          style: FlapText.sora(fontSize: 13.5, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tr('il_3ac75e6772', args: ['${team.memberIds.length}']),
                          style: FlapText.sora(fontSize: 11, color: FlapColors.muted),
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
                  _teamChip('W', wins, FlapColors.greenBright),
                  _teamChip('L', losses, FlapColors.red),
                  _teamChip('D', draws, FlapColors.amber),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('il_6eba3c021d', namedArgs: {'winRate': winRate}),
                style: FlapText.sora(fontSize: 11, color: FlapColors.muted),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(label, style: FlapText.sora(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(value.toString(), style: FlapText.sora(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}