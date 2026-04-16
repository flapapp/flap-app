import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/matches/data/rating_service.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/features/tournaments/domain/entities/tournament_summary.dart';
import 'package:flap_app/features/tournaments/domain/repositories/tournaments_repository.dart';
import 'package:flap_app/features/tournaments/presentation/screens/tournament_details_screen.dart';
import 'package:flap_app/features/tournaments/presentation/screens/tournaments_screen.dart';
import 'package:flap_app/features/matches/domain/repositories/matches_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flap_app/widgets/user_chip.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/media/flap_cached_image.dart';
import 'package:flap_app/core/navigation/flap_navigation.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/core/theme/app_colors.dart';
import 'package:flap_app/core/theme/app_spacing.dart';
import 'package:flap_app/shared/ui/app_card.dart';

@RoutePage()
class MatchesScreen extends StatefulWidget {
  final int? initialTabIndex;

  MatchesScreen({super.key, this.initialTabIndex});

  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with SingleTickerProviderStateMixin {
  bool _isLeaving = false;
  late TabController _tabController;
  late Future<List<TournamentSummary>> _ongoingTournamentsFuture;
  bool _ongoingFutureReady = false;

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t('confirm'))),
        ],
      ),
    );
  }

  MatchesRepository get _matchesRepo => context.read<MatchesRepository>();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: (widget.initialTabIndex ?? 0).clamp(0, 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ongoingFutureReady) {
      _ongoingFutureReady = true;
      _ongoingTournamentsFuture = context.read<TournamentsRepository>().listOngoingTournaments();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isUpcomingPickupMatch(Match m) {
    if (m.status == MatchStatus.finished || m.status == MatchStatus.cancelled) {
      return false;
    }
    final now = DateTime.now();
    final matchDay = DateTime(m.date.year, m.date.month, m.date.day);
    final today = DateTime(now.year, now.month, now.day);
    return !matchDay.isBefore(today);
  }

  Future<void> _refreshTournaments() async {
    setState(() {
      _ongoingTournamentsFuture = context.read<TournamentsRepository>().listOngoingTournaments();
    });
    await _ongoingTournamentsFuture;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        title: InkWell(
          onTap: () => flapOpenMainTab(context, FlapMainTab.home),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/logo/flap_logo.jpg', fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FLAP',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    I18n.inline('Матч-центр', 'Match center'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
    StreamBuilder<int>(
      stream: _notificationService.getUnreadCount(),
            builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textPrimary,
                size: 20,
              ),
              onPressed: () => context.pushRoute(const NotificationsRoute()),
              padding: EdgeInsets.zero,
              tooltip: I18n.t('notifications'),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(unreadCount > 9 ? '9+' : unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        );
      },
          ),
    StreamBuilder<Map<String, dynamic>>(
      stream: AppAuthContext.userId != null
          ? context.read<ProfileRepository>().watchLegacyUserMap(AppAuthContext.userId!)
          : Stream.value(<String, dynamic>{}),
      builder: (context, snapshot) {
        String avatarUrl = '';
        String displayName = '';
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final d = snapshot.data!;
          avatarUrl = (d['avatarUrl'] ?? d['avatar'] ?? d['photoUrl'] ?? '').toString();
          displayName = (d['displayName'] ?? d['name'] ?? d['authorName'] ?? d['email']?.toString().split('@').first ?? I18n.inline('Г', 'U')).toString();
        }
        return IconButton(
          padding: EdgeInsets.zero,
          onPressed: () => flapOpenMainTab(context, FlapMainTab.profile),
          icon: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.accentPrimary,
            backgroundImage:
                avatarUrl.isNotEmpty ? flapCachedImageProvider(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.bgBase,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
                ),
              );
            },
          ),
    const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accentPrimary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: I18n.inline('Турніри', 'Tournaments')),
              Tab(text: I18n.inline('Матчі', 'Matches')),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTournamentsTab(),
          _buildMatchesTab(),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      onRefresh: _refreshTournaments,
      child: FutureBuilder<List<TournamentSummary>>(
        future: _ongoingTournamentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            );
          }
          final items = snapshot.data ?? const <TournamentSummary>[];
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: _buildTabEmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: I18n.inline('Немає активних турнірів', 'No ongoing tournaments'),
                    subtitle: I18n.inline(
                      'Завершені та скасовані приховані',
                      'Completed and cancelled are hidden',
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
                child: AppCard(
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TournamentDetailsScreen(
                            tournamentId: item.id,
                            title: item.name,
                            createdByUserId: item.createdBy,
                          ),
                        ),
                      );
                    },
                    title: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      [
                        item.type,
                        item.status,
                        if (item.endDate != null)
                          '${I18n.inline('до', 'until')} ${item.endDate!.toLocal().toString().split(' ').first}',
                      ].join(' • '),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMatchesTab() {
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      onRefresh: () async => setState(() {}),
      child: StreamBuilder<List<Match>>(
        stream: _matchesRepo.getAvailableMatches().map(
          (list) => list.where(_isUpcomingPickupMatch).toList(growable: false),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            );
          }
          final matches = snapshot.data ?? const <Match>[];
          if (matches.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: _buildTabEmptyState(
                    icon: Icons.sports_soccer_outlined,
                    title: I18n.inline('Немає майбутніх матчів', 'No upcoming matches'),
                    subtitle: I18n.inline(
                      'Матчі на сьогодні й пізніше',
                      'Matches from today onward',
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 100),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final m = matches[index];
              return InkWell(
                onTap: () => context.pushRoute(MatchDetailsRoute(match: m)),
                child: _buildMatchCard(m),
              );
            },
          );
        },
      ),
    );
  }


  Widget _buildTabEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _shareMatch(Match match) {
    final url = 'https://flap.app/match/${match.id}';
    Share.share(I18n.inline('Приєднуйся до матчу: ', 'Join the match: ') + url);
  }

  // Метод для розрахунку середнього рейтингу учасників
  Future<double> _calculateAverageRating(List<String> participantIds) async {
    try {
      if (participantIds.isEmpty) return 3.0; // Початковий рейтинг

      double totalRating = 0.0;
      int ratedParticipants = 0;

      for (final participantId in participantIds) {
        final rating = await RatingService().getUserRating(participantId);
        totalRating += rating;
        ratedParticipants++;
      }

      return ratedParticipants > 0 ? totalRating / ratedParticipants : 3.0;
    } catch (e) {
      print('Error calculating average rating: $e');
      return 3.0;
    }
  }

  // Метод для створення картки матчу
    Widget _buildMatchCard(Match match) {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

  return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
      child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  match.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(match.status, match: match).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _getStatusColor(match.status, match: match).withOpacity(0.55),
                  ),
                ),
                child: Text(
                  _getStatusText(match.status),
                  style: TextStyle(
                    color: _getStatusColor(match.status, match: match),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildMatchDetails(match),

          const SizedBox(height: 16),

          _buildActionButtons(match, currentUser.id),
          if (match.coverPhotoUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildMatchPhotoFooter(match),
          ],
        ],
      ),
      ),
    );
  }

 Widget _buildMatchPhotoFooter(Match match) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlapCachedImage(
              imageUrl: match.coverPhotoUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              errorWidget: (_, __, ___) => Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      I18n.inline(
                        'Післяматчевий момент',
                        'Match highlight',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (match.teamAScore != null && match.teamBScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${match.teamAScore}:${match.teamBScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// ... existing code ...

Widget _metaChip({
  required IconData icon,
  required String label,
  Color iconColor = Colors.white70,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildMatchDetails(Match match) {
  final totalParticipants = match.participants.length;
  final confirmedCount = match.isTeamMatch
      ? match.confirmedParticipantsCount
      : totalParticipants;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _metaChip(
            icon: Icons.calendar_today,
            label: '${match.date.day}.${match.date.month}.${match.date.year}',
          ),
          _metaChip(
            icon: Icons.access_time,
            label: match.time,
          ),
          _metaChip(
            icon: Icons.star,
            label: '${I18n.t('level_colon')} ${_getLevelText(match.level)}',
            iconColor: Colors.amber,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Icon(Icons.location_city, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              match.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      FutureBuilder<double>(
        future: _calculateAverageRating(match.participants),
        builder: (context, snap) {
          final avg = (snap.hasData ? snap.data! : 0.0).toStringAsFixed(2);
          return Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFD54F), size: 16),
              const SizedBox(width: 8),
              Text(
                '${I18n.t('average_rating')}: $avg',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
Row(
  children: [
    const Icon(Icons.people, color: Colors.white70, size: 16),
    const SizedBox(width: 8),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$totalParticipants/${match.maxPlayers} ${I18n.t('participants')}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        if (match.isTeamMatch)
          Text(
            I18n.inline('Підтверджено: $confirmedCount', 'Confirmed: $confirmedCount'),
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
      ],
    ),
    Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(match.status, match: match),
        borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
        _getStatusText(match.status),
        style: const TextStyle(
                      color: Colors.white,
          fontSize: 12,
                      fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
const SizedBox(height: 8),

      if (match.isTeamMatch) ...[
        const SizedBox(height: 4),
        _buildTeamMatchBanner(match),
      ],

// Аватарки окремим рядком, щоб не було переповнення
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.only(top: 4, bottom: 4),
  child: Row(
    children: match.participants.take(10).map((id) {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        child: UserChip(userId: id, size: 22, showName: false),
      );
    }).toList(),
  ),
),
      
      SizedBox(height: 8),
      
      // Організатор
      Row(
        children: [
          PlayerAvatarButton(
            userId: match.organizerId,
            displayName: match.organizerName ?? I18n.t('organizer'),
            size: 36,
            backgroundColor: const Color(0xFF1f2b3a),
            borderColor: Colors.white.withOpacity(0.15),
            borderWidth: 1.5,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t('organizer'),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  match.organizerName ?? I18n.t('player'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildActionButtons(Match match, String currentUserId) {
  // Перевіряємо статус користувача в матчі
  final rawUserStatus = match.getUserStatus(currentUserId);
  final userStatus = _convertUserStatus(rawUserStatus);

  // Діагностика
  print('DEBUG: Match ${match.title}');
  print('DEBUG: Raw user status: $rawUserStatus');
  print('DEBUG: Converted user status: $userStatus');
  print('DEBUG: Match status: ${match.status}');
  print('DEBUG: Participants: ${match.participants}');
  print('DEBUG: Current user: $currentUserId');
  print('DEBUG: Organizer ID: ${match.organizerId}');

  final isOrganizer = match.organizerId == currentUserId;
  final isParticipant = match.participants.contains(currentUserId);
  if (match.isTeamMatch && !isOrganizer && !isParticipant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  I18n.inline(
                      'Це командний матч. Долучитись можна лише через запрошення від капітана.',
                      'Team-only match. You can join only via a team invite.'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              context.pushRoute(MatchDetailsRoute(match: match)),
          icon: const Icon(Icons.info_outline, size: 16),
          label: Text(I18n.t('details'),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(0, 40),
          ),
        ),
      ],
    );
  }

  // Приватний матч — лише за запрошенням
  if (match.isPrivate && !match.invitedFriends.contains(currentUserId)) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock, color: Colors.white70, size: 16),
          SizedBox(width: 8),
          Text('Приватний матч: доступ за запрошенням', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // Відкритий матч і користувач не учасник — показати три компактні кнопки
  if (rawUserStatus == 'none' && match.status == MatchStatus.open) {
    return LayoutBuilder(
  builder: (context, c) {
    final isNarrow = c.maxWidth < 360;

    final joinBtn = ElevatedButton.icon(
      onPressed: () => _applyForMatch(match.id),
      icon: const Icon(Icons.person_add_alt_1, size: 16),
      label: Text(I18n.t('join'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4caf50),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
      ),
    );

    final detailsBtn = OutlinedButton.icon(
      onPressed: () => context.pushRoute(MatchDetailsRoute(match: match)),
      icon: const Icon(Icons.info_outline, size: 16),
      label: Text(I18n.t('details'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
      ),
    );

    final shareBtn = OutlinedButton.icon(
      onPressed: () => _shareMatch(match),
      icon: const Icon(Icons.share, size: 16),
      label: Text(I18n.inline('Поділитися', 'Share'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
      ),
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: joinBtn),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: detailsBtn),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: shareBtn),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: SizedBox(height: 40, child: joinBtn)),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 40, child: detailsBtn)),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 40, child: shareBtn)),
      ],
    );
  },
);
  }

  // Інші стани — дві компактні кнопки
  return Row(
    children: [
      // Деталі (outline)
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: TextButton(
            onPressed: () {
              context.pushRoute(MatchDetailsRoute(match: match));
            },
            child: Text(
              I18n.t('details'),
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Share / Join CTA
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4caf50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: () {
              if (match.status == MatchStatus.open && rawUserStatus == 'none') {
                _applyForMatch(match.id);
                return;
              }
              final url = 'https://flap.app/match/${match.id}';
              Share.share(I18n.inline('Приєднуйся до матчу: ', 'Join the match: ') + url);
            },
            child: Text(
              match.status == MatchStatus.open && rawUserStatus == 'none'
                  ? I18n.inline('Приєднатися', 'Join')
                  : I18n.inline('Поділитися', 'Share'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildTeamMatchBanner(Match match) {
    final teamAName = (match.teamA?.name?.isNotEmpty ?? false)
        ? match.teamA!.name
        : I18n.inline('Команда організатора', 'Host team');
    final teamBName = (match.teamB?.name?.isNotEmpty ?? false)
        ? match.teamB!.name
        : (match.teamBId != null
            ? I18n.inline('Команда суперника', 'Opponent team')
            : I18n.inline('Очікує суперника', 'Waiting for opponent'));
    final teamARoster =
        match.teamRosters['teamA'] ?? match.teamA?.playerIds ?? const <String>[];
    final teamBRoster =
        match.teamRosters['teamB'] ?? match.teamB?.playerIds ?? const <String>[];

    final teamAStatus = match.teamAStatus ?? 'confirmed';
    final teamBStatus =
        match.teamBStatus ?? (match.teamBId == null ? 'pending' : 'confirmed');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_soccer, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                I18n.inline('Командний матч', 'Team match'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTeamMatchRow(teamAName, teamAStatus, teamARoster),
          const SizedBox(height: 8),
          _buildTeamMatchRow(teamBName, teamBStatus, teamBRoster),
        ],
      ),
    );
  }

  Widget _buildTeamMatchRow(
      String teamName, String status, List<String> roster) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                teamName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildTeamStatusChip(status),
          ],
        ),
        if (roster.isNotEmpty) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: roster.take(8).map((playerId) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: UserChip(userId: playerId, size: 24, showName: false),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTeamStatusChip(String status) {
    final text = _getTeamStatusText(status);
    final color = _getTeamStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getTeamStatusText(String? status) {
    switch (status) {
      case 'confirmed':
        return I18n.inline('Підтверджено', 'Confirmed');
      case 'declined':
        return I18n.inline('Відхилено', 'Declined');
      default:
        return I18n.inline('Очікує', 'Pending');
    }
  }

  Color _getTeamStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }




  // Метод для отримання кольору статусу
  Color _getStatusColor(MatchStatus status, {Match? match}) {
  if (match?.isUnplayedByTimeout == true) {
    return const Color(0xFF607D8B);
  }
  switch (status) {
    case MatchStatus.open:
      return const Color(0xFF4caf50);
    case MatchStatus.full:
      return Colors.blue;
    case MatchStatus.inProgress:
      return Colors.orange;
    case MatchStatus.finished:
      return Colors.grey;
    case MatchStatus.cancelled:
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String _getStatusText(MatchStatus status, {Match? match}) {
  if (match?.isUnplayedByTimeout == true) {
    return I18n.inline('Незіграний', 'Unplayed');
  }
  switch (status) {
    case MatchStatus.open:
      return I18n.t('status_open');
    case MatchStatus.full:
      return I18n.t('status_full');
    case MatchStatus.inProgress:
      return I18n.t('status_in_progress');
    case MatchStatus.finished:
      return I18n.t('status_finished');
    case MatchStatus.cancelled:
      return I18n.t('status_cancelled');
    default:
      return I18n.t('unknown');
  }
}

IconData _getStatusIcon(MatchStatus status) {
  switch (status) {
    case MatchStatus.open:
      return Icons.person;
    case MatchStatus.full:
      return Icons.check_circle;
    case MatchStatus.inProgress:
      return Icons.play_circle;
    case MatchStatus.finished:
      return Icons.done_all;
    case MatchStatus.cancelled:
      return Icons.cancel;
    default:
      return Icons.help;
    }
  }

  // Метод для форматування дати та часу
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return I18n.inline('Сьогодні', 'Today') + ' ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return I18n.inline('Завтра', 'Tomorrow') + ' ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}.${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // Допоміжні методи для фільтрації
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _getLevelText(MatchLevel level) {
    switch (level) {
      case MatchLevel.beginner:
        return I18n.t('beginner');
      case MatchLevel.intermediate:
        return I18n.t('intermediate');
      case MatchLevel.advanced:
        return I18n.t('advanced');
      case MatchLevel.professional:
        return I18n.t('professional');
      default:
        return I18n.t('unknown');
    }
  }

  // Заголовок секції "Мої матчі"
  Widget _buildMyMatchesHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            I18n.t('my_matches'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TournamentsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4caf50),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              I18n.inline('Create tournament', 'Create tournament'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Картка матчу для "Мої матчі"
// version_0.1/lib/screens/matches_screen.dart

Widget _buildMyMatchCard(Match match) {
  final currentUser = AppAuthContext.currentUser;
  final isOrganizer = currentUser?.id == match.organizerId;
  final role = isOrganizer ? I18n.t('organizer') : I18n.t('participant');

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Шапка картки: статус окремим рядком, щоб уникнути overflow
Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    // Дата/час + локація у Wrap: перенос і еліпсиси на вузьких екранах
    Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
        const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
          child: Text(
                        '${match.date.day}.${match.date.month} о ${match.time}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        const Icon(Icons.location_on, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 160),
          child: Text(
                        match.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
                      ),
                    ],
                  ),
    const SizedBox(height: 6),
    Row(
      children: [
        isOrganizer ? const Text('👑', style: TextStyle(fontSize: 16))
                    : const Icon(Icons.person, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(role, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    ),
    const SizedBox(height: 8),
    
  ],
),
        SizedBox(height: 16),

        Row(
  children: [
    Icon(Icons.people, color: Colors.white70, size: 16),
    SizedBox(width: 4),
    Text(
      '${match.currentPlayers}/${match.maxPlayers}',
      style: TextStyle(color: Colors.white70, fontSize: 14),
    ),
    Spacer(),
            Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(match.status),
                borderRadius: BorderRadius.circular(20),
              ),
      child: Text(
                    _getStatusText(match.status, match: match),
        style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
        ),
      ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Аватарки учасників (ініціали)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            children: match.participants.take(10).map((id) {
              return Container(
                margin: const EdgeInsets.only(right: 6),
    child: UserChip(
      userId: id,
      size: 24, // ≈ радіус 12
      showName: false,
                ),
              );
            }).toList(),
          ),
        ),

        SizedBox(height: 16),

        // Кнопки дій
        Row(
          children: [
    if (isOrganizer &&
    match.status != MatchStatus.finished &&
    match.status != MatchStatus.cancelled &&
    !match.isUnplayedByTimeout)
              ElevatedButton(
                onPressed: () {
                  context.pushRoute(MatchManagementRoute(match: match));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4caf50),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  I18n.t('manage'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
    if (isOrganizer && match.status != MatchStatus.finished) SizedBox(width: 8),
    ElevatedButton(
      onPressed: () {
        context.pushRoute(MatchDetailsRoute(match: match));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        I18n.t('details'),
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
          ],
        ),

        // Кнопка "Вийти з матчу" (учасник, не організатор, відкритий матч)
        if (!isOrganizer &&
            match.status == MatchStatus.open &&
            !match.isUnplayedByTimeout &&
            currentUser != null &&
            match.participants.contains(currentUser.id)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isLeaving
                    ? null
                    : () async {
                        final sure = await _confirm(I18n.t('leave_match_confirm'), I18n.t('leave_match_sure'));
                        if (sure != true) return;
                        setState(() => _isLeaving = true);
                        await _onLeaveMatch(match);
                        setState(() => _isLeaving = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _isLeaving ? I18n.t('leaving') : I18n.t('leave_match'),
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],

        // Швидкі дії для організатора
        if (isOrganizer &&
    match.status != MatchStatus.cancelled &&
    !match.isUnplayedByTimeout) ...[
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final canStartNow = match.hasTeams
                ? match.hasConfirmedPlayersForBothTeams
                : match.participants.length >= 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            children: [
              if (!match.hasTeams &&
                  match.participants.length >= 4 &&
                  match.status != MatchStatus.finished)
                ElevatedButton(
                  onPressed: () async {
                    final sure = await _confirm('Сформувати команди?', 'Буде виконано автобаланс за рейтингом.');
                    if (sure != true) return;
                    await _onAutoBalance(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66bb6a),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Автобаланс',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (!match.hasTeams && match.participants.length >= 4)
                const SizedBox(width: 8),
              if (match.hasTeams &&
                  match.status != MatchStatus.inProgress &&
                  match.status != MatchStatus.finished)
                ElevatedButton(
                  onPressed: canStartNow
                      ? () async {
                    final sure = await _confirm('Почати матч?', 'Після початку рахунок стане доступним і дії зміняться.');
                    if (sure != true) return;
                    await _onStartMatch(match);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canStartNow ? const Color(0xFF2196f3) : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    I18n.t('start_match'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (match.status != MatchStatus.inProgress && match.hasTeams)
                const SizedBox(width: 8),
              if (match.status == MatchStatus.inProgress)
                ElevatedButton(
                  onPressed: () async {
                    final sure = await _confirm(I18n.t('finish_match') + '?', I18n.inline('Потрібно ввести рахунок команд.', 'Need to enter team scores.'));
                    if (sure != true) return;
                    await _onFinishMatch(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    I18n.t('finish_match'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
            if (match.hasTeams &&
                match.status == MatchStatus.open &&
                !canStartNow)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  I18n.inline(
                    'Потрібно щонайменше по одному підтвердженому гравцю з кожної команди.',
                    'Need at least one confirmed player per team to start.',
                  ),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
          ],
            );
          }),
        ],

        // Інфо для неорганізаторів
        if (!isOrganizer) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  I18n.inline('Лише організатор може формувати команди, розпочати або завершити матч.', 'Only organizer can form teams, start or finish match.'),
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
  Future<void> _onStartMatchPrep(Match match) async {
    final ok = await _matchesRepo.startMatch(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? I18n.inline('Матч розпочато', 'Match started') : I18n.inline('Не вдалося розпочати матч', 'Failed to start match')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }


  // Метод для подачі заявки на матч
  Future<void> _applyForMatch(String matchId) async {
    try {
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.inline('Потрібно увійти в систему', 'You need to sign in')), backgroundColor: Colors.red),
        );
        return;
      }

      final success = await _matchesRepo.applyForMatch(matchId, currentUser.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Заявку прийнято, очікуйте підтвердження', 'Request sent, awaiting approval')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Ви вже подали заявку', 'You already applied')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка: $e', 'Error: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // Вихід з матчу
Future<void> _onLeaveMatch(Match match) async {
  try {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Потрібно увійти в систему', 'You need to sign in')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ok = await _matchesRepo.leaveMatch(match.id, currentUser.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? I18n.t('left_match') : I18n.t('leave_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${I18n.t('error')}: $e'), backgroundColor: Colors.red),
    );
  }
}
    // Дії організатора
  Future<void> _onAutoBalance(Match match) async {
    final ok = await _matchesRepo.autoBalanceTeams(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? I18n.t('teams_balanced') : I18n.t('teams_balance_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }

  Future<void> _onStartMatch(Match match) async {
    final ok = await _matchesRepo.startMatch(match.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? I18n.t('match_started') : I18n.t('match_start_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }

  Future<void> _onFinishMatch(Match match) async {
    final scores = await _showFinishDialog();
    if (scores == null) return;

    final int a = scores['teamAScore']!;
    final int b = scores['teamBScore']!;
    final MatchResult result = (a > b) ? MatchResult.teamAWins : (b > a) ? MatchResult.teamBWins : MatchResult.draw;
    final goals = await _collectGoalsForMatch(match);
    if (goals == null) return;
    if (!_validateGoalsAgainstScore(match, goals, a, b)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Суми голів по командах не збігаються з рахунком. Перевірте дані.',
              'Goals per team do not match the final score. Please adjust.',
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final ok = await _matchesRepo.finishMatch(match.id, result, a, b, goalsByPlayer: goals);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? I18n.t('match_finished') : I18n.t('match_finish_failed')),
      backgroundColor: ok ? const Color(0xFF4caf50) : Colors.red,
    ));
    if (ok) setState(() {});
  }

  Future<Map<String, int>?> _showFinishDialog() async {
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('finish_match')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: I18n.t('goals_team_a'))),
            TextField(controller: bCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: I18n.t('goals_team_b'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(I18n.t('cancel'))),
          ElevatedButton(
            onPressed: () {
              final int? a = int.tryParse(aCtrl.text);
              final int? b = int.tryParse(bCtrl.text);
              if (a == null || b == null || a < 0 || b < 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('enter_valid_scores')), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx, {'teamAScore': a, 'teamBScore': b});
            },
            child: Text(I18n.t('confirm')),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>?> _collectGoalsForMatch(Match match) async {
    final ids = match.participants;
    if (ids.isEmpty) return {};
    final names = await _loadParticipantNames(ids);
    final assignments = match.playerTeamAssignments;
    final Map<String, List<String>> grouped = {
      'teamA': [],
      'teamB': [],
      'free': [],
    };
    for (final id in ids) {
      final key = assignments[id] ?? 'free';
      grouped.putIfAbsent(key, () => <String>[]);
      grouped[key]!.add(id);
    }
    final controllers = {
      for (final id in ids) id: TextEditingController(text: '0')
    };
    final map = await showDialog<Map<String, int>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(I18n.inline('Голи гравців', 'Player goals')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _buildGoalInputSections(
                grouped: grouped,
                names: names,
                controllers: controllers,
                match: match,
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(I18n.t('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, <String, int>{}), child: Text(I18n.inline('Пропустити', 'Skip'))),
            ElevatedButton(
              onPressed: () {
                final result = <String, int>{};
                controllers.forEach((id, ctrl) {
                  final val = int.tryParse(ctrl.text) ?? 0;
                  if (val > 0) result[id] = val;
                });
                Navigator.pop(ctx, result);
              },
              child: Text(I18n.t('confirm')),
            ),
          ],
        );
      },
    );
    controllers.values.forEach((c) => c.dispose());
    return map;
  }

  bool _validateGoalsAgainstScore(
    Match match,
    Map<String, int> goals,
    int teamAScore,
    int teamBScore,
  ) {
    if (match.hasTeams) {
      final assignments = match.playerTeamAssignments;
      int sumA = 0;
      int sumB = 0;
      goals.forEach((playerId, value) {
        final teamKey = assignments[playerId];
        if (teamKey == 'teamB') {
          sumB += value;
        } else {
          sumA += value;
        }
      });
      return sumA == teamAScore && sumB == teamBScore;
    }
    final total = goals.values.fold<int>(0, (prev, value) => prev + value);
    return total == (teamAScore + teamBScore);
  }

  List<Widget> _buildGoalInputSections({
    required Map<String, List<String>> grouped,
    required Map<String, String> names,
    required Map<String, TextEditingController> controllers,
    required Match match,
  }) {
    final sections = <Widget>[];
    final order = ['teamA', 'teamB', 'free'];

    String _teamLabel(String key) {
      switch (key) {
        case 'teamA':
          return match.teamA?.name ?? I18n.inline('Команда А', 'Team A');
        case 'teamB':
          return match.teamB?.name ?? I18n.inline('Команда Б', 'Team B');
        default:
          return I18n.inline('Інші гравці', 'Other players');
      }
    }

    for (final key in order) {
      final players = grouped[key] ?? const <String>[];
      if (players.isEmpty) continue;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            _teamLabel(key),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      sections.addAll(players.map((id) {
        final name = names[id] ?? I18n.t('player');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(name)),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: controllers[id],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: I18n.t('goals'),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        );
      }));
    }

    return sections;
  }

  Future<Map<String, String>> _loadParticipantNames(List<String> ids) async {
    final names = <String, String>{};
    final repo = context.read<UserProfileRepository>();
    for (final id in ids) {
      try {
        final p = await repo.loadProfile(id);
        final label = p?.resolveDisplayName();
        names[id] = (label != null && label.isNotEmpty) ? label : I18n.t('player');
      } catch (_) {
        names[id] = I18n.t('player');
      }
    }
    return names;
  }
    // Метод для отримання кольору рівня
  Color _getLevelColor(MatchLevel level) {
    switch (level) {
      case MatchLevel.beginner:
        return Colors.green;
      case MatchLevel.intermediate:
        return Colors.yellow;
      case MatchLevel.advanced:
        return Colors.orange;
      case MatchLevel.professional:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  String _convertUserStatus(String status) {
  switch (status) {
    case 'organizer':
      return I18n.t('manage');
    case 'participant':
      return I18n.t('participant');
    case 'pending':
      return I18n.inline('Заявка подана', 'Application sent');
    case 'rejected':
      return I18n.t('reject');
    case 'none':
      return I18n.t('apply');
    default:
      return I18n.t('apply');
  }
  }
}

