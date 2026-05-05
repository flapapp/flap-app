import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flap_app/core/supabase/supabase_date.dart';

import '../../../../router/app_router.dart';
import '../../../../core/di/injection.dart';
import '../../application/match_management_actions_use_case.dart';
import '../../domain/repositories/matches_repository.dart';
import '../../data/models/match.dart';
import 'match_invite_search_screen.dart';
import 'finish_match_flow_page.dart';
import '../../../../widgets/team_logo_button.dart';
import '../../../../widgets/player_avatar_button.dart';
import 'dart:math';
import 'package:flap_app/core/auth/app_auth.dart';

/// DB column is [profiles.overall_rating], not `rating`.
double _profileOverallRatingFromRow(Map<String, dynamic> data) {
  final v = data['overall_rating'] ?? data['rating'];
  if (v is num) return v.toDouble();
  return 0.0;
}

@RoutePage()
class MatchManagementScreen extends StatefulWidget {
  final Match match;
  final int initialTabIndex;

  const MatchManagementScreen({
    Key? key,
    required this.match,
    this.initialTabIndex = 1,
  }) : super(key: key);

  @override
  _MatchManagementScreenState createState() => _MatchManagementScreenState();
}

class _MatchManagementScreenState extends State<MatchManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final bool _isOwner;

  MatchesRepository get _matchRepo => sl<MatchesRepository>();
  MatchManagementActionsUseCase get _managementActions =>
      sl<MatchManagementActionsUseCase>();
  final SupabaseClient _sb = Supabase.instance.client;

  List<String> _pendingApplications = [];
  List<String> _participants = [];
  bool _isLoading = false;
  bool _shufflingTeams = false;
  final Set<String> _busyUserIds = {};

  bool _editMode = false;
  List<String> _editingTeamA = [];
  List<String> _editingTeamB = [];
  final Set<String> _locked = {};
  bool _isSavingTeams = false;
  bool _showResultForm = false;
  bool _savingResults = false;
  final Map<int, TextEditingController> _winsControllers = {};
  final Map<int, TextEditingController> _goalsControllers = {};
  Map<String, double> _ratingsCache = {};
  Match? _latestMatch;
  int _teamCount = 2;
  final List<Color> _teamColors = [
    const Color(0xFF1976D2),
    const Color(0xFF8E24AA),
    const Color(0xFF43A047),
    const Color(0xFFFF7043),
  ];
  List<List<String>> _editingTeams = [[], []];

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, _ClubInfo> _clubCache = {};

  Stream<Match?> _liveMatchStream() {
    return _sb
        .from('matches')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => _matchRepo.fetchMatchById(widget.match.id));
  }

  /// Prefer realtime payload vs [_latestMatch] by [Match.updatedAt] so local reload after mutations
  /// (e.g. form teams) wins until the stream catches up with the same or newer row.
  Match? _mergeStreamAndLatest(AsyncSnapshot<Match?> snap) {
    final fromStream = snap.data;
    final local = _latestMatch;
    if (fromStream == null) return local;
    if (local == null) return fromStream;
    if (fromStream.id != local.id) return fromStream;
    final c = local.updatedAt.compareTo(fromStream.updatedAt);
    if (c > 0) return local;
    return fromStream;
  }

  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    try {
      final data =
          await _sb.from('profiles').select().eq('id', userId).maybeSingle() ??
          const <String, dynamic>{};
      final profile = <String, dynamic>{
        'displayName':
            (data['display_name'] ?? data['first_name'] ?? tr('player'))
                .toString(),
        'avatarUrl': ((data['avatar_url'] ?? data['photo_url']) ?? '')
            .toString(),
        'rating': _profileOverallRatingFromRow(data),
        'wins': (data['wins'] ?? 0),
        'draws': (data['draws'] ?? 0),
        'losses': (data['losses'] ?? 0),
      };
      _userCache[userId] = profile;
      return profile;
    } catch (_) {
      final fallback = <String, dynamic>{
        'displayName': tr('player'),
        'avatarUrl': '',
        'rating': 0.0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
      };
      _userCache[userId] = fallback;
      return fallback;
    }
  }

  Future<_ClubInfo> _getClubInfo(
    String? teamId,
    MatchTeamEntity? fallback, {
    required String fallbackLabel,
  }) async {
    final effectiveLabel = (fallback != null && fallback.name.isNotEmpty)
        ? fallback.name
        : fallbackLabel;

    if (teamId == null || teamId.isEmpty) {
      return _ClubInfo.fromTeam(fallback, fallbackLabel: effectiveLabel);
    }

    final cached = _clubCache[teamId];
    if (cached != null) return cached;

    try {
      final data = await _sb
          .from('teams')
          .select()
          .eq('id', teamId)
          .maybeSingle();
      final info = _ClubInfo(
        name: (data?['name'] ?? effectiveLabel).toString(),
        logoUrl: (data?['logo_url'] ?? '').toString(),
        rating:
            (data?['rating'] ??
                    data?['team_rating'] ??
                    fallback?.averageRating ??
                    0)
                .toDouble(),
      );
      _clubCache[teamId] = info;
      return info;
    } catch (_) {
      final info = _ClubInfo.fromTeam(fallback, fallbackLabel: effectiveLabel);
      _clubCache[teamId] = info;
      return info;
    }
  }

  @override
  void initState() {
    super.initState();
    _isOwner = AppAuth.currentUserId == widget.match.organizerId;
    final tabCount = _isOwner ? 4 : 3;
    final safeInitialIndex = widget.initialTabIndex
        .clamp(0, tabCount - 1)
        .toInt();
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: safeInitialIndex,
    );
    _loadMatchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _winsControllers.values) {
      c.dispose();
    }
    for (final c in _goalsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);

    try {
      final updatedMatch = await _matchRepo.fetchMatchById(widget.match.id);
      if (updatedMatch != null) {
        setState(() {
          _latestMatch = updatedMatch;
          _pendingApplications = updatedMatch.pendingApplications;
          _participants = updatedMatch.participants;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_c487fc4cab', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('il_7e8eb93ff8'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_pendingApplications.isNotEmpty) ...[
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tr('il_359c2e5470', args: ['${_pendingApplications.length}']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _isOwner
            ? [
                IconButton(
                  tooltip: tr('il_146ee72e30'),
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MatchInviteSearchScreen(
                          matchId: widget.match.id,
                          matchTitle: widget.match.title,
                          organizerName: widget.match.organizerName,
                          excludedUserIds: <String>[
                            widget.match.organizerId,
                            ...widget.match.participants,
                            ...widget.match.pendingApplications,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ]
            : null,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: StreamBuilder<Match?>(
            stream: _liveMatchStream(),
            builder: (context, snap) {
              final has = snap.hasData && snap.data != null;
              final m = has ? snap.data! : widget.match;
              final pendingCount = has
                  ? m.pendingApplications.length
                  : _pendingApplications.length;

              final tabs = <Widget>[
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('il_98e33b0f31')),
                        const SizedBox(width: 6),
                        if (pendingCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tr('il_1e1a1c078a')),
                  ),
                ),
                Tab(text: tr('settings')),
              ];
              if (_isOwner) {
                tabs.add(Tab(text: tr('invitations')));
              }

              return TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: tabs,
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationsTab(),
          _buildTeamsTab(),
          _buildSettingsTab(),
          if (_isOwner) _buildInvitationsTab(),
        ],
      ),
    );
  }

  Stream<List<_InviteHistoryItem>> _invitationHistoryStream() {
    return _sb
        .from('match_invites')
        .stream(primaryKey: ['id'])
        .eq('match_id', widget.match.id)
        .asyncMap((rows) async {
          final inviteRows = (rows as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(growable: false);
          final userIds = inviteRows
              .map((r) => (r['user_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList(growable: false);

          final profileById = <String, Map<String, dynamic>>{};
          if (userIds.isNotEmpty) {
            try {
              final profiles = await _sb
                  .from('profiles')
                  .select('id,display_name,email')
                  .inFilter('id', userIds);
              for (final p in profiles as List<dynamic>) {
                final row = Map<String, dynamic>.from(p as Map);
                final id = (row['id'] ?? '').toString();
                if (id.isNotEmpty) profileById[id] = row;
              }
            } catch (_) {}
          }

          final items =
              inviteRows
                  .map((r) {
                    final userId = (r['user_id'] ?? '').toString();
                    final p = profileById[userId];
                    final label =
                        (p?['display_name'] ??
                                p?['email']?.toString().split('@').first ??
                                userId)
                            .toString();
                    final email = (p?['email'] ?? '').toString();
                    return _InviteHistoryItem(
                      userId: userId,
                      label: label,
                      email: email,
                      status: (r['status'] ?? 'pending').toString(),
                      createdAt:
                          asDateTimeOrNull(r['created_at']) ?? DateTime.now(),
                    );
                  })
                  .toList(growable: false)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Widget _buildInvitationsTab() {
    if (!_isOwner) {
      return Center(
        child: Text(
          tr('match_mgmt_not_available'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return StreamBuilder<List<_InviteHistoryItem>>(
      stream: _invitationHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(
                    'il_e69e7edfdf',
                    namedArgs: {'e': snapshot.error.toString()},
                  ),
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() {}),
                  child: Text(tr('retry')),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const <_InviteHistoryItem>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              tr('match_invitations_tab_empty'),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white12,
                    child: Text(
                      item.label.isNotEmpty ? item.label[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.email.isNotEmpty)
                          Text(
                            item.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _formatInvitationTime(item.createdAt),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildInviteStatusChip(item.status),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatInvitationTime(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mm ${dt.year} $hh:$min';
  }

  Widget _buildInviteStatusChip(String status) {
    final normalized = status.trim().toLowerCase();
    Color bg = Colors.white24;
    String label = normalized;
    if (normalized == 'pending') {
      bg = Colors.orange;
      label = tr('match_invite_status_pending');
    } else if (normalized == 'accepted') {
      bg = const Color(0xFF4caf50);
      label = tr('match_invite_status_accepted');
    } else if (normalized == 'declined') {
      bg = Colors.redAccent;
      label = tr('match_invite_status_declined');
    } else if (normalized == 'cancelled') {
      bg = Colors.grey;
      label = tr('match_invite_status_cancelled');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildApplicationsTab() {
    return StreamBuilder<Match?>(
      stream: _liveMatchStream(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          );
        }
        final updated = snap.data!;
        final pending = updated.pendingApplications;
        if (pending.isEmpty) {
          return Center(
            child: Text(
              tr('il_62a5da4bf1'),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: pending.length,
          itemBuilder: (context, index) =>
              _buildApplicationCard(pending[index]),
        );
      },
    );
  }

  // -------- TEAMS TAB --------

  Widget _buildTeamsTab() {
    return Stack(
      children: [
        StreamBuilder<Match?>(
          stream: _liveMatchStream(),
          builder: (context, snap) {
            final match = _mergeStreamAndLatest(snap);
            if (match == null) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4caf50)),
              );
            }
            final isOrganizer = AppAuth.currentUserId == match.organizerId;
            return _buildTeamsContent(match, isOrganizer);
          },
        ),
        if (_shufflingTeams)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamsContent(Match m, bool isOrganizer) {
    if (_showResultForm && !m.isInProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showResultForm = false);
      });
    }

    if (_winsControllers.length != m.allTeams.length) {
      _winsControllers.clear();
      _goalsControllers.clear();
      for (var i = 0; i < m.allTeams.length; i++) {
        _winsControllers[i] = TextEditingController();
        _goalsControllers[i] = TextEditingController();
      }
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 32,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTeamsHeader(m, isOrganizer),
              if (m.isTeamMatch) ...[
                const SizedBox(height: 12),
                _buildTeamConfirmationCard(m, isOrganizer),
              ],
              if (!m.isTeamMatch && m.participants.length >= 2) ...[
                const SizedBox(height: 12),
                _buildTeamCountSelector(m),
              ],
              const SizedBox(height: 20),
              if (!m.hasTeams && m.participants.length >= 2)
                _buildAutoFormButton(),
              if (m.hasTeams && !_editMode) ...[_buildBalanceAndManagement(m)],
              if (_editMode) _buildEditingSection(m),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamsHeader(Match m, bool isOrganizer) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                tr('il_1e1a1c078a'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tr('il_ef2cc663e8', args: ['${m.participants.length}']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (m.hasTeams && isOrganizer)
          TextButton.icon(
            onPressed: () {
              if (_editMode) {
                setState(() => _editMode = false);
              } else {
                _enterEditMode(m);
              }
            },
            icon: Icon(
              _editMode ? Icons.close : Icons.edit,
              color: Colors.white70,
            ),
            label: Text(
              _editMode ? tr('il_b82f21129b') : tr('il_a575c5b4e4'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamCountSelector(Match m) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: List.generate(3, (index) {
        final value = index + 2;
        final enabled = m.participants.length >= value;
        return ChoiceChip(
          label: Text(tr('il_7b7e87fdbe', namedArgs: {'value': '$value'})),
          selected: _teamCount == value,
          onSelected: enabled
              ? (selected) => setState(() => _teamCount = value)
              : null,
        );
      }),
    );
  }

  Widget _buildAutoFormButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _autoBalanceTeams,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4caf50),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shuffle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              tr('il_27efc72f99'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceAndManagement(Match m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scale, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                tr('il_90c7d60d8b'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!m.isTeamMatch)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await _confirm(
                      tr('il_419d3a583c'),
                      tr('il_737fec7a47'),
                    );
                    if (ok == true) await _shuffleTeams(m);
                  },
                  icon: const Icon(Icons.shuffle, color: Colors.white),
                  label: Text(
                    tr('il_317cb3a7ef'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          m.isTeamMatch ? _buildClubVsCard(m) : _buildTeamsWrap(m),
          const SizedBox(height: 20),
          Text(
            tr('il_7e8eb93ff8'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildManagementButtons(m),
          if (_showResultForm && (m.teamCount ?? 2) > 2) _buildResultsTable(m),
        ],
      ),
    );
  }

  Widget _buildTeamsWrap(Match m) {
    final visibleTeams = m.allTeams
        .where((team) => team.playerIds.isNotEmpty)
        .toList();

    final cards = List.generate(visibleTeams.length, (index) {
      final team = visibleTeams[index];
      final players = team.playerIds;
      final total = _teamTotalRating(
        players,
        _ratingsCache,
        team.averageRating,
      );
      return _mvpTeamCard(
        title: team.name.isNotEmpty
            ? team.name
            : '${tr('il_5985039f10')} ${index + 1}',
        color: _teamColors[index % _teamColors.length],
        total: total,
        players: players,
        ratings: _ratingsCache,
      );
    });

    if (cards.length == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cards[0], const SizedBox(height: 16), cards[1]],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(cards.length, (index) {
        return SizedBox(
          width:
              MediaQuery.of(context).size.width /
                  (visibleTeams.length >= 2 ? 2 : 1) -
              24,
          child: cards[index],
        );
      }),
    );
  }

  Widget _buildClubVsCard(Match m) {
    return FutureBuilder<_ClubCardData>(
      future: _prepareClubCardData(m),
      builder: (context, snapshot) {
        final infos =
            snapshot.data?.infos ??
            [
              _ClubInfo.fromTeam(m.teamA, fallbackLabel: tr('il_e18d322f14')),
              _ClubInfo.fromTeam(m.teamB, fallbackLabel: tr('il_aceaf5d9ac')),
            ];
        final ratings = snapshot.data?.ratings ?? _ratingsCache;

        Widget buildSide(
          _ClubInfo info,
          List<String> roster,
          double total,
          String? teamId,
        ) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TeamLogoButton(
                  teamId: teamId,
                  teamName: info.name,
                  logoUrl: info.logoUrl,
                  size: 60,
                ),
                const SizedBox(height: 8),
                Text(
                  info.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${tr('il_9f29530464')}: ${total.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${roster.length} ${tr('players').toLowerCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          );
        }

        final rosterA =
            m.teamRosters['teamA'] ?? m.teamA?.playerIds ?? const <String>[];
        final rosterB =
            m.teamRosters['teamB'] ?? m.teamB?.playerIds ?? const <String>[];
        final totalA = _teamTotalRating(rosterA, ratings, infos[0].rating ?? 0);
        final totalB = _teamTotalRating(rosterB, ratings, infos[1].rating ?? 0);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              buildSide(infos[0], rosterA, totalA, m.teamAId),
              Column(
                children: [
                  Text(
                    tr('il_f130559f0e'),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rosterA.length}-${rosterB.length}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              buildSide(infos[1], rosterB, totalB, m.teamBId),
            ],
          ),
        );
      },
    );
  }

  double _calculateWinRateFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return 0.0;
    final wins = (profile['wins'] ?? 0) as num;
    final draws = (profile['draws'] ?? 0) as num;
    final losses = (profile['losses'] ?? 0) as num;
    final total = wins + draws + losses;
    if (total <= 0) return 0.0;
    return (wins / total) * 100;
  }

  Future<_ClubCardData> _prepareClubCardData(Match m) async {
    final infos = await Future.wait([
      _getClubInfo(m.teamAId, m.teamA, fallbackLabel: tr('il_e18d322f14')),
      _getClubInfo(m.teamBId, m.teamB, fallbackLabel: tr('il_aceaf5d9ac')),
    ]);

    final rosterA =
        m.teamRosters['teamA'] ?? m.teamA?.playerIds ?? const <String>[];
    final rosterB =
        m.teamRosters['teamB'] ?? m.teamB?.playerIds ?? const <String>[];
    final neededIds = {...rosterA, ...rosterB}..removeWhere((id) => id.isEmpty);

    final missing = neededIds
        .where((id) => !_ratingsCache.containsKey(id))
        .toList();
    Map<String, double> mergedRatings = Map<String, double>.from(_ratingsCache);
    if (missing.isNotEmpty) {
      final fetched = await _fetchRatings(missing);
      mergedRatings.addAll(fetched);
      _ratingsCache = mergedRatings;
    }

    return _ClubCardData(infos: infos, ratings: mergedRatings);
  }

  Widget _buildManagementButtons(Match m) {
    final totalTeams = m.teamCount ?? m.allTeams.length;
    final awaitingTeamConfirmations =
        m.isTeamMatch && !m.hasConfirmedPlayersForBothTeams;
    final isOrganizer = AppAuth.currentUserId == m.organizerId;

    VoidCallback? primaryAction;
    IconData primaryIcon = Icons.play_arrow;
    String primaryLabel = tr('action_start_match_ui');
    Color primaryColor = const Color(0xFF4caf50);

    if (m.isInProgress) {
      primaryIcon = Icons.flag;
      primaryLabel = tr('finish_match');
      primaryColor = const Color(0xFFFFA000);
      primaryAction = totalTeams > 2
          ? () {
              setState(() {
                _showResultForm = true;
              });
            }
          : _showFinishMatchDialog;
    } else if (m.isFinished) {
      primaryIcon = Icons.check_circle;
      primaryLabel = tr('status_finished');
      primaryColor = Colors.grey;
      primaryAction = null;
    } else if (m.isCancelled) {
      primaryIcon = Icons.cancel;
      primaryLabel = tr('status_cancelled');
      primaryColor = Colors.grey;
      primaryAction = null;
    } else {
      if (awaitingTeamConfirmations) {
        primaryIcon = Icons.hourglass_empty;
        primaryLabel = tr('il_0e24d1fae8');
        primaryColor = Colors.grey;
        primaryAction = null;
      } else {
        primaryAction = _startMatch;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: primaryAction,
                icon: Icon(primaryIcon, color: Colors.white),
                label: Text(
                  primaryLabel,
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!m.isFinished && !m.isCancelled)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await _confirm(
                      tr('il_8c82a6c729'),
                      tr('il_ff7e15efc2'),
                    );
                    if (ok == true) await _cancelMatch();
                  },
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: Text(
                    tr('cancel'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
        if (!m.isFinished &&
            !m.isCancelled &&
            !m.isInProgress &&
            awaitingTeamConfirmations) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('il_1cfd8a014c'),
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
        if (isOrganizer &&
            !m.isInProgress &&
            !m.isFinished &&
            !m.isCancelled) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _deleteMatch,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: Text(
              tr('il_4a54daa086'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultsTable(Match m) {
    final teams = m.allTeams;
    if (teams.isEmpty) return const SizedBox.shrink();

    if (_winsControllers.length != teams.length) {
      _winsControllers.clear();
      _goalsControllers.clear();
      for (var i = 0; i < teams.length; i++) {
        _winsControllers[i] = TextEditingController();
        _goalsControllers[i] = TextEditingController();
      }
    }

    final existingStats = <int, Map<String, dynamic>>{};
    for (final stat in m.multiTeamStats) {
      final idx = stat['teamIndex'];
      if (idx is int) {
        existingStats[idx] = stat;
      }
    }

    for (var i = 0; i < teams.length; i++) {
      final saved = existingStats[i];
      if (saved == null) continue;
      final winsVal = saved['wins'];
      final goalsVal = saved['goals'];
      final winsCtrl = _winsControllers[i]!;
      final goalsCtrl = _goalsControllers[i]!;
      if (winsVal != null && winsCtrl.text.isEmpty) {
        winsCtrl.text = winsVal.toString();
      }
      if (goalsVal != null && goalsCtrl.text.isEmpty) {
        goalsCtrl.text = goalsVal.toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          tr('il_27f18ca3c7'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...teams.asMap().entries.map((entry) {
          final index = entry.key;
          final team = entry.value;
          final winsCtrl = _winsControllers[index]!;
          final goalsCtrl = _goalsControllers[index]!;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name.isEmpty
                      ? tr('il_d040fd4027', args: ['${index + 1}'])
                      : team.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _resultField(tr('il_41da8b729f'), winsCtrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _resultField(tr('il_116cd3982a'), goalsCtrl),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _savingResults ? null : () => _saveResults(m),
          child: _savingResults
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('il_5fc0a3943a')),
        ),
      ],
    );
  }

  Future<void> _saveResults(Match m) async {
    FocusScope.of(context).unfocus();

    final stats = <Map<String, int>>[];
    bool hasAnyInput = false;
    for (var i = 0; i < m.allTeams.length; i++) {
      final winsText = _winsControllers[i]?.text.trim() ?? '';
      final goalsText = _goalsControllers[i]?.text.trim() ?? '';
      final wins = int.tryParse(winsText) ?? 0;
      final goals = int.tryParse(goalsText) ?? 0;
      if (winsText.isNotEmpty || goalsText.isNotEmpty) {
        hasAnyInput = true;
      }
      stats.add({'teamIndex': i, 'wins': wins, 'goals': goals});
    }

    if (!hasAnyInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_12f1cbf3bb')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _savingResults = true);
    try {
      final saved = await _matchRepo.saveMultiTeamResults(m.id, stats);
      if (!saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('il_9eab08ac7d'))));
        return;
      }

      final finished = await _managementActions.finishMatch(
        matchId: m.id,
        result: MatchResult.draw,
        teamAScore: m.teamAScore ?? 0,
        teamBScore: m.teamBScore ?? 0,
      );

      if (!finished) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('il_7813427f3c'))));
        return;
      }

      setState(() => _showResultForm = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_813c992c4c'))));
      await context.router.push(
        MatchRatingRoute(
          match: m.copyWith(
            status: MatchStatus.finished,
            result: MatchResult.draw,
            teamAScore: m.teamAScore ?? 0,
            teamBScore: m.teamBScore ?? 0,
            multiTeamStats: stats,
            teams: m.allTeams,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingResults = false);
      }
    }
  }

  Widget _resultField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildTeamConfirmationCard(Match m, bool isOrganizer) {
    final teamAName = m.teamA?.name ?? tr('il_e18d322f14');
    final teamBName = m.teamB?.name ?? tr('il_aceaf5d9ac');
    final rosterA =
        m.teamRosters['teamA'] ?? m.teamA?.playerIds ?? const <String>[];
    final rosterB =
        m.teamRosters['teamB'] ?? m.teamB?.playerIds ?? const <String>[];
    final rosterStatusesA =
        m.teamRosterStatus['teamA'] ?? const <String, String>{};
    final rosterStatusesB =
        m.teamRosterStatus['teamB'] ?? const <String, String>{};
    final statusA = m.teamAStatus ?? 'pending';
    final statusB = m.teamBStatus ?? 'pending';
    final bothConfirmed = statusA == 'confirmed' && statusB == 'confirmed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                tr('il_cb31ba59b7'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bothConfirmed
                      ? const Color(0xFF4caf50)
                      : const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  bothConfirmed ? tr('il_5fa7aac537') : tr('il_331551b0de'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _teamStatusTile(
            teamId: m.teamAId,
            name: teamAName,
            status: statusA,
            roster: rosterA,
            rosterStatuses: rosterStatusesA,
            accent: const Color(0xFF4caf50),
          ),
          const SizedBox(height: 12),
          _teamStatusTile(
            teamId: m.teamBId,
            name: teamBName,
            status: statusB,
            roster: rosterB,
            rosterStatuses: rosterStatusesB,
            accent: const Color(0xFF42a5f5),
          ),
          if (m.teamsReadyNotified && isOrganizer) ...[
            const SizedBox(height: 12),
            _infoPill(
              icon: Icons.check_circle,
              text: tr('il_6ed73f6fcc'),
              color: const Color(0xFF81C784),
            ),
          ] else if (!bothConfirmed && isOrganizer) ...[
            const SizedBox(height: 12),
            _infoPill(
              icon: Icons.info_outline,
              text: tr('il_c7df816a19'),
              color: const Color(0xFFFFC107),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamStatusTile({
    required String? teamId,
    required String name,
    required String status,
    required List<String> roster,
    required Map<String, String> rosterStatuses,
    required Color accent,
  }) {
    final totalTracked = rosterStatuses.isNotEmpty
        ? rosterStatuses.length
        : roster.length;
    final confirmed = rosterStatuses.values
        .where((v) => v == 'confirmed')
        .length;
    final declined = rosterStatuses.values.where((v) => v == 'declined').length;
    final pending = totalTracked - confirmed - declined;
    final hasResponses = rosterStatuses.isNotEmpty;
    final statusColor = _teamStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TeamLogoButton(teamId: teamId, teamName: name, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _teamStatusText(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasResponses && totalTracked > 0) ...[
            LinearProgressIndicator(
              value: totalTracked == 0 ? 0 : confirmed / totalTracked,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'il_4df14714b9',
                namedArgs: {
                  'confirmed': '$confirmed',
                  'totalTracked': '$totalTracked',
                },
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _statusCounter(
                  icon: Icons.check_circle,
                  color: const Color(0xFF4caf50),
                  value: confirmed,
                ),
                const SizedBox(width: 8),
                _statusCounter(
                  icon: Icons.timelapse,
                  color: const Color(0xFFFFC107),
                  value: max(pending, 0),
                ),
                const SizedBox(width: 8),
                _statusCounter(
                  icon: Icons.cancel,
                  color: const Color(0xFFE53935),
                  value: max(declined, 0),
                ),
              ],
            ),
          ] else ...[
            Text(
              tr('il_55372144a2'),
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            if (roster.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tr('il_ec7d9c2b9b', args: ['${roster.length}']),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusCounter({
    required IconData icon,
    required Color color,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _teamStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return tr('il_fe00b67b6d');
      case 'declined':
        return tr('il_dce083a2c4');
      default:
        return tr('il_331551b0de');
    }
  }

  Color _teamStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF4caf50);
      case 'declined':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFFFFC107);
    }
  }

  Widget _buildEditingSection(Match m) {
    return FutureBuilder<Map<String, double>>(
      future: _ratingsCache.isEmpty
          ? _fetchRatings(_editingTeams.expand((team) => team).toList()).then((
              loaded,
            ) {
              _ratingsCache = loaded;
              return loaded;
            })
          : Future.value(_ratingsCache),
      builder: (context, rSnap) {
        final ratings = rSnap.data ?? _ratingsCache;
        final editingSets = _editingTeams.isNotEmpty
            ? _editingTeams
            : [_editingTeamA, _editingTeamB];
        final sourceTeams = m.allTeams;

        String teamNameForIndex(int index) {
          if (index < sourceTeams.length &&
              sourceTeams[index].name.isNotEmpty) {
            return sourceTeams[index].name;
          }
          if (index == 0 && (m.teamA?.name ?? '').isNotEmpty) {
            return m.teamA!.name;
          }
          if (index == 1 && (m.teamB?.name ?? '').isNotEmpty) {
            return m.teamB!.name;
          }
          return tr('il_d040fd4027', args: ['${index + 1}']);
        }

        String? teamIdForIndex(int index) {
          if (index == 0) return m.teamAId;
          if (index == 1) return m.teamBId;
          return null;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.balance, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  tr('il_f5b0ef7b5d', args: ['${editingSets.length}']),
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      final first = editingSets.first;
                      editingSets.removeAt(0);
                      editingSets.add(first);
                    });
                  },
                  icon: const Icon(Icons.loop, color: Colors.white70),
                  label: Text(
                    tr('il_c3613b1704'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            (() {
              final cards = List.generate(editingSets.length, (index) {
                final teamPlayers = editingSets[index];
                return _dragZone(
                  teamName: teamNameForIndex(index),
                  teamId: teamIdForIndex(index),
                  accent: _teamColors[index % _teamColors.length],
                  players: teamPlayers,
                  onRemove: (id) {
                    if (_locked.contains(id)) return;
                    setState(() => teamPlayers.remove(id));
                  },
                  onAcceptFromOther: (id) {
                    if (_locked.contains(id)) return;
                    setState(() {
                      for (final list in editingSets) {
                        if (list != teamPlayers) list.remove(id);
                      }
                      teamPlayers.add(id);
                    });
                  },
                  locked: _locked,
                  onToggleLock: (id) => setState(() {
                    _locked.contains(id) ? _locked.remove(id) : _locked.add(id);
                  }),
                  ratings: ratings,
                );
              });
              if (cards.length == 2) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cards[0], const SizedBox(height: 16), cards[1]],
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(cards.length, (index) {
                  return SizedBox(
                    width:
                        MediaQuery.of(context).size.width /
                            (cards.length >= 2 ? 2 : 1) -
                        24,
                    child: cards[index],
                  );
                }),
              );
            })(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingTeams
                    ? null
                    : () async {
                        final ok = await _confirm(
                          tr('il_30ce115ca4'),
                          tr('il_a153c9cb4e'),
                        );
                        if (ok != true) return;
                        setState(() => _isSavingTeams = true);
                        final success = await _matchRepo.updateTeamsFlexible(
                          widget.match.id,
                          editingSets,
                        );
                        setState(() => _isSavingTeams = false);
                        if (success) {
                          setState(() => _editMode = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('il_5f65bdc4b5')),
                              backgroundColor: const Color(0xFF4caf50),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('il_1f88a41954')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                icon: _isSavingTeams
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isSavingTeams ? tr('il_23e39291d6') : tr('il_abe29cc364'),
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4caf50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _enterEditMode(Match m, {bool manual = false}) {
    _editMode = true;
    _locked.clear();
    _ratingsCache.clear();

    final sourceTeams = m.allTeams;
    if (!manual && sourceTeams.isNotEmpty) {
      _editingTeams = sourceTeams
          .map((team) => List<String>.from(team.playerIds))
          .toList();
      _editingTeamA = _editingTeams.isNotEmpty ? _editingTeams.first : [];
      _editingTeamB = _editingTeams.length > 1 ? _editingTeams[1] : [];
    } else {
      _editingTeamA = [];
      _editingTeamB = [];
      _editingTeams = [[], []];
    }
    setState(() {});
  }

  List<List<String>> _autoDistributePlayers(
    List<String> playerIds,
    Map<String, double> ratings,
    int teamCount,
  ) {
    final rnd = Random();
    final cleaned = playerIds.where((id) => id.isNotEmpty).toList();
    if (teamCount < 2 || cleaned.length < teamCount) {
      return List.generate(teamCount, (_) => <String>[]);
    }

    List<List<String>> best = List.generate(teamCount, (_) => <String>[]);
    double bestGap = double.infinity;

    for (var attempt = 0; attempt < 200; attempt++) {
      final shuffled = [...cleaned]..shuffle(rnd);
      final candidate = List.generate(teamCount, (_) => <String>[]);
      final totals = List<double>.filled(teamCount, 0);

      for (final playerId in shuffled) {
        final rating = ratings[playerId] ?? 0.0;

        var target = 0;
        var minTotal = totals[0];
        for (var i = 1; i < teamCount; i++) {
          final total = totals[i];
          if (total < minTotal ||
              (total == minTotal &&
                  candidate[i].length < candidate[target].length)) {
            target = i;
            minTotal = total;
          }
        }

        candidate[target].add(playerId);
        totals[target] += rating;
      }

      final maxTotal = totals.reduce(max);
      final minTotal = totals.reduce(min);
      final gap = maxTotal - minTotal;

      if (gap < bestGap - 0.01 || (gap <= bestGap + 0.01 && rnd.nextBool())) {
        bestGap = gap;
        best = candidate.map((team) => List<String>.from(team)).toList();
        if (bestGap == 0) break;
      }
    }

    return best;
  }

  Future<void> _shuffleTeams(Match match) async {
    setState(() {
      _isLoading = true;
      _shufflingTeams = true;
    });
    try {
      final ids = match.participants.map((e) => e.toString()).toList();
      if (ids.length < 2) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('il_238030df7e'))));
        return;
      }

      final ratings = await _fetchRatings(ids);
      final balanced = _autoDistributePlayers(ids, ratings, _teamCount);

      final ok = await _matchRepo.updateTeamsFlexible(match.id, balanced);
      if (!ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('il_115806d062'))));
        return;
      }

      await _matchRepo.ensureFixtures(match.id);

      setState(() {
        _ratingsCache = {};
        _editingTeams = [];
        _editingTeamA = [];
        _editingTeamB = [];
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('il_e9cefdd85f'))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_50b9b968e1', namedArgs: {'e': e.toString()})),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _shufflingTeams = false;
        });
      }
    }
  }

  Widget _buildSettingsTab() {
    return StreamBuilder<Match?>(
      stream: _liveMatchStream(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          );
        }
        final m = snap.data!;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('il_7e8eb93ff8'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (m.hasTeams &&
                  !m.isInProgress &&
                  !m.isFinished &&
                  !m.isCancelled)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startMatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4caf50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tr('start_match'),
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
              const SizedBox(height: 16),
              if (m.isInProgress)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : ((m.teamCount ?? 2) > 2
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(tr('il_73a9f0d19a')),
                                    ),
                                  );
                                }
                              : _showFinishMatchDialog),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFf44336),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stop, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          tr('finish_match'),
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('il_9f93d6b4f0', args: [_localizedMatchStatus(m)]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (m.isInProgress && m.startedAt != null)
                      Text(
                        tr('started_at', args: [_formatDateTime(m.startedAt!)]),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    if (m.isFinished && m.finishedAt != null)
                      Text(
                        tr(
                          'il_d154eebf57',
                          args: [_formatDateTime(m.finishedAt!)],
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    if (m.hasTeams)
                      Text(
                        tr('il_105abd8b27'),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Application card
  Widget _buildApplicationCard(String userId) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Application header with user name, avatar, and rating
          FutureBuilder<Map<String, dynamic>?>(
            future: _sb
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle(),
            builder: (context, snap) {
              final Map<String, dynamic> data =
                  (snap.hasData && snap.data != null) ? snap.data! : const {};
              final String displayName =
                  (data['display_name'] ?? data['first_name'] ?? tr('player'))
                      .toString();
              final String avatarUrl =
                  ((data['avatar_url'] ?? data['photo_url']) ?? '').toString();
              final double rating = _profileOverallRatingFromRow(data);

              return InkWell(
                onTap: () {
                  context.router.push(
                    PlayerProfileRoute(
                      playerId: userId,
                      playerName: displayName,
                    ),
                  );
                },
                child: Row(
                  children: [
                    PlayerAvatarButton(
                      userId: userId,
                      displayName: displayName,
                      avatarUrl: avatarUrl,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFD54F),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ID: ${userId.substring(0, 6)}…',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busyUserIds.contains(userId)
                      ? null
                      : () async {
                          final sure = await _confirm(
                            tr('il_d7c7d3254c'),
                            tr('il_bad1b5af9a'),
                          );
                          if (sure != true) return;
                          setState(() => _busyUserIds.add(userId));
                          await _acceptApplication(userId);
                          setState(() => _busyUserIds.remove(userId));
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4caf50),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _busyUserIds.contains(userId)
                        ? tr('il_a168fd64e9')
                        : tr('accept'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busyUserIds.contains(userId)
                      ? null
                      : () async {
                          final sure = await _confirm(
                            tr('match_reject_application_title'),
                            tr('match_reject_application_body'),
                          );
                          if (sure != true) return;
                          setState(() => _busyUserIds.add(userId));
                          await _rejectApplication(userId);
                          setState(() => _busyUserIds.remove(userId));
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _busyUserIds.contains(userId)
                        ? tr('il_09868524d9')
                        : tr('reject'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, double>> _fetchRatings(List<String> ids) async {
    final Map<String, double> result = {};
    const int chunkSize = 100;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        i + chunkSize > ids.length ? ids.length : i + chunkSize,
      );
      final rows = await _sb
          .from('profiles')
          .select('id,overall_rating')
          .inFilter('id', chunk);
      for (final doc in rows as List<dynamic>) {
        final data = Map<String, dynamic>.from(doc as Map);
        final r = _profileOverallRatingFromRow(data);
        result[data['id'].toString()] = r;
      }
      for (final id in chunk) {
        result.putIfAbsent(id, () => 0.0);
      }
    }
    return result;
  }

  double _teamTotalRating(
    List<String> players,
    Map<String, double> ratings,
    double remoteAvg,
  ) {
    if (players.isEmpty) return 0.0;
    if (ratings.isEmpty) {
      return remoteAvg * players.length;
    }
    double sum = 0.0;
    var hasData = false;
    for (final id in players) {
      final value = ratings[id];
      if (value != null) {
        sum += value;
        hasData = true;
      }
    }
    return hasData ? sum : remoteAvg * players.length;
  }

  // Accept application
  Future<void> _acceptApplication(String userId) async {
    try {
      final success = await _managementActions.acceptApplication(
        matchId: widget.match.id,
        userId: userId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_692368eca1')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );
        _loadMatchData(); // Reload data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_5d31b2f729')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Reject application
  Future<void> _rejectApplication(String userId) async {
    try {
      final success = await _managementActions.rejectApplication(
        matchId: widget.match.id,
        userId: userId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_3bbca810b0')),
            backgroundColor: Colors.orange,
          ),
        );
        _loadMatchData(); // Reload data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_a6453cea62')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _mvpTeamCard({
    required String title,
    required Color color,
    required double total,
    required List<String> players,
    required Map<String, double> ratings,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
        color: Colors.white.withOpacity(0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFFFD54F), size: 20),
              const SizedBox(width: 6),
              Text(
                total.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('il_0d5e3f5337'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...players.map((id) {
            final r = ratings[id] ?? 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _getUserProfile(id),
                builder: (context, snap) {
                  final name =
                      (snap.data?['displayName'] ?? tr('player')) as String;
                  final avatarUrl =
                      ((snap.data?['avatarUrl'] ?? snap.data?['photoUrl']) ??
                              '')
                          as String;
                  final realRating = ((snap.data?['rating'] ?? r) as num)
                      .toDouble();
                  final winRate = _calculateWinRateFromProfile(snap.data);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlayerAvatarButton(
                        userId: id,
                        displayName: name,
                        avatarUrl: avatarUrl,
                        size: 32,
                        borderColor: Colors.white.withOpacity(0.15),
                        borderWidth: 1,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${realRating.toStringAsFixed(2)} ${tr('il_112895d7af')}'
                              ' • ${winRate.toStringAsFixed(0)}% ${tr('il_dd54e8f076')}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _dragZone({
    required String teamName,
    required String? teamId,
    required Color accent,
    required List<String> players,
    required void Function(String id) onRemove,
    required void Function(String id) onAcceptFromOther,
    required Set<String> locked,
    required void Function(String id) onToggleLock,
    required Map<String, double> ratings,
  }) {
    final total = _teamTotalRating(players, ratings, 0);
    return DragTarget<String>(
      onWillAccept: (id) => id != null && !(locked.contains(id)),
      onAccept: onAcceptFromOther,
      builder: (context, candidate, rejected) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (candidate.isNotEmpty ? accent : accent.withOpacity(0.6)),
              width: 2,
            ),
            color: Colors.white.withOpacity(0.02),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TeamLogoButton(teamId: teamId, teamName: teamName, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${players.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.bolt, color: Color(0xFFFFD54F), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    total.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...players.map((id) {
                final r = ratings[id] ?? 0.0;
                final isLocked = locked.contains(id);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _getUserProfile(id),
                    builder: (context, snap) {
                      final name =
                          (snap.data?['displayName'] ?? tr('player')) as String;
                      final avatarUrl =
                          ((snap.data?['avatarUrl'] ??
                                      snap.data?['photoUrl']) ??
                                  '')
                              as String;
                      final realRating = ((snap.data?['rating'] ?? r) as num)
                          .toDouble();
                      final winRate = _calculateWinRateFromProfile(snap.data);
                      final row = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PlayerAvatarButton(
                            userId: id,
                            displayName: name,
                            avatarUrl: avatarUrl,
                            size: 32,
                            borderColor: Colors.white.withOpacity(0.15),
                            borderWidth: 1,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${realRating.toStringAsFixed(2)} ${tr('il_112895d7af')}'
                                  ' • ${winRate.toStringAsFixed(0)}% ${tr('il_dd54e8f076')}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => onToggleLock(id),
                            child: Icon(
                              isLocked ? Icons.lock : Icons.lock_open,
                              size: 16,
                              color: isLocked ? Colors.white38 : Colors.white60,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => onRemove(id),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: isLocked ? Colors.white24 : Colors.white60,
                            ),
                          ),
                        ],
                      );
                      return Draggable<String>(
                        data: id,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101018),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '$name (${realRating.toStringAsFixed(2)})',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.45, child: row),
                        child: row,
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _autoBalanceTeams() async {
    setState(() => _isLoading = true);

    try {
      final success = await _matchRepo.autoBalanceTeams(widget.match.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_ebc084d8e2')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );

        // Reload data
        await _loadMatchData();
        // Reset local temporary lineups
        setState(() {
          _editingTeams = [];
          _editingTeamA = [];
          _editingTeamB = [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('team_formation_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startMatch() async {
    setState(() => _isLoading = true);

    try {
      final success = await _managementActions.startMatch(widget.match.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('match_started')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );

        // Reload data
        await _loadMatchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('match_start_error_teams')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showFinishMatchDialog() {
    if (_isLoading) return;
    final activeMatch = _latestMatch ?? widget.match;
    Navigator.of(context)
        .push<FinishMatchResult?>(
          MaterialPageRoute<FinishMatchResult?>(
            fullscreenDialog: true,
            builder: (_) => FinishMatchFlowPage(
              match: activeMatch,
              participantIds: _participants,
              teamColors: _teamColors,
              loadPlayerRows: _loadFinishMatchPlayerRows,
            ),
          ),
        )
        .then((result) {
          if (!mounted || result == null) return;
          _applyFinishMatch(result);
        });
  }

  Future<void> _applyFinishMatch(FinishMatchResult data) async {
    setState(() => _isLoading = true);

    try {
      MatchResult result;
      if (data.teamAScore > data.teamBScore) {
        result = MatchResult.teamAWins;
      } else if (data.teamBScore > data.teamAScore) {
        result = MatchResult.teamBWins;
      } else {
        result = MatchResult.draw;
      }

      final success = await _managementActions.finishMatch(
        matchId: widget.match.id,
        result: result,
        teamAScore: data.teamAScore,
        teamBScore: data.teamBScore,
        goalsByPlayer: data.goalsByPlayer,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_a7c0f718a2')),
            backgroundColor: Color(0xFF4caf50),
          ),
        );

        await _loadMatchData();
        if (!mounted) return;
        await context.router.push(
          MatchRatingRoute(match: _latestMatch ?? widget.match),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_9a01f718c1')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, MatchFinishPlayerRow>> _loadFinishMatchPlayerRows(
    List<String> ids,
  ) => loadFinishMatchPlayerRows(_sb, ids);

  Future<void> _cancelMatch() async {
    setState(() => _isLoading = true);
    try {
      final success = await _matchRepo.cancelMatch(widget.match.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('status_cancelled')),
            backgroundColor: Colors.redAccent,
          ),
        );
        await _loadMatchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_aedba96e5a')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMatch() async {
    final ok = await _confirm(tr('il_f48238a263'), tr('il_3d6a452672'));
    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      final success = await _matchRepo.deleteMatch(widget.match.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_94f8877ff8')),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_f88551e1f7')),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _localizedMatchStatus(Match m) {
    if (m.isUnplayedByTimeout == true) {
      return tr('il_ee288d682b');
    }
    switch (m.status) {
      case MatchStatus.open:
        return tr('status_open');
      case MatchStatus.full:
        return tr('status_full');
      case MatchStatus.inProgress:
        return tr('status_in_progress');
      case MatchStatus.finished:
        return tr('status_finished');
      case MatchStatus.cancelled:
        return tr('status_cancelled');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _ClubInfo {
  final String name;
  final String? logoUrl;
  final double? rating;

  const _ClubInfo({required this.name, this.logoUrl, this.rating});

  factory _ClubInfo.fromTeam(
    MatchTeamEntity? team, {
    required String fallbackLabel,
  }) {
    return _ClubInfo(
      name: team != null && team.name.isNotEmpty ? team.name : fallbackLabel,
      logoUrl: null,
      rating: team?.averageRating,
    );
  }
}

class _InviteHistoryItem {
  const _InviteHistoryItem({
    required this.userId,
    required this.label,
    required this.email,
    required this.status,
    required this.createdAt,
  });

  final String userId;
  final String label;
  final String email;
  final String status;
  final DateTime createdAt;
}

class _ClubCardData {
  final List<_ClubInfo> infos;
  final Map<String, double> ratings;

  const _ClubCardData({required this.infos, required this.ratings});
}
