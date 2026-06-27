import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../widgets/team_logo_button.dart';
import '../../data/models/match.dart';

/// Display row for a player on the "Who scored?" step.
class MatchFinishPlayerRow {
  const MatchFinishPlayerRow({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;
}

/// Result returned when the user completes the finish-match flow.
class FinishMatchResult {
  const FinishMatchResult({
    required this.teamAScore,
    required this.teamBScore,
    required this.goalsByPlayer,
  });

  final int teamAScore;
  final int teamBScore;
  final Map<String, int> goalsByPlayer;
}

/// Fullscreen flow: final score → per-player goals. Uses a normal [Scaffold] so
/// keyboard inset and scrolling match the rest of the app (no dialog overlay).
class FinishMatchFlowPage extends StatefulWidget {
  const FinishMatchFlowPage({
    super.key,
    required this.match,
    required this.participantIds,
    required this.teamColors,
    required this.loadPlayerRows,
  });

  final Match match;
  final List<String> participantIds;
  final List<Color> teamColors;
  final Future<Map<String, MatchFinishPlayerRow>> Function(List<String> ids)
  loadPlayerRows;

  @override
  State<FinishMatchFlowPage> createState() => _FinishMatchFlowPageState();
}

class _FinishMatchFlowPageState extends State<FinishMatchFlowPage> {
  int _step = 0;
  late final TextEditingController _scoreAController;
  late final TextEditingController _scoreBController;
  Map<String, TextEditingController>? _goalControllers;
  late final Future<_FinishFlowData> _finishFlowFuture;

  int _committedScoreA = 0;
  int _committedScoreB = 0;

  List<String> get _baseParticipantIds => widget.participantIds.isNotEmpty
      ? widget.participantIds
      : widget.match.participants;

  /// Same roster resolution as [MatchManagementScreen] / match details.
  List<String> _rosterTeamAFromMatch(Match m) {
    final r = m.teamRosters['teamA'];
    if (r != null && r.isNotEmpty) return List<String>.from(r);
    return List<String>.from(m.teamA?.playerIds ?? const <String>[]);
  }

  List<String> _rosterTeamBFromMatch(Match m) {
    final r = m.teamRosters['teamB'];
    if (r != null && r.isNotEmpty) return List<String>.from(r);
    return List<String>.from(m.teamB?.playerIds ?? const <String>[]);
  }

  Color _accent(int index) {
    if (index >= 0 && index < widget.teamColors.length) {
      return widget.teamColors[index];
    }
    return const Color(0xFF1976D2);
  }

  @override
  void initState() {
    super.initState();
    _scoreAController = TextEditingController(text: '0');
    _scoreBController = TextEditingController(text: '0');
    _finishFlowFuture = _loadFinishFlowData();
  }

  Future<_FinishFlowData> _loadFinishFlowData() async {
    final sb = Supabase.instance.client;
    final match = widget.match;

    final rawRows = await sb
        .from('team_match_requests')
        .select(
          'requesting_team_id,target_team_id,status,created_at,created_by',
        )
        .eq('match_id', match.id);
    final inviteRows = (rawRows as List<dynamic>)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList(growable: false);

    final teamIds = resolveFinishTeamIds(match, inviteRows);
    final teamsDisplay = await loadFinishTeamsDisplay(sb, match, teamIds);

    final matchRosterA = _rosterTeamAFromMatch(match);
    final matchRosterB = _rosterTeamBFromMatch(match);

    var fetchedA = const <String>[];
    var fetchedB = const <String>[];
    if (matchRosterA.isEmpty &&
        teamIds.teamAId != null &&
        teamIds.teamAId!.trim().isNotEmpty) {
      fetchedA = await fetchFinishMatchTeamMemberUserIds(sb, teamIds.teamAId!);
    }
    if (matchRosterB.isEmpty &&
        teamIds.teamBId != null &&
        teamIds.teamBId!.trim().isNotEmpty) {
      fetchedB = await fetchFinishMatchTeamMemberUserIds(sb, teamIds.teamBId!);
    }

    final merged = mergeFinishMatchRosterLists(
      matchRosterA: matchRosterA,
      matchRosterB: matchRosterB,
      fetchedMembersA: fetchedA,
      fetchedMembersB: fetchedB,
    );
    final rosterA = merged.rosterA;
    final rosterB = merged.rosterB;

    final seen = <String>{};
    void addAll(Iterable<String> xs) {
      for (final x in xs) {
        if (x.isNotEmpty) seen.add(x);
      }
    }

    addAll(_baseParticipantIds);
    addAll(rosterA);
    addAll(rosterB);

    final allPlayerIds = seen.toList();
    final playerRows = await widget.loadPlayerRows(allPlayerIds);

    return _FinishFlowData(
      teamsDisplay: teamsDisplay,
      rosterA: rosterA,
      rosterB: rosterB,
      allPlayerIds: allPlayerIds,
      playerRows: playerRows,
    );
  }

  void _ensureGoalControllers(List<String> ids) {
    if (_goalControllers != null) return;
    _goalControllers = {
      for (final id in ids) id: TextEditingController(text: '0'),
    };
  }

  @override
  void dispose() {
    _scoreAController.dispose();
    _scoreBController.dispose();
    for (final c in _goalControllers?.values ?? const Iterable.empty()) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToScoresStep() {
    setState(() => _step = 0);
  }

  void _submitScoresStep(_FinishFlowData flow) {
    final a = int.tryParse(_scoreAController.text.trim());
    final b = int.tryParse(_scoreBController.text.trim());
    if (a == null || b == null || a < 0 || b < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('error'))));
      return;
    }

    if (a == 0 && b == 0) {
      Navigator.of(context).pop(
        FinishMatchResult(
          teamAScore: a,
          teamBScore: b,
          goalsByPlayer: const {},
        ),
      );
      return;
    }

    if (flow.allPlayerIds.isEmpty) {
      Navigator.of(context).pop(
        FinishMatchResult(
          teamAScore: a,
          teamBScore: b,
          goalsByPlayer: const {},
        ),
      );
      return;
    }

    setState(() {
      _committedScoreA = a;
      _committedScoreB = b;
      _step = 1;
      _ensureGoalControllers(flow.allPlayerIds);
    });
  }

