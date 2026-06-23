import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../router/app_router.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/matches_repository.dart';
import '../../application/match_participation_actions_use_case.dart';
import '../../../teams/domain/repositories/teams_repository.dart';
import '../../../teams/data/models/app_team.dart';
import '../../data/models/match.dart';
import '../utils/match_status_ui.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/team_logo_button.dart';
import '../../../../widgets/team_crest.dart';
import '../../../../widgets/user_chip.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/city_localization.dart';
import '../../../../core/locale/football_position.dart';
import '../widgets/team_roster_total_rating_badge.dart';
import 'team_invite_search_screen.dart';

double _profileOverallRatingFromRow(Map<String, dynamic> data) {
  final v = data['overall_rating'] ?? data['rating'];
  if (v is num) return v.toDouble();
  return 0.0;
}

@RoutePage()
class MatchDetailsScreen extends StatefulWidget {
  final Match match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  MatchesRepository get _matchRepo => sl<MatchesRepository>();
  TeamsRepository get _teamsRepo => sl<TeamsRepository>();
  MatchParticipationActionsUseCase get _participationActions =>
      sl<MatchParticipationActionsUseCase>();
  final SupabaseClient _sb = Supabase.instance.client;

  final NotificationService _notificationService = sl<NotificationService>();
  bool _isJoining = false;
  bool _joinRequested = false;
  bool _isRespondingInvite = false;
  bool _isRespondingTeamInvite = false;
  String? _inviteStatusOverride;
  bool _acceptedInviteLocally = false;
  bool _isUploadingCover = false;
  // The current viewer's direct match-invite status ('pending'/'declined'/'').
  // Loaded once so the join affordances and dock can decide synchronously.
  String _myInviteStatus = '';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMyInviteStatus();
  }

  Future<void> _loadMyInviteStatus() async {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    try {
      final row = await _sb
          .from('match_invites')
          .select('status')
          .eq('match_id', widget.match.id)
          .eq('user_id', uid)
          .maybeSingle();
      final status = (row?['status'] ?? '').toString();
      if (mounted && status.isNotEmpty) {
        setState(() => _myInviteStatus = status);
      }
    } catch (_) {}
  }

  // Profile cache to avoid duplicate fetches
  final Map<String, Map<String, dynamic>> _profileCache = {};
  final Map<String, AppTeam> _teamCache = {};
  final Map<String, String> _playerNameCache = {};
  bool _isProcessingRosterAction = false;

  List<String> get _effectiveParticipants {
    final ids = List<String>.from(widget.match.participants);
    final currentUserId = AppAuth.currentUserId;
    if (_acceptedInviteLocally &&
        currentUserId != null &&
        !ids.contains(currentUserId)) {
      ids.add(currentUserId);
    }
    return ids;
  }

  Stream<Match?> _liveMatchStream() {
    return _sb
        .from('matches')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => _matchRepo.fetchMatchById(widget.match.id));
  }

  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    if (_profileCache.containsKey(userId)) return _profileCache[userId]!;
    try {
      final data =
          await _sb.from('profiles').select().eq('id', userId).maybeSingle() ??
          const <String, dynamic>{};
      final profile = <String, dynamic>{
        'displayName':
            (data['display_name'] ??
                    data['first_name'] ??
                    data['author_name'] ??
                    tr('player'))
                .toString(),
        'avatarUrl': (data['avatar_url'] ?? '').toString(),
      };
      _profileCache[userId] = profile;
      return profile;
    } catch (_) {
      final fallback = <String, dynamic>{
        'displayName': tr('player'),
        'avatarUrl': '',
      };
      _profileCache[userId] = fallback;
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A08),
      appBar: AppBar(
        title: Text(
          tr('il_f6e1977cf4'),
          style: FlapText.sora(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: FlapColors.text,
        iconTheme: const IconThemeData(color: FlapColors.text),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF13241B), FlapColors.bg],
            ),
          ),
        ),
        actions: [
          if (AppAuth.currentUserId == widget.match.organizerId)
            _detailAppBarIcon(
              Icons.settings_outlined,
              () => context.router
                  .push(MatchManagementRoute(match: widget.match)),
              tooltip: tr('manage'),
            ),
          if (_canJoin)
            _appBarJoinPill(
              icon: Icons.person_add_outlined,
              label: tr('join'),
              onPressed: _isJoining ? null : _joinMatch,
            )
          else if (_hasRequestedJoin)
            _appBarJoinPill(
              icon: Icons.mark_email_read_outlined,
              label: tr('match_feed_join_requested'),
              onPressed: null,
            ),
          _detailAppBarIcon(
            Icons.ios_share,
            () => _shareMatch(),
            tooltip: tr('share'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and status
            _buildHeaderSection(),
            SizedBox(height: 20),
            _buildCoverPhotoSection(),

            // Main info
            _buildInfoSection(),
            SizedBox(height: 20),

            if (widget.match.isTeamMatch) ...[
              StreamBuilder<Match?>(
                stream: _liveMatchStream(),
                builder: (context, snapshot) {
                  final m = snapshot.data ?? widget.match;
                  return Column(
                    children: [
                      _buildTeamMatchSection(m),
                      const SizedBox(height: 14),
                      _buildTeamInvitationManagementSection(m),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildCaptainControlCard(),
              _buildRosterInviteBanner(),
            ],

            // Lineups and score for finished matches (live reload so goals/scores match DB)
            StreamBuilder<Match?>(
              stream: _liveMatchStream(),
              builder: (context, snapshot) {
                final resolved = snapshot.data ?? widget.match;
                if (resolved.status != MatchStatus.finished) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    _buildFinishedTeamsAndScoreSection(resolved),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            // Participants with detail (only for non-team matches)
            if (!widget.match.isTeamMatch) ...[
              _buildParticipantsSection(),
              SizedBox(height: 20),
            ],

          ],
        ),
      ),
      bottomNavigationBar: _buildActionDock(),
    );
  }

  // Sticky bottom action dock (design `.dock`).
  Widget _buildActionDock() {
    // Joinable viewers act via the app-bar join button + open-spot slots;
    // requested viewers see the "Requested" badge in the app bar. Either way
    // there's no bottom Join / Share / message.
    if (_canJoin || _hasRequestedJoin) return const SizedBox.shrink();
    final action = _buildActionButtons();
    // No dock when there's no bottom action (e.g. organizers, who manage and
    // share from the app bar).
    if (action is SizedBox) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00070A08), FlapColors.bg],
          stops: [0.0, 0.32],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: SafeArea(
        top: false,
        // mainAxisSize.min so the dock hugs its content height (the bottom
        // bar otherwise hands the action column a full-screen height budget).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [action],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final statusUi = buildMatchStatusUi(
      widget.match.status,
      match: widget.match,
    );

    final m = widget.match;
    final IconData statusIcon = m.isTeamMatch
        ? Icons.shield_outlined
        : m.status == MatchStatus.open
            ? Icons.check_circle_outline
            : m.status == MatchStatus.full
                ? Icons.people_alt_outlined
                : Icons.sports_soccer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x2E4CAF50), Color(0x05FFFFFF)],
          stops: [0.0, 0.5],
        ),
        color: FlapColors.card2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: statusUi.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 13, color: statusUi.color),
                const SizedBox(width: 6),
                Text(
                  statusUi.label,
                  style: FlapText.sora(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: statusUi.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // condensed athletic title
          Text(
            m.title.toUpperCase(),
            style: FlapText.cond(fontSize: 30, height: 0.98),
          ),
          if (m.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              m.description,
              style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          // level + cost pills
          Row(
            children: [
              _detailPill(Icons.bar_chart_rounded, _getLevelText(m.level)),
              const SizedBox(width: 8),
              _detailPill(
                Icons.monetization_on_outlined,
                m.cost <= 0
                    ? tr('match_cost_free')
                    : tr('match_cost_uah', namedArgs: {'amount': '${m.cost}'}),
                iconColor: FlapColors.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailPill(IconData icon, String text,
      {Color iconColor = FlapColors.text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(text,
              style: FlapText.sora(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // App-bar Join / Requested pill — matches the Matches-card secondary action.
  Widget _appBarJoinPill({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: FlapColors.text,
            disabledForegroundColor: FlapColors.muted,
            side: const BorderSide(color: FlapColors.borderStrong),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailAppBarIcon(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: FlapColors.border),
        ),
        child: Icon(icon, size: 18, color: FlapColors.text),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: tooltip != null ? Tooltip(message: tooltip, child: btn) : btn,
    );
  }

  Widget _buildCoverPhotoSection() {
    final bool isOrganizer = AppAuth.currentUserId == widget.match.organizerId;
    return StreamBuilder<Match?>(
      stream: _liveMatchStream(),
      builder: (context, snapshot) {
        final liveMatch = snapshot.data;
        final photoUrl = liveMatch?.coverPhotoUrl ?? widget.match.coverPhotoUrl;
        final status = liveMatch?.status ?? widget.match.status;
        final bool showUploadCta =
            isOrganizer && status == MatchStatus.finished;
        final bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
        if (!hasPhoto && !showUploadCta) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: hasPhoto
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _buildCoverPlaceholderContent(),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.photo_album,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr('il_556df31ebb'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildCoverPlaceholderContent(),
              ),
            ),
            if (showUploadCta) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _isUploadingCover ? null : _handleUploadMatchPhoto,
                  icon: _isUploadingCover
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    hasPhoto ? tr('il_7e683a862b') : tr('il_97572951db'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildCoverPlaceholderContent() {
    return Container(
      color: Colors.black.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: Colors.white.withOpacity(0.6),
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              tr('il_2f9b6b2d9d'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUploadMatchPhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingCover = true);

      final uid = AppAuth.currentUser?.id;
      if (uid == null) {
        throw Exception('Not signed in');
      }
      final fileName =
          'cover_${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';
      final objectPath = '${uid}/${widget.match.id}/$fileName';
      final data = await pickedFile.readAsBytes();
      final downloadUrl = await SupabaseAppStorage.uploadPublicBytes(
        Supabase.instance.client,
        bucket: SupabaseAppStorage.matchCovers,
        path: objectPath,
        bytes: data,
        contentType: 'image/jpeg',
      );

      await _matchRepo.updateCoverPhoto(
        matchId: widget.match.id,
        photoUrl: downloadUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_af75da9942')),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'match_photo_upload_failed',
              namedArgs: {'detail': e.toString()},
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  Widget _buildInfoSection() {
    final m = widget.match;
    final locale = context.locale.toString();
    final dateStr =
        DateFormat('EEE, d MMM yyyy', locale).format(m.scheduledDateTime);
    final isOrganizer = AppAuth.currentUserId == m.organizerId;
    final city = localizeCity(m.city);
    final locationValue =
        city.isNotEmpty ? '${m.location}, $city' : m.location;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.calendar_today_outlined,
            label: tr('il_99c40ab405'),
            value: dateStr,
          ),
          _infoRow(
            icon: Icons.schedule,
            label: tr('il_33b93476cf'),
            value: m.scheduledKickoffTimeLabel,
          ),
          _infoRow(
            icon: Icons.place_outlined,
            label: tr('match_location_label'),
            value: locationValue,
          ),
          _infoRow(
            label: tr('organizer'),
            value: isOrganizer
                ? '${m.organizerName} ${tr('match_organizer_you')}'
                : m.organizerName,
            leading: UserChip(
              userId: m.organizerId,
              name: m.organizerName.isNotEmpty ? m.organizerName : null,
              size: 38,
              showName: false,
            ),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    IconData? icon,
    Widget? leading,
    required String label,
    required String value,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: FlapColors.border)),
      ),
      child: Row(
        children: [
          leading ??
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: FlapColors.border),
                ),
                child: Icon(icon, size: 18, color: FlapColors.greenBright),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: FlapText.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style:
                      FlapText.sora(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMatchSection(Match match) {
    final teamAName = (match.teamA?.name.isNotEmpty ?? false)
        ? match.teamA!.name
        : tr('il_d161440e8d');
    final teamBName = (match.teamB?.name.isNotEmpty ?? false)
        ? match.teamB!.name
        : (match.teamBId != null
              ? tr('il_6b3e8cd77f')
              : tr('il_324df4ad19'));

    final rosterA =
        match.teamRosters['teamA'] ??
        match.teamA?.playerIds ??
        const <String>[];
    final rosterB =
        match.teamRosters['teamB'] ??
        match.teamB?.playerIds ??
        const <String>[];
    final rosterStatusA =
        match.teamRosterStatus['teamA'] ?? const <String, String>{};
    final rosterStatusB =
        match.teamRosterStatus['teamB'] ?? const <String, String>{};

    final hasScore =
        match.teamAScore != null && match.teamBScore != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('il_4f76cec7a7'),
                  style:
                      FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              _buildTeamStatusChip(),
            ],
          ),
          const SizedBox(height: 14),
          _buildVsBlock(
            teamAName: teamAName,
            teamBName: teamBName,
            teamAId: match.teamAId,
            teamBId: match.teamBId,
            rosterA: rosterA,
            rosterB: rosterB,
          ),
          if (hasScore) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildScorePill(
                  teamAName,
                  match.teamAScore!,
                  Colors.greenAccent,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildScorePill(
                  teamBName,
                  match.teamBScore!,
                  Colors.lightBlueAccent,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildTeamRow(
            label: teamAName,
            status: match.teamAStatus ?? 'confirmed',
            playerIds: rosterA,
            accent: const Color(0xFF4caf50),
            rosterStatuses: rosterStatusA,
          ),
          const SizedBox(height: 16),
          _buildTeamRow(
            label: teamBName,
            status:
                match.teamBStatus ??
                (match.teamBId == null ? 'pending' : 'confirmed'),
            playerIds: rosterB,
            accent: const Color(0xFF42a5f5),
            rosterStatuses: rosterStatusB,
          ),
          if ((rosterA.isNotEmpty || rosterB.isNotEmpty) &&
              match.teamRosterStatus.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildRosterStatusLegend(),
          ],
        ],
      ),
    );
  }

  // Design `.vs` block: two team cards facing off with a VS divider.
  Widget _buildVsBlock({
    required String teamAName,
    required String teamBName,
    required String? teamAId,
    required String? teamBId,
    required List<String> rosterA,
    required List<String> rosterB,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _vsTeamCard(
              name: teamAName,
              teamId: teamAId,
              playerIds: rosterA,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('VS',
                    style: FlapText.cond(fontSize: 20, color: FlapColors.muted)),
                const SizedBox(height: 6),
                const Icon(Icons.sports_soccer,
                    size: 20, color: FlapColors.muted),
              ],
            ),
          ),
          Expanded(
            child: _vsTeamCard(
              name: teamBName,
              teamId: teamBId,
              playerIds: rosterB,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vsTeamCard({
    required String name,
    required String? teamId,
    required List<String> playerIds,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0BFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TeamCrest(
            teamId: teamId,
            teamName: name,
            size: 46,
            circular: false,
            borderRadius: 14,
          ),
          const SizedBox(height: 10),
          Text(
            name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: FlapText.cond(fontSize: 18),
          ),
          const SizedBox(height: 6),
          if (playerIds.isNotEmpty)
            TeamRosterTotalRatingBadge(
              playerIds: playerIds,
              accent: FlapColors.gold,
              iconSize: 13,
              fontSize: 13,
            ),
        ],
      ),
    );
  }

  Widget _buildCaptainControlCard() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null || !widget.match.isTeamMatch) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Match?>(
      stream: _liveMatchStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final liveMatch = snapshot.data!;
        final sections = <Widget>[];

        final teamASection = _buildCaptainSectionForTeam(
          liveMatch,
          'teamA',
          currentUser.id,
        );
        if (teamASection != null) sections.add(teamASection);

        final teamBSection = _buildCaptainSectionForTeam(
          liveMatch,
          'teamB',
          currentUser.id,
        );
        if (teamBSection != null) sections.add(teamBSection);

        if (sections.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections
              .map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: section,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTeamInvitationManagementSection(Match match) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sb
          .from('team_match_requests')
          .stream(primaryKey: ['id'])
          .map(
            (rows) => (rows as List<dynamic>)
                .map((raw) => Map<String, dynamic>.from(raw as Map))
                .where((row) => (row['match_id'] ?? '').toString() == match.id)
                .toList(growable: false),
          ),
      builder: (context, snapshot) {
        final invite = _resolveTeamInviteRequest(match, snapshot.data ?? const []);
        final currentUserId = AppAuth.currentUserId;
        final isOrganizer =
            currentUserId != null && currentUserId == match.organizerId;
        final inviteStatus = (invite?['status'] ?? '').toString();
        final canChangePending = isOrganizer && inviteStatus == 'pending';
        final canInviteFresh = isOrganizer && invite == null;
        final creatorTeamId = ((match.teamAId ?? widget.match.teamAId) ?? '').toString();
        final creatorTeamIdFromRequest =
            (invite?['requesting_team_id'] ?? '').toString();
        final effectiveCreatorTeamId = creatorTeamId.isNotEmpty
            ? creatorTeamId
            : creatorTeamIdFromRequest;
        final invitedTeamId = (invite?['target_team_id'] ?? '').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Creator Team',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<AppTeam?>(
                future: effectiveCreatorTeamId.isEmpty
                    ? Future.value(null)
                    : _getTeam(effectiveCreatorTeamId),
                builder: (context, creatorSnap) {
                  final creatorTeam = creatorSnap.data;
                  final creatorTeamName = creatorTeam?.name ??
                      (match.teamA?.name.isNotEmpty == true
                          ? match.teamA!.name
                          : tr('il_d161440e8d'));
                  return Row(
                    children: [
                      if (effectiveCreatorTeamId.isNotEmpty)
                        TeamLogoButton(
                          teamId: creatorTeam?.id ?? effectiveCreatorTeamId,
                          teamName: creatorTeamName,
                          logoUrl: creatorTeam?.logoUrl,
                          size: 36,
                        )
                      else
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white12,
                          child: Icon(Icons.groups, color: Colors.white70, size: 18),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          creatorTeamName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                tr('il_ecbd71fddb'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (invite == null)
                const Text(
                  'No invited team yet.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                )
              else
                FutureBuilder<AppTeam?>(
                  future: invitedTeamId.isEmpty ? Future.value(null) : _getTeam(invitedTeamId),
                  builder: (context, teamSnap) {
                    final invitedTeam = teamSnap.data;
                    final teamName = invitedTeam?.name ??
                        (invite['target_team_id'] ?? '').toString();
                    final statusLabel = _teamInviteStatusLabel(inviteStatus);
                    final accepted = inviteStatus == 'accepted';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TeamLogoButton(
                              teamId: invitedTeam?.id ?? invitedTeamId,
                              teamName: teamName,
                              logoUrl: invitedTeam?.logoUrl,
                              size: 36,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                teamName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _teamInviteStatusColor(inviteStatus)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _teamInviteStatusColor(inviteStatus)
                                      .withValues(alpha: 0.38),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: _teamInviteStatusColor(inviteStatus),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          accepted
                              ? 'Invitation accepted.'
                              : 'Invitation not accepted yet.',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              if (canInviteFresh || canChangePending) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleTeamInviteSelection(
                      match: match,
                      currentInvite: invite,
                    ),
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: Text(
                      canInviteFresh ? tr('il_7ec0bce7a1') : tr('il_1f6c4a2d9e'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4caf50)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _resolveTeamInviteRequest(
    Match match,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return null;
    final hostTeamId = (match.teamAId ?? widget.match.teamAId ?? '').trim();
    final invitedTeamId = (match.teamBId ?? widget.match.teamBId ?? '').trim();
    final valid = rows.where((row) {
      final status = (row['status'] ?? '').toString();
      return status == 'pending' || status == 'accepted' || status == 'declined';
    }).toList(growable: false);
    if (valid.isEmpty) return null;

    List<Map<String, dynamic>> scoped = valid;
    if (hostTeamId.isNotEmpty) {
      scoped = scoped.where((row) {
        final requesting = (row['requesting_team_id'] ?? '').toString();
        final target = (row['target_team_id'] ?? '').toString();
        return requesting == hostTeamId && target != hostTeamId;
      }).toList(growable: false);
    }
    if (invitedTeamId.isNotEmpty) {
      final byInvitedId = scoped.where((row) {
        final target = (row['target_team_id'] ?? '').toString();
        return target == invitedTeamId;
      }).toList(growable: false);
      if (byInvitedId.isNotEmpty) {
        scoped = byInvitedId;
      }
    }
    if (scoped.isEmpty) {
      scoped = valid.where((row) {
        final createdBy = (row['created_by'] ?? '').toString();
        final requesting = (row['requesting_team_id'] ?? '').toString();
        final target = (row['target_team_id'] ?? '').toString();
        return createdBy == match.organizerId && requesting != target;
      }).toList(growable: false);
    }
    final pool = scoped.isNotEmpty ? scoped : valid;
    pool.sort((a, b) {
      final aDate = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return pool.first;
  }

  Future<void> _handleTeamInviteSelection({
    required Match match,
    required Map<String, dynamic>? currentInvite,
  }) async {
    final hostTeamId = (match.teamAId ?? widget.match.teamAId ?? '').trim();
    if (hostTeamId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host team is not assigned yet.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final initialTargetId = (currentInvite?['target_team_id'] ?? '').toString();
    final initialTeam =
        initialTargetId.isEmpty ? null : await _getTeam(initialTargetId);
    if (!mounted) return;

    final selectedTeam = await Navigator.of(context).push<AppTeam>(
      MaterialPageRoute(
        builder: (_) => TeamInviteSearchScreen(
          initialSelectedTeam: initialTeam,
          excludedTeamId: hostTeamId,
        ),
      ),
    );
    if (!mounted || selectedTeam == null) return;

    try {
      // Cancel still-pending outgoing invitations for this match via RPC so
      // RLS uses the security-definer path (organizer of the match is allowed
      // even if not a team officer).
      final pendingIds = await _sb
          .from('team_match_requests')
          .select('id')
          .eq('match_id', match.id)
          .eq('requesting_team_id', hostTeamId)
          .eq('status', 'pending');
      for (final raw in pendingIds as List<dynamic>) {
        final id = (raw as Map<String, dynamic>)['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        try {
          await _teamsRepo.cancelMatchRequest(requestId: id);
        } catch (_) {
          // Continue - we still want to send the new invite.
        }
      }

      await _teamsRepo.sendMatchRequest(
        teamId: hostTeamId,
        opponentTeamId: selectedTeam.id,
        opponentName: selectedTeam.name,
        matchId: match.id,
        proposedRoster: const [],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentInvite == null
                ? 'Team invitation sent.'
                : 'Team invitation updated.',
          ),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _teamInviteStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return tr('match_invite_status_accepted');
      case 'declined':
        return tr('match_invite_status_declined');
      default:
        return tr('match_invite_status_pending');
    }
  }

  Color _teamInviteStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }

  Widget? _buildCaptainSectionForTeam(
    Match liveMatch,
    String teamKey,
    String currentUserId,
  ) {
    final teamId = teamKey == 'teamA' ? liveMatch.teamAId : liveMatch.teamBId;
    if (teamId == null || teamId.isEmpty) return null;

    return FutureBuilder<AppTeam?>(
      future: _getTeam(teamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FlapShimmer(
            child: FlapSkeletonBox(
              width: double.infinity,
              height: 92,
              radius: 16,
            ),
          );
        }
        final team = snapshot.data;
        if (team == null) return const SizedBox.shrink();

        final isManager =
            team.captainId == currentUserId ||
            team.viceCaptainIds.contains(currentUserId);
        if (!isManager) return const SizedBox.shrink();

        final roster = liveMatch.teamRosters[teamKey] ?? team.memberIds;
        final rosterStatus =
            liveMatch.teamRosterStatus[teamKey] ?? const <String, String>{};
        final teamStatus =
            (teamKey == 'teamA'
                ? liveMatch.teamAStatus
                : liveMatch.teamBStatus) ??
            'pending';

        final allConfirmed =
            roster.isNotEmpty &&
            rosterStatus.values.every((s) => s == 'confirmed');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('il_9212d8dcc4', args: [team.name]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildStatusChip(teamStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('il_e411803602', args: ['${roster.length}']),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
              if (roster.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  tr('il_eda0355fec'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ] else ...[
                const SizedBox(height: 10),
                _buildRosterStatusWrap(roster, rosterStatus),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessingRosterAction
                    ? null
                    : () => _openRosterPicker(
                        teamKey: teamKey,
                        team: team,
                        liveMatch: liveMatch,
                      ),
                icon: const Icon(Icons.group_add),
                label: Text(
                  roster.isEmpty ? tr('il_6ae263d842') : tr('il_0474305707'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4caf50),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                allConfirmed ? tr('il_42d5e0da31') : tr('il_253d26aef7'),
                style: TextStyle(
                  color: allConfirmed
                      ? const Color(0xFF4caf50)
                      : Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamRow({
    required String label,
    required String status,
    required List<String> playerIds,
    required Color accent,
    Map<String, String> rosterStatuses = const {},
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (playerIds.isNotEmpty)
              TeamRosterTotalRatingBadge(
                playerIds: playerIds,
                accent: accent,
                iconSize: 17,
                fontSize: 15,
                padding: const EdgeInsets.only(right: 10),
              ),
            _buildTeamStatusPill(status),
          ],
        ),
        const SizedBox(height: 10),
        if (playerIds.isEmpty)
          Text(
            tr('il_c6b28c9228'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: playerIds.take(12).map((id) {
                final playerStatus = rosterStatuses[id] ?? 'pending';
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: UserChip(userId: id, size: 32, showName: false),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: _buildPlayerStatusIndicator(playerStatus),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamStatusPill(String status) {
    final color = _teamStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _teamStatusText(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRosterInviteBanner() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<Match?>(
      stream: _liveMatchStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final match = snapshot.data!;
        final rawStatus = match.teamRosterStatus;

        String? teamKey;
        String playerStatus = '';
        rawStatus.forEach((key, value) {
          if (teamKey != null) return;
          if (value.containsKey(currentUser.id)) {
            teamKey = key.toString();
            playerStatus = value[currentUser.id]?.toString() ?? '';
          }
        });

        if (teamKey == null) {
          return const SizedBox.shrink();
        }

        final teamName = teamKey == 'teamA'
            ? (match.teamA?.name ?? tr('il_e18d322f14'))
            : (match.teamB?.name ?? tr('il_aceaf5d9ac'));
        final isPending = playerStatus.isEmpty || playerStatus == 'pending';
        final headline = isPending
            ? tr('il_a23b1c12bb')
            : playerStatus == 'confirmed'
            ? tr('il_d585866af0')
            : tr('il_d3bcba9446');
        final description = isPending
            ? tr(
                'match_roster_captain_added_you',
                namedArgs: {'teamName': teamName},
              )
            : playerStatus == 'confirmed'
            ? tr('il_cf3c929b1b')
            : tr('il_9a08914842');
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_ind, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          headline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _playerStatusColor(
                            playerStatus.isEmpty ? 'pending' : playerStatus,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          teamName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              (_isProcessingRosterAction ||
                                  playerStatus == 'confirmed')
                              ? null
                              : () => _handleRosterResponse(teamKey!, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4caf50),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            playerStatus == 'confirmed'
                                ? tr('il_fe00b67b6d')
                                : tr('il_eebdd24a77'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              (_isProcessingRosterAction ||
                                  playerStatus == 'declined')
                              ? null
                              : () => _handleRosterResponse(teamKey!, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            playerStatus == 'declined'
                                ? tr('il_dce083a2c4')
                                : tr('il_a2d285b352'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildScorePill(String name, int score, Color color) {
    return Column(
      children: [
        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        tr('il_9e236cb5f1'),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _teamStatusText(String? status) {
    switch (status) {
      case 'confirmed':
        return tr('il_fe00b67b6d');
      case 'declined':
        return tr('il_dce083a2c4');
      default:
        return tr('il_331551b0de');
    }
  }

  Color _teamStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }

  Widget _buildPlayerStatusIndicator(String status) {
    final color = _playerStatusColor(status);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.black87,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Color _playerStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }

  Widget _buildRosterStatusLegend() {
    return Row(
      children: [
        _legendChip(_playerStatusColor('confirmed'), tr('il_fe00b67b6d')),
        const SizedBox(width: 8),
        _legendChip(_playerStatusColor('pending'), tr('il_331551b0de')),
        const SizedBox(width: 8),
        _legendChip(_playerStatusColor('declined'), tr('il_dce083a2c4')),
      ],
    );
  }

  Widget _legendChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<AppTeam?> _getTeam(String teamId) async {
    if (_teamCache.containsKey(teamId)) return _teamCache[teamId];
    final teamRow = await _sb
        .from('teams')
        .select()
        .eq('id', teamId)
        .maybeSingle();
    if (teamRow == null) return null;
    final members = await _sb
        .from('team_members')
        .select('user_id, role')
        .eq('team_id', teamId);
    String captainId = '';
    final viceCaptainIds = <String>[];
    final memberIds = <String>[];
    for (final raw in members as List<dynamic>) {
      final member = raw as Map<String, dynamic>;
      final uid = (member['user_id'] ?? '').toString();
      if (uid.isEmpty) continue;
      memberIds.add(uid);
      final role = (member['role'] ?? '').toString();
      if (role == 'captain') {
        captainId = uid;
      } else if (role == 'vice_captain') {
        viceCaptainIds.add(uid);
      }
    }
    final team = AppTeam.fromRemoteMap(teamId, <String, dynamic>{
      'name': teamRow['name'] ?? '',
      'description': teamRow['description'] ?? '',
      'captainId': captainId,
      'viceCaptainIds': viceCaptainIds,
      'memberIds': memberIds,
      'isPublic': teamRow['is_public'] ?? true,
      'logoUrl': teamRow['logo_url'],
      'city': teamRow['city'],
      'createdAt': teamRow['created_at'],
      'updatedAt': teamRow['updated_at'],
    });
    _teamCache[teamId] = team;
    return team;
  }

  Future<String> _fetchPlayerName(String userId) async {
    if (_playerNameCache.containsKey(userId)) {
      return _playerNameCache[userId]!;
    }
    try {
      final data = await _sb
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      final name =
          (data?['display_name'] ??
                  data?['first_name'] ??
                  data?['author_name'] ??
                  tr('player'))
              .toString();
      _playerNameCache[userId] = name;
      return name;
    } catch (_) {
      final fallback = tr('player');
      _playerNameCache[userId] = fallback;
      return fallback;
    }
  }

  Future<void> _openRosterPicker({
    required String teamKey,
    required AppTeam team,
    required Match liveMatch,
  }) async {
    final members = team.memberIds;
    if (members.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_208058ae7b'))));
      return;
    }

    final previousSelection = Set<String>.from(
      liveMatch.teamRosters[teamKey] ?? const <String>[],
    );

    final memberNames = <String, String>{};
    for (final memberId in members) {
      memberNames[memberId] = await _fetchPlayerName(memberId);
    }
    if (!mounted) return;

    final selectedResult = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1310),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final selected = Set<String>.from(previousSelection);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('il_944478b5c4', args: [team.name]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: ListView(
                        children: members.map((memberId) {
                          return CheckboxListTile(
                            value: selected.contains(memberId),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(memberId);
                                } else {
                                  selected.remove(memberId);
                                }
                              });
                            },
                            activeColor: const Color(0xFF4caf50),
                            title: Text(
                              memberNames[memberId] ?? tr('player'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: Text(tr('cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(ctx, selected.toList()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4caf50),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              selected.isEmpty
                                  ? tr('il_91ba85a4a0')
                                  : tr('il_31b7605fc5'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedResult == null) return;

    await _saveTeamRosterSelection(
      teamKey: teamKey,
      team: team,
      playerIds: selectedResult,
      previousSelection: previousSelection,
    );
  }

  Future<void> _saveTeamRosterSelection({
    required String teamKey,
    required AppTeam team,
    required List<String> playerIds,
    required Set<String> previousSelection,
  }) async {
    if (playerIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_5eac012cf2'))));
      return;
    }

    setState(() => _isProcessingRosterAction = true);
    try {
      await _matchRepo.setTeamRoster(
        matchId: widget.match.id,
        teamKey: teamKey,
        team: team,
        playerIds: playerIds,
      );

      final newlyInvited = playerIds
          .where((id) => !previousSelection.contains(id))
          .toList();
      for (final playerId in newlyInvited) {
        await _notificationService.sendTeamRosterInvite(
          toUserId: playerId,
          matchId: widget.match.id,
          teamName: team.name,
          teamKey: teamKey,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_80626508c7'))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingRosterAction = false);
      }
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _playerStatusColor(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRosterStatusWrap(
    List<String> roster,
    Map<String, String> rosterStatus,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: roster
          .map(
            (playerId) => FutureBuilder<String>(
              future: _fetchPlayerName(playerId),
              initialData: _playerNameCache[playerId],
              builder: (context, snapshot) {
                final name = snapshot.data ?? tr('player');
                final status = rosterStatus[playerId] ?? 'pending';
                return _playerStatusChip(name, status);
              },
            ),
          )
          .toList(),
    );
  }

  Widget _playerStatusChip(String name, String status) {
    final color = _playerStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$name • ${_statusLabel(status)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return tr('il_fe00b67b6d');
      case 'declined':
        return tr('il_dce083a2c4');
      default:
        return tr('il_331551b0de');
    }
  }

  // Superseded by the design info rows (kept for reference).
  // ignore: unused_element
  Widget _buildStatCard(String icon, String value, String label) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(icon, style: TextStyle(fontSize: 20)),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  /// Whether the current viewer can join this match as an individual.
  bool get _canJoin {
    final user = AppAuth.currentUser;
    if (user == null) return false;
    final m = widget.match;
    if (m.organizerId == user.id) return false;
    if (m.isTeamMatch) return false;
    if (m.status != MatchStatus.open) return false;
    if (m.isUnplayedByTimeout) return false;
    // Direct invitees respond via the dock (accept/decline), not "join".
    if (_myInviteStatus == 'pending' || _myInviteStatus == 'declined') {
      return false;
    }
    if (_effectiveParticipants.length >= m.maxPlayers) return false;
    if (_effectiveParticipants.contains(user.id)) return false;
    if (_joinRequested || m.hasPendingApplication(user.id)) return false;
    if (m.isPrivate && !m.invitedFriends.contains(user.id)) return false;
    return true;
  }

  /// Whether the viewer has a pending join request (shows a "Requested" badge).
  bool get _hasRequestedJoin {
    final user = AppAuth.currentUser;
    if (user == null) return false;
    final m = widget.match;
    if (m.organizerId == user.id) return false;
    if (_effectiveParticipants.contains(user.id)) return false;
    return _joinRequested || m.hasPendingApplication(user.id);
  }

  Widget _buildParticipantsSection() {
    final filled = _effectiveParticipants.length;
    final cap = widget.match.maxPlayers;
    final pct = cap > 0 ? (filled / cap).clamp(0.0, 1.0) : 0.0;
    final remaining = cap - filled;
    final openSlots = remaining < 0 ? 0 : (remaining > 4 ? 4 : remaining);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('players'),
                  style:
                      FlapText.sora(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$filled',
                      style: FlapText.sora(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '/$cap',
                      style: FlapText.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FlapColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // fill progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [FlapColors.green, FlapColors.greenBright],
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 10.0;
              final tileW = (c.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final id in _effectiveParticipants)
                    SizedBox(width: tileW, child: _buildRosterTile(id)),
                  for (int i = 0; i < openSlots; i++)
                    SizedBox(
                      width: tileW,
                      // Only the first open spot acts as the join button.
                      child: _buildOpenSlot(
                        onJoin: (i == 0 && _canJoin && !_isJoining)
                            ? _joinMatch
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRosterTile(String participantId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sb
          .from('profiles')
          .select()
          .eq('id', participantId)
          .maybeSingle(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final displayName = (data?['display_name'] ??
                data?['first_name'] ??
                data?['author_name'] ??
                tr('player'))
            .toString()
            .trim();
        final firstName = displayName.split(RegExp(r'\s+')).first;
        final positionLabel =
            positionLabelForDisplay(data?['position'] as String?);
        final rating = data != null ? _profileOverallRatingFromRow(data) : 0.0;
        final isOrganizer = participantId == widget.match.organizerId;
        return GestureDetector(
          onTap: () => _openPlayerProfile(participantId, displayName),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0x0BFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOrganizer
                    ? const Color(0x594CAF50)
                    : FlapColors.border,
              ),
            ),
            child: Row(
              children: [
                UserChip(
                  userId: participantId,
                  name: displayName.isNotEmpty ? displayName : null,
                  size: 36,
                  showName: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        positionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            FlapText.sora(fontSize: 11, color: FlapColors.muted),
                      ),
                    ],
                  ),
                ),
                if (rating > 0) ...[
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: FlapColors.gold),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(2),
                        style: FlapText.cond(
                            fontSize: 15, color: FlapColors.gold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpenSlot({VoidCallback? onJoin}) {
    final joinable = onJoin != null;
    final slot = Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: joinable ? const Color(0x144CAF50) : const Color(0x05FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: joinable ? const Color(0x4D4CAF50) : FlapColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: joinable ? const Color(0x294CAF50) : const Color(0x0DFFFFFF),
            ),
            child: Icon(Icons.add,
                size: 18,
                color: joinable ? FlapColors.greenBright : FlapColors.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  joinable ? tr('join') : tr('match_open_spot'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.sora(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: joinable ? FlapColors.greenBright : FlapColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  joinable ? tr('match_open_spot') : tr('match_waiting'),
                  style: FlapText.sora(fontSize: 11, color: FlapColors.muted2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!joinable) return Opacity(opacity: 0.7, child: slot);
    return GestureDetector(
      onTap: onJoin,
      behavior: HitTestBehavior.opaque,
      child: slot,
    );
  }

  void _openPlayerProfile(String playerId, String displayName) {
    context.router.push(
      PlayerProfileRoute(playerId: playerId, playerName: displayName),
    );
  }

  // Superseded by the design roster grid (_buildRosterTile).
  // ignore: unused_element
  Widget _buildParticipantCard(String participantId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sb
          .from('profiles')
          .select()
          .eq('id', participantId)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildParticipantCardPlaceholder(participantId);
        }

        final userData = snapshot.data!;
        final positionLabel = positionLabelForDisplay(
          userData['position'] as String?,
        );
        final cityLabel = _localizedCity(userData['city'] as String?);
        final isOrganizer = participantId == widget.match.organizerId;
        final displayName =
            (userData['display_name'] ??
                    userData['first_name'] ??
                    userData['author_name'] ??
                    tr('player'))
                .toString()
                .trim();
        final avatarUrl = (userData['avatar_url'] ?? '').toString();
        final ratingValue = _profileOverallRatingFromRow(userData);

        void handleTap() => _openPlayerProfile(participantId, displayName);

        return GestureDetector(
          onTap: handleTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOrganizer
                    ? const Color(0xFF4caf50)
                    : Colors.white.withOpacity(0.08),
                width: isOrganizer ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PlayerAvatarButton(
                  userId: participantId,
                  displayName: displayName.isNotEmpty
                      ? displayName
                      : tr('player'),
                  avatarUrl: avatarUrl,
                  size: 48,
                  borderColor: isOrganizer
                      ? const Color(0xFF4caf50)
                      : Colors.white.withOpacity(0.2),
                  borderWidth: 2,
                  onTap: handleTap,
                ),
                const SizedBox(width: 12),

                // Player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName
                                  : tr('player'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isOrganizer) ...[
                            const SizedBox(width: 8),
                            _buildOrganizerBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$positionLabel • $cityLabel',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rating
                const SizedBox(width: 12),
                _buildRatingChip(ratingValue),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrganizerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF4caf50).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4caf50).withOpacity(0.6)),
      ),
      child: Text(
        tr('organizer'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRatingChip(double rating) {
    final value = rating > 0 ? rating : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4caf50).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Color(0xFF4caf50), size: 16),
              const SizedBox(width: 4),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('il_9f29530464'),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  String _localizedCity(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return tr('il_49980d893f');
    }
    return localizeCity(raw);
  }

  Widget _buildParticipantCardPlaceholder(String participantId) {
    final isOrganizer = participantId == widget.match.organizerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOrganizer
              ? const Color(0xFF4caf50)
              : Colors.white.withOpacity(0.08),
          width: isOrganizer ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isOrganizer
                  ? const Color(0xFF4caf50)
                  : const Color(0xFF2196f3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isOrganizer ? Icons.star : Icons.person,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '${tr('player')} ${participantId.length > 8 ? '${participantId.substring(0, 8)}...' : participantId}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isOrganizer) ...[
                      const SizedBox(width: 8),
                      _buildOrganizerBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr('il_a62e8c639a')} • ${tr('il_49980d893f')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildRatingChip(3.0),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final isParticipant =
        _effectiveParticipants.contains(currentUser.id) ||
        _acceptedInviteLocally;
    final hasPendingRequest = widget.match.hasPendingApplication(
      currentUser.id,
    );
    final isFull = _effectiveParticipants.length >= widget.match.maxPlayers;
    final isOrganizer = widget.match.organizerId == currentUser.id;

    if (widget.match.isTeamMatch && !isParticipant && !isOrganizer) {
      return _buildTeamInviteOrTeamOnlyMessage(currentUser.id);
    }

    if (isOrganizer &&
        widget.match.status != MatchStatus.finished &&
        widget.match.status != MatchStatus.cancelled &&
        !widget.match.isUnplayedByTimeout) {
      // Manage + share now live in the app bar (gear + share); no bottom dock.
      return const SizedBox.shrink();
    }

    if (isFull && !isParticipant) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('il_1b3438d9c8'),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isParticipant && widget.match.status == MatchStatus.finished) {
      final userId = currentUser.id;
      return FutureBuilder<double>(
        future: _getMyMatchAverageRating(widget.match.id, userId),
        builder: (context, snap) {
          final value = (snap.data ?? 0.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFF4CAF50), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value > 0
                            ? tr(
                                'il_f45eec2ce1',
                                args: [value.toStringAsFixed(2)],
                              )
                            : tr('il_41d1f1a079'),
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.router.push(MatchRatingRoute(match: widget.match));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.how_to_vote_rounded),
                  label: Text(tr('il_acddf82ed7')),
                ),
              ),
            ],
          );
        },
      );
    }

    if (isParticipant) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('il_537d8a9dcd'),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.match.isUnplayedByTimeout ||
        widget.match.status == MatchStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.35)),
        ),
        child: Text(
          tr('il_efda4a187c'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    if (hasPendingRequest) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.hourglass_top,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('join'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildShareButton(),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              tr('already_applied'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildPrimaryAction(currentUser.id)),
        const SizedBox(width: 16),
        // _buildShareButton(),
      ],
    );
  }

  Widget _buildPrimaryAction(String userId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sb
          .from('match_invites')
          .select('status')
          .eq('match_id', widget.match.id)
          .eq('user_id', userId)
          .maybeSingle(),
      builder: (context, snapshot) {
        final inviteStatus =
            _inviteStatusOverride ??
            (snapshot.data?['status'] ?? '').toString();
        if (inviteStatus == 'pending') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isRespondingInvite
                          ? null
                          : () => _respondMatchInvite(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4caf50),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRespondingInvite
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr('accept')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isRespondingInvite
                          ? null
                          : _confirmDeclineInvite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(tr('reject')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildShareButton(expand: false),
            ],
          );
        }
        if (inviteStatus == 'declined') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  tr('il_d3bcba9446'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              _buildShareButton(expand: false),
            ],
          );
        }
        // Join now lives on the open-spot slots + the app-bar join icon.
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTeamInviteOrTeamOnlyMessage(String userId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadMyTeamMatchInvite(userId),
      builder: (context, snapshot) {
        final invite = snapshot.data;
        final status = (invite?['status'] ?? '').toString();
        if (status == 'pending') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isRespondingTeamInvite
                          ? null
                          : () => _respondTeamMatchInvite(
                                requestId: (invite?['id'] ?? '').toString(),
                                accept: true,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4caf50),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRespondingTeamInvite
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr('accept')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isRespondingTeamInvite
                          ? null
                          : () => _respondTeamMatchInvite(
                                requestId: (invite?['id'] ?? '').toString(),
                                accept: false,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(tr('reject')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildShareButton(expand: false),
            ],
          );
        }
        return _buildTeamOnlyMessage();
      },
    );
  }

  Future<Map<String, dynamic>?> _loadMyTeamMatchInvite(String userId) async {
    final officerRows = await _sb
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId)
        .inFilter('role', ['captain', 'vice_captain']);
    final teamIds = (officerRows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['team_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (teamIds.isEmpty) return null;

    final requests = await _sb
        .from('team_match_requests')
        .select('id,status,target_team_id,created_at')
        .eq('match_id', widget.match.id)
        .inFilter('target_team_id', teamIds);
    final rows = (requests as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    if (rows.isEmpty) return null;
    rows.sort((a, b) {
      final aDate = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return rows.first;
  }

  Future<void> _respondTeamMatchInvite({
    required String requestId,
    required bool accept,
  }) async {
    if (requestId.isEmpty || _isRespondingTeamInvite) return;
    setState(() => _isRespondingTeamInvite = true);
    try {
      // Roster + match_teams propagation lives in the RPC. A direct UPDATE
      // here would silently leave invited-team players invisible to the match
      // and break stat aggregation.
      if (accept) {
        await _sb.rpc(
          'accept_team_match_request',
          params: <String, dynamic>{'p_request_id': requestId},
        );
      } else {
        await _sb.rpc(
          'decline_team_match_request',
          params: <String, dynamic>{'p_request_id': requestId},
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? tr('il_d585866af0') : tr('il_d3bcba9446')),
          backgroundColor:
              accept ? const Color(0xFF4caf50) : Colors.orangeAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRespondingTeamInvite = false);
    }
  }

  Widget _buildShareButton({bool expand = true}) {
    final button = Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _shareMatch,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  tr('share'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (expand) {
      return Expanded(child: button);
    }
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildTeamOnlyMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('il_a2822d30af'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRosterResponse(String teamKey, bool accept) async {
    if (_isProcessingRosterAction) return;
    setState(() => _isProcessingRosterAction = true);
    try {
      await _matchRepo.respondToRosterInvite(
        matchId: widget.match.id,
        teamKey: teamKey,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? tr('il_d585866af0') : tr('il_d3bcba9446')),
          backgroundColor: accept
              ? const Color(0xFF4caf50)
              : Colors.orangeAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingRosterAction = false);
      }
    }
  }

  // Manage now lives in the app-bar gear (kept for reference).
  // ignore: unused_element
  Widget _buildManageMatchButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          context.router.push(MatchManagementRoute(match: widget.match));
        },
        icon: const Icon(Icons.tune),
        label: Text(tr('il_dfe3bd5721')),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4caf50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _joinMatch() async {
    // Prevent double taps while request in flight.
    if (_isJoining) return;

    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    if (widget.match.hasPendingApplication(currentUser.id)) return;

    if (widget.match.isUnplayedByTimeout ||
        widget.match.status == MatchStatus.cancelled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_d11de119cf'))));
      return;
    }

    setState(() => _isJoining = true);

    try {
      final success = await _participationActions.applyForMatch(
        matchId: widget.match.id,
        userId: currentUser.id,
      );

      if (!mounted) return;

      if (success) {
        setState(() => _joinRequested = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('applied_wait')),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('already_applied')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _respondMatchInvite(bool accept) async {
    if (_isRespondingInvite) return;
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;

    setState(() => _isRespondingInvite = true);
    try {
      await _sb
          .from('match_invites')
          .update({'status': accept ? 'accepted' : 'declined'})
          .eq('match_id', widget.match.id)
          .eq('user_id', currentUser.id);

      if (accept) {
        await _sb.from('match_participants').upsert({
          'match_id': widget.match.id,
          'user_id': currentUser.id,
          'status': 'accepted',
          'joined_at': DateTime.now().toUtc().toIso8601String(),
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'match_id,user_id');
      }

      if (!mounted) return;
      setState(() {
        _inviteStatusOverride = accept ? 'accepted' : 'declined';
        if (accept) {
          _acceptedInviteLocally = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? tr('il_d585866af0') : tr('il_d3bcba9446')),
          backgroundColor: accept
              ? const Color(0xFF4caf50)
              : Colors.orangeAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRespondingInvite = false);
    }
  }

  Future<void> _confirmDeclineInvite() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('confirm')),
        content: Text(tr('match_decline_invite_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(tr('reject')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _respondMatchInvite(false);
    }
  }

  void _shareMatch() {
    final url = 'https://flap.app/match/${widget.match.id}';
    Share.share('${tr('il_5f7bc7026d', args: [widget.match.title])}$url');
  }

  String _getLevelText(MatchLevel level) {
    switch (level) {
      case MatchLevel.beginner:
        return tr('beginner');
      case MatchLevel.intermediate:
        return tr('il_3b1cfa63d7');
      case MatchLevel.advanced:
        return tr('il_9f088dbebd');
      case MatchLevel.professional:
        return tr('professional');
    }
  }

  Future<double> _getMyMatchAverageRating(String matchId, String userId) async {
    try {
      final rows = await _sb
          .from('match_player_ratings')
          .select('overall_rating')
          .eq('match_id', matchId)
          .eq('player_id', userId);
      if (rows.isEmpty) return 0.0;
      double sum = 0.0;
      for (final m in rows) {
        final r = (m['overall_rating'] is num)
            ? (m['overall_rating'] as num).toDouble()
            : 0.0;
        sum += r;
      }
      return sum / rows.length;
    } catch (_) {
      return 0.0;
    }
  }

  Widget _buildFinishedTeamsAndScoreSection(Match match) {
    final allTeams = match.allTeams;
    final isMultiTeamFormat = allTeams.length > 2;
    final hasCustomStats = match.multiTeamStats.isNotEmpty;

    if (isMultiTeamFormat || hasCustomStats) {
      return _buildMultiTeamFinishedSection(match, allTeams);
    }

    final aName = (match.teamA?.name.isNotEmpty == true)
        ? match.teamA!.name
        : tr('team_name_default_a');
    final bName = (match.teamB?.name.isNotEmpty == true)
        ? match.teamB!.name
        : tr('team_name_default_b');
    // If teams are missing or empty, show all participants split in half
    // to avoid desync with participants (MVP display-only fallback)
    List<String> aPlayers = List<String>.from(
      match.teamA?.playerIds ?? const <String>[],
    );
    List<String> bPlayers = List<String>.from(
      match.teamB?.playerIds ?? const <String>[],
    );
    if (aPlayers.isEmpty && bPlayers.isEmpty) {
      final all = List<String>.from(_effectiveParticipants);
      all.sort();
      final mid = (all.length / 2).floor();
      aPlayers = all.sublist(0, mid);
      bPlayers = all.sublist(mid);
    }
    final aScore = match.teamAScore ?? 0;
    final bScore = match.teamBScore ?? 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score and header
          Row(
            children: [
              Expanded(
                child: Text(
                  aName,
                  style: TextStyle(
                    color: Color(0xFF64B5F6),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  '$aScore : $bScore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    bName,
                    style: TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Two lineup columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _teamList(aPlayers, color: Color(0xFF64B5F6))),
              SizedBox(width: 12),
              Expanded(child: _teamList(bPlayers, color: Color(0xFFE57373))),
            ],
          ),
          if (match.goalsByPlayer.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildGoalsBreakdownSection(aName, bName, match),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiTeamFinishedSection(
    Match match,
    List<MatchTeamEntity> teams,
  ) {
    final palette = [
      const Color(0xFF4CAF50),
      const Color(0xFF42A5F5),
      const Color(0xFFFFB74D),
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
    ];

    final statsByIndex = <int, Map<String, dynamic>>{};
    for (final stat in match.multiTeamStats) {
      final idx = (stat['teamIndex'] as num?)?.toInt();
      if (idx != null) {
        statsByIndex[idx] = stat;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('il_ad6bbae214'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            match.multiTeamStats.isEmpty
                ? tr('il_e41d2dd5a0')
                : tr('il_c4c9155815'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (teams.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text(
                tr('il_c9484266af'),
                style: const TextStyle(color: Colors.white70),
              ),
            )
          else
            ...teams.asMap().entries.map((entry) {
              final index = entry.key;
              final team = entry.value;
              final stat = statsByIndex[index];
              final accent = palette[index % palette.length];
              return _buildMultiTeamTeamCard(team, index, stat, accent);
            }),
        ],
      ),
    );
  }

  Widget _buildGoalsBreakdownSection(
    String teamAName,
    String teamBName,
    Match match,
  ) {
    final goals = match.goalsByPlayer;
    if (goals.isEmpty) {
      return const SizedBox.shrink();
    }
    final assignments = match.playerTeamAssignments;
    final teamAEntries = <MapEntry<String, int>>[];
    final teamBEntries = <MapEntry<String, int>>[];
    goals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..forEach((entry) {
        final teamKey = assignments[entry.key];
        if (teamKey == 'teamB') {
          teamBEntries.add(entry);
        } else {
          teamAEntries.add(entry);
        }
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('il_116cd3982a'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _goalColumn(
                teamAName,
                const Color(0xFF64B5F6),
                teamAEntries,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _goalColumn(
                teamBName,
                const Color(0xFFE57373),
                teamBEntries,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _goalColumn(
    String heading,
    Color accent,
    List<MapEntry<String, int>> entries,
  ) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Text(
          tr('il_e53cc468ea'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _fetchPlayerName(entry.key),
                      builder: (context, snapshot) {
                        final name = snapshot.data ?? tr('il_64aee8c6cb');
                        return Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '×${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiTeamTeamCard(
    MatchTeamEntity team,
    int index,
    Map<String, dynamic>? stat,
    Color accent,
  ) {
    final wins = (stat?['wins'] ?? 0) as num;
    final goals = (stat?['goals'] ?? 0) as num;
    final label = team.name.isNotEmpty
        ? team.name
        : tr('il_d040fd4027', args: ['${index + 1}']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (team.playerIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            TeamRosterTotalRatingBadge(
              playerIds: team.playerIds,
              accent: accent,
              iconSize: 18,
              fontSize: 15,
              padding: EdgeInsets.zero,
              showTotalRatingLabel: true,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _statPill(
                label: tr('il_41da8b729f'),
                value: wins.toString(),
                icon: Icons.emoji_events,
                accent: accent,
              ),
              const SizedBox(width: 12),
              _statPill(
                label: tr('il_116cd3982a'),
                value: goals.toString(),
                icon: Icons.sports_soccer,
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _teamList(team.playerIds, color: accent),
        ],
      ),
    );
  }

  Widget _statPill({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamList(List<String> ids, {required Color color}) {
    if (ids.isEmpty) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          tr('match_roster_missing'),
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ids.map((id) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _fetchUserProfile(id),
          builder: (context, snap) {
            final profile = snap.data ??
                {'displayName': tr('player'), 'avatarUrl': ''};
            final displayName = (profile['displayName'] as String).trim();
            final avatarUrl = (profile['avatarUrl'] as String).trim();
            final initials =
                (displayName.isNotEmpty
                        ? displayName
                              .split(' ')
                              .map((p) => p.isNotEmpty ? p[0] : '')
                              .take(2)
                              .join()
                        : (id.isNotEmpty
                              ? id.substring(0, id.length >= 2 ? 2 : 1)
                              : '?'))
                    .toUpperCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: GestureDetector(
                onTap: () {
                  context.router.push(
                    PlayerProfileRoute(playerId: id, playerName: displayName),
                  );
                },
                child: Row(
                  children: [
                    PlayerAvatarButton(
                      userId: id,
                      displayName: displayName.isNotEmpty
                          ? displayName
                          : initials,
                      avatarUrl: avatarUrl,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName
                            : tr(
                                'player_display_id_fallback',
                                namedArgs: {
                                  'label': tr('player'),
                                  'id': id.substring(
                                    0,
                                    id.length >= 6 ? 6 : id.length,
                                  ),
                                },
                              ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
