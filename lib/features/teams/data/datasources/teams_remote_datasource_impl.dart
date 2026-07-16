import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_stats.dart' show mapTeamStatsRowToLegacyShape;
import 'teams_remote_datasource.dart';

class TeamsRemoteDataSourceImpl implements TeamsRemoteDataSource {
  TeamsRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> _bundleTeam(String teamId) async {
    final team = await _client
        .from('teams')
        .select()
        .eq('id', teamId)
        .maybeSingle();
    if (team == null) {
      return null;
    }
    final members = await _client
        .from('team_members')
        .select('user_id,role')
        .eq('team_id', teamId);
    final rows = (members as List<dynamic>).cast<Map<String, dynamic>>();
    String captainId = '';
    final vice = <String>[];
    final memberIds = <String>[];
    for (final r in rows) {
      final uid = r['user_id'] as String;
      memberIds.add(uid);
      final role = (r['role'] ?? 'member').toString();
      if (role == 'captain') {
        captainId = uid;
      } else if (role == 'vice_captain') {
        vice.add(uid);
      }
    }

    // Pull aggregated stats from `public.team_stats` so this bundle stays
    // consistent with what the dedicated TeamStatsRemoteDataSource exposes.
    final stats = await _client
        .from('team_stats')
        .select(
          'wins,draws,losses,goals_for,goals_against,clean_sheets,'
          'current_win_streak,current_unbeaten_streak,longest_win_streak,'
          'recent_form,recent_matches,player_goals,'
          'last_finished_match_at,updated_at',
        )
        .eq('team_id', teamId)
        .maybeSingle();
    final s = stats ?? const <String, dynamic>{};

    int asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return <String, dynamic>{
      'id': teamId,
      'name': team['name'],
      'description': team['description'] ?? '',
      'captainId': captainId,
      'viceCaptainIds': vice,
      'memberIds': memberIds,
      'isPublic': team['is_public'] ?? true,
      'logoUrl': team['logo_url'],
      'city': team['city'],
      'createdAt': team['created_at'],
      'updatedAt': team['updated_at'],
      'wins': asInt(s['wins']),
      'losses': asInt(s['losses']),
      'draws': asInt(s['draws']),
      'goalsFor': asInt(s['goals_for']),
      'goalsAgainst': asInt(s['goals_against']),
      'cleanSheets': asInt(s['clean_sheets']),
      'currentWinStreak': asInt(s['current_win_streak']),
      'currentUnbeatenStreak': asInt(s['current_unbeaten_streak']),
      'longestWinStreak': asInt(s['longest_win_streak']),
      'recentForm':
          ((s['recent_form'] as List?) ?? const []).cast<dynamic>(),
      'recentMatches':
          ((s['recent_matches'] as List?) ?? const []).cast<dynamic>(),
      'playerGoals': (s['player_goals'] as Map?) ?? const <String, dynamic>{},
      'lastFinishedMatchAt': s['last_finished_match_at'],
      'statsUpdatedAt': s['updated_at'],
    };
  }

  /// Single-emission stream: the team bundle is fetched once per subscription.
  /// Callers re-subscribe (pull-to-refresh, app resume, after a mutation) to
  /// pick up other users' roster/profile edits.
  @override
  Stream<Map<String, dynamic>?> watchTeamDocument(String teamId) {
    return Stream.fromFuture(_bundleTeam(teamId));
  }

  /// Single-emission stream of every team, each with its aggregated stats.
  /// Sorted by name here; the hub applies its own ranking on top.
  @override
  Stream<List<Map<String, dynamic>>> watchTeamsOrderedByWins() {
    return Stream.fromFuture(_fetchTeamsOrderedByWins());
  }

  Future<List<Map<String, dynamic>>> _fetchTeamsOrderedByWins() async {
    final allRows = await _client.from('teams').select('id').order('name');
    final out = <Map<String, dynamic>>[];
    for (final raw in allRows as List<dynamic>) {
      final id = (raw as Map<String, dynamic>)['id'] as String;
      final bundle = await _bundleTeam(id);
      if (bundle != null) {
        out.add(bundle);
      }
    }
    return out;
  }

  /// Single-emission stream joining `teams` with `team_stats` into the legacy
  /// shape. Two queries instead of two live subscriptions over whole tables.
  @override
  Stream<List<Map<String, dynamic>>> watchTeamStatsCollection() {
    return Stream.fromFuture(_fetchTeamStatsCollection());
  }

  Future<List<Map<String, dynamic>>> _fetchTeamStatsCollection() async {
    final teamRows = (await _client.from('teams').select('id,name,updated_at'))
        .cast<Map<String, dynamic>>();
    final statRows = (await _client.from('team_stats').select())
        .cast<Map<String, dynamic>>();

    final byTeamId = <String, Map<String, dynamic>>{
      for (final s in statRows) (s['team_id']?.toString() ?? ''): s,
    };
    final list = <Map<String, dynamic>>[];
    for (final t in teamRows) {
      final id = t['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final s = byTeamId[id] ?? const <String, dynamic>{};
      list.add(
        mapTeamStatsRowToLegacyShape(
          <String, dynamic>{
            'team_name': t['name'],
            'updated_at': t['updated_at'],
            ...s,
          },
          fallbackName: (t['name'] ?? '').toString(),
        )..putIfAbsent('id', () => id),
      );
    }
    return list;
  }
}