  void _submitGoalsStep(_FinishFlowData flow) {
    final ctrls = _goalControllers;
    if (ctrls == null) return;

    final teamAIds = flow.rosterA;
    final teamBIds = flow.rosterB;

    int sumTeam(Iterable<String> ids) {
      var s = 0;
      for (final id in ids) {
        s += int.tryParse(ctrls[id]?.text ?? '0') ?? 0;
      }
      return s;
    }

    final teamAGoals = sumTeam(teamAIds);
    final teamBGoals = sumTeam(teamBIds);

    // Validate each team independently: the sum of its players' goals must
    // exactly equal the team's recorded score, or the match can't be finished.
    final mismatches = <String>[];
    if (teamAGoals != _committedScoreA) {
      mismatches.add(tr('match_goals_team_mismatch', namedArgs: {
        'team': flow.teamsDisplay.teamA.name,
        'assigned': '$teamAGoals',
        'score': '$_committedScoreA',
      }));
    }
    if (teamBGoals != _committedScoreB) {
      mismatches.add(tr('match_goals_team_mismatch', namedArgs: {
        'team': flow.teamsDisplay.teamB.name,
        'assigned': '$teamBGoals',
        'score': '$_committedScoreB',
      }));
    }
    if (mismatches.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('il_1e20d69e73')}\n${mismatches.join('\n')}'),
          backgroundColor: const Color(0xFFf44336),
        ),
      );
      return;
    }

    final map = <String, int>{};
    ctrls.forEach((id, c) {
      final value = int.tryParse(c.text) ?? 0;
      if (value > 0) map[id] = value;
    });

    Navigator.of(context).pop(
      FinishMatchResult(
        teamAScore: _committedScoreA,
        teamBScore: _committedScoreB,
        goalsByPlayer: map,
      ),
    );
  }

  static const _fieldScrollPadding = EdgeInsets.only(bottom: 120);

  Widget _scoreStep(_FinishTeamInfo teamA, _FinishTeamInfo teamB) {
    Widget teamHeader(_FinishTeamInfo team) {
      return Column(
        children: [
          TeamLogoButton(
            teamId: team.id,
            teamName: team.name,
            logoUrl: team.logoUrl,
            size: 44,
          ),
          const SizedBox(height: 8),
          Text(
            team.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('il_0bcaa93dc1'),
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  teamHeader(teamA),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _scoreAController,
                    keyboardType: TextInputType.number,
                    scrollPadding: _fieldScrollPadding,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: tr('il_116cd3982a'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 36),
              child: Text(
                ':',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  teamHeader(teamB),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _scoreBController,
                    keyboardType: TextInputType.number,
                    scrollPadding: _fieldScrollPadding,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: tr('il_116cd3982a'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _teamGoalsSection({
    required void Function(void Function()) setBody,
    required String teamName,
    required List<String> teamIds,
    required Map<String, MatchFinishPlayerRow> players,
    required Color accent,
    required Map<String, TextEditingController> ctrls,
  }) {
    final teamGoals = teamIds.fold<int>(
      0,
      (sum, id) => sum + (int.tryParse(ctrls[id]?.text ?? '0') ?? 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  teamName,
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${tr('il_116cd3982a')}: $teamGoals',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (teamIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr('match_roster_missing'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            ...teamIds.map((id) {
            final row =
                players[id] ?? MatchFinishPlayerRow(displayName: tr('player'));
            final c = ctrls[id];
            if (c == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  PlayerAvatarButton(
                    userId: id,
                    displayName: row.displayName,
                    avatarUrl: row.avatarUrl,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.displayName,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: TextField(
                      controller: c,
                      keyboardType: TextInputType.number,
                      scrollPadding: _fieldScrollPadding,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: tr('il_116cd3982a'),
                      ),
                      onChanged: (_) => setBody(() {}),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _goalsStep(
    _FinishTeamInfo teamA,
    _FinishTeamInfo teamB,
    List<String> rosterA,
    List<String> rosterB,
    Map<String, MatchFinishPlayerRow> players,
    Map<String, TextEditingController> ctrls,
  ) {
    final teamAIds = rosterA;
    final teamBIds = rosterB;

    return StatefulBuilder(
      builder: (context, setBody) {
        final teamAGoals = teamAIds.fold<int>(
          0,
          (sum, id) => sum + (int.tryParse(ctrls[id]?.text ?? '0') ?? 0),
        );
        final teamBGoals = teamBIds.fold<int>(
          0,
          (sum, id) => sum + (int.tryParse(ctrls[id]?.text ?? '0') ?? 0),
        );
        final totalGoals = teamAGoals + teamBGoals;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                'match_goals_assign_intro',
                namedArgs: {
                  'teamAScore': '$_committedScoreA',
                  'teamAName': teamA.name,
                  'teamBScore': '$_committedScoreB',
                  'teamBName': teamB.name,
                },
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 16),
            _teamGoalsSection(
              setBody: setBody,
              teamName: teamA.name,
              teamIds: teamAIds,
              players: players,
              accent: _accent(0),
              ctrls: ctrls,
            ),
            _teamGoalsSection(
              setBody: setBody,
              teamName: teamB.name,
              teamIds: teamBIds,
              players: players,
              accent: _accent(1),
              ctrls: ctrls,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tr('il_f47e8394cb')}: '
                    '${teamA.name} $teamAGoals - $teamBGoals ${teamB.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tr('il_f8d6301a5e')}: $totalGoals',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 0 ? tr('finish_match') : tr('il_37d6086f07');

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2a),
        foregroundColor: Colors.white,
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<_FinishFlowData>(
        future: _finishFlowFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const FlapLoadingList(
              itemCount: 5,
              itemHeight: 88,
              radius: 16,
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${tr('error')}: ${snap.error}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final flow = snap.data!;
          final teams = flow.teamsDisplay;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == 1)
                Material(
                  color: const Color(0xFF252525),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          tr('finish_match'),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: Colors.white38),
                        ),
                        Text(
                          tr('il_37d6086f07'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _step == 0
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: _scoreStep(teams.teamA, teams.teamB),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: _goalsStep(
                          teams.teamA,
                          teams.teamB,
                          flow.rosterA,
                          flow.rosterB,
                          flow.playerRows,
                          _goalControllers!,
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Material(
                  color: const Color(0xFF2a2a2a),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: _step == 0
                        ? Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(tr('cancel')),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () => _submitScoresStep(flow),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFf44336),
                                ),
                                child: Text(tr('finish_match')),
                              ),
                            ],
                          )
                        : OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: 8,
                            overflowSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: _goToScoresStep,
                                child: Text(tr('back')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(tr('cancel')),
                              ),
                              FilledButton(
                                onPressed: () => _submitGoalsStep(flow),
                                child: Text(tr('confirm')),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rosters for finish-match goal assignment: prefer match rosters, else team membership.
@immutable
class MergedFinishRosters {
  const MergedFinishRosters({required this.rosterA, required this.rosterB});

  final List<String> rosterA;
  final List<String> rosterB;
}

MergedFinishRosters mergeFinishMatchRosterLists({
  required List<String> matchRosterA,
  required List<String> matchRosterB,
  required List<String> fetchedMembersA,
  required List<String> fetchedMembersB,
}) {
  var a = matchRosterA.isNotEmpty
      ? List<String>.from(matchRosterA)
      : List<String>.from(fetchedMembersA);
  var b = matchRosterB.isNotEmpty
      ? List<String>.from(matchRosterB)
      : List<String>.from(fetchedMembersB);
  final setA = a.toSet();
  b = b.where((id) => id.isNotEmpty && !setA.contains(id)).toList();
  return MergedFinishRosters(rosterA: a, rosterB: b);
}

Future<List<String>> fetchFinishMatchTeamMemberUserIds(
  SupabaseClient sb,
  String teamId,
) async {
  try {
    final rows =
        await sb.from('team_members').select('user_id').eq('team_id', teamId);
    return (rows as List<dynamic>)
        .map((raw) => (raw as Map<String, dynamic>)['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<_FinishTeamsDisplay> loadFinishTeamsDisplay(
  SupabaseClient sb,
  Match match,
  _FinishTeamIds ids,
) async {
  Future<_FinishTeamInfo> loadTeam(
    String? teamId, {
    required String fallbackName,
    required String? fallbackLogo,
  }) async {
    if (teamId == null || teamId.isEmpty) {
      return _FinishTeamInfo(
        id: null,
        name: fallbackName,
        logoUrl: fallbackLogo,
      );
    }
    try {
      final row = await sb
          .from('teams')
          .select('id,name,logo_url')
          .eq('id', teamId)
          .maybeSingle();
      return _FinishTeamInfo(
        id: teamId,
        name: (row?['name'] ?? fallbackName).toString(),
        logoUrl: (row?['logo_url'] ?? fallbackLogo ?? '').toString(),
      );
    } catch (_) {
      return _FinishTeamInfo(
        id: teamId,
        name: fallbackName,
        logoUrl: fallbackLogo,
      );
    }
  }

  final fallbackAName = match.teamA?.name ?? tr('il_e18d322f14');
  final fallbackBName = match.teamB?.name ?? tr('il_aceaf5d9ac');
  final teams = await Future.wait([
    loadTeam(
      ids.teamAId,
      fallbackName: fallbackAName,
      fallbackLogo: null,
    ),
    loadTeam(
      ids.teamBId,
      fallbackName: fallbackBName,
      fallbackLogo: null,
    ),
  ]);
  return _FinishTeamsDisplay(teamA: teams[0], teamB: teams[1]);
}

class _FinishFlowData {
  const _FinishFlowData({
    required this.teamsDisplay,
    required this.rosterA,
    required this.rosterB,
    required this.allPlayerIds,
    required this.playerRows,
  });

  final _FinishTeamsDisplay teamsDisplay;
  final List<String> rosterA;
  final List<String> rosterB;
  final List<String> allPlayerIds;
  final Map<String, MatchFinishPlayerRow> playerRows;
}

class _FinishTeamIds {
  const _FinishTeamIds({required this.teamAId, required this.teamBId});
  final String? teamAId;
  final String? teamBId;
}

_FinishTeamIds resolveFinishTeamIds(
  Match match,
  List<Map<String, dynamic>> inviteRows,
) {
  final hostTeamId = (match.teamAId ?? '').trim();
  final invitedTeamId = (match.teamBId ?? '').trim();
  final valid = inviteRows.where((row) {
    final status = (row['status'] ?? '').toString();
    return status == 'pending' || status == 'accepted' || status == 'declined';
  }).toList(growable: false);

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
    if (byInvitedId.isNotEmpty) scoped = byInvitedId;
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
  final invite = pool.isNotEmpty ? pool.first : null;
  final resolvedA = hostTeamId.isNotEmpty
      ? hostTeamId
      : (invite?['requesting_team_id'] ?? '').toString();
  final resolvedB = (invite?['target_team_id'] ?? '').toString().isNotEmpty
      ? (invite?['target_team_id'] ?? '').toString()
      : invitedTeamId;
  return _FinishTeamIds(
    teamAId: resolvedA.isEmpty ? null : resolvedA,
    teamBId: resolvedB.isEmpty ? null : resolvedB,
  );
}

class _FinishTeamInfo {
  const _FinishTeamInfo({
    required this.id,
    required this.name,
    required this.logoUrl,
  });

  final String? id;
  final String name;
  final String? logoUrl;
}

class _FinishTeamsDisplay {
  const _FinishTeamsDisplay({required this.teamA, required this.teamB});
  final _FinishTeamInfo teamA;
  final _FinishTeamInfo teamB;
}

String _finishMatchDisplayNameFromProfileRow(Map<String, dynamic> row) {
  String? take(String key) {
    final v = row[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  final first = take('first_name');
  final last = take('last_name');
  final combined = [
    first,
    last,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();

  final email = take('email');
  String? emailLocal;
  if (email != null && email.contains('@')) {
    final part = email.split('@').first.trim();
    if (part.isNotEmpty) emailLocal = part;
  }

  return take('display_name') ??
      take('nickname') ??
      (combined.isNotEmpty ? combined : null) ??
      emailLocal ??
      tr('player');
}

String? _finishMatchAvatarUrlFromProfileRow(Map<String, dynamic> row) {
  final v = row['avatar_url'];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Shared loader for [FinishMatchFlowPage] (match management + matches list).
Future<Map<String, MatchFinishPlayerRow>> loadFinishMatchPlayerRows(
  SupabaseClient sb,
  List<String> ids,
) async {
  if (ids.isEmpty) return <String, MatchFinishPlayerRow>{};

  final idByLower = <String, String>{};
  for (final id in ids) {
    if (id.isEmpty) continue;
    idByLower.putIfAbsent(id.toLowerCase().trim(), () => id);
  }
  final canonicalIds = idByLower.values.toList();

  final out = <String, MatchFinishPlayerRow>{};
  const chunkSize = 80;

  try {
    for (var i = 0; i < canonicalIds.length; i += chunkSize) {
      final chunk = canonicalIds.sublist(
        i,
        min(i + chunkSize, canonicalIds.length),
      );
      final rows = await sb
          .from('profiles')
          .select(
            'id,display_name,first_name,last_name,nickname,email,avatar_url',
          )
          .inFilter('id', chunk);

      for (final row in rows) {
        final rowId = (row['id'] ?? '').toString().trim();
        if (rowId.isEmpty) continue;
        final rosterKey = idByLower[rowId.toLowerCase()] ?? rowId;
        out[rosterKey] = MatchFinishPlayerRow(
          displayName: _finishMatchDisplayNameFromProfileRow(row),
          avatarUrl: _finishMatchAvatarUrlFromProfileRow(row),
        );
      }
    }
  } catch (_) {}

  for (final id in ids) {
    if (id.isEmpty) continue;
    out.putIfAbsent(id, () => MatchFinishPlayerRow(displayName: tr('player')));
  }
  return out;
}
