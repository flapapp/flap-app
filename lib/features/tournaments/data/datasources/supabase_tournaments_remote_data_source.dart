import 'package:supabase_flutter/supabase_flutter.dart';

import 'tournaments_remote_data_source.dart';

class SupabaseTournamentsRemoteDataSource implements TournamentsRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchTournaments() async {
    final rows = await _client
        .from('tournaments')
        .select(
          'id, name, type, status, created_by, created_at, start_date, end_date, max_teams',
        )
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> fetchTournamentById(String tournamentId) async {
    final row = await _client
        .from('tournaments')
        .select(
          'id, name, type, status, created_by, created_at, start_date, end_date, max_teams, rules',
        )
        .eq('id', tournamentId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<void> insertTournamentJoinRequest({
    required String tournamentId,
    required String teamId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Authentication required');
    }
    await _client.from('tournament_join_requests').insert({
      'tournament_id': tournamentId,
      'team_id': teamId,
      'requested_by': uid,
    });
  }

  @override
  Future<String> insertTournament({
    required String name,
    required String type,
    int? maxTeams,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? rules,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Authentication required');
    }
    final row = await _client
        .from('tournaments')
        .insert({
          'name': name.trim(),
          'type': type,
          'status': 'DRAFT',
          'created_by': uid,
          'max_teams': maxTeams,
          'start_date': startDate?.toUtc().toIso8601String(),
          'end_date': endDate?.toUtc().toIso8601String(),
          'rules': rules,
        })
        .select('id')
        .single();
    return row['id'].toString();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMatches(String tournamentId) async {
    final rows = await _client
        .from('matches')
        .select('id, home_team_id, away_team_id, status, home_score, away_score, match_date')
        .eq('tournament_id', tournamentId)
        .order('match_date', ascending: true);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTeamsByIds(List<String> teamIds) async {
    if (teamIds.isEmpty) return const [];
    final rows = await _client.from('teams').select('id, name').inFilter('id', teamIds);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTournamentTeams(String tournamentId) async {
    final rows = await _client
        .from('tournament_teams')
        .select('team_id, status, teams(id, name)')
        .eq('tournament_id', tournamentId)
        .eq('status', 'APPROVED');
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<String> insertTournamentMatch({
    required String tournamentId,
    required String homeTeamId,
    required String awayTeamId,
    DateTime? matchDate,
    String? venue,
  }) async {
    if (homeTeamId == awayTeamId) {
      throw ArgumentError('Home and away teams must differ');
    }
    final row = await _client
        .from('matches')
        .insert({
          'tournament_id': tournamentId,
          'home_team_id': homeTeamId,
          'away_team_id': awayTeamId,
          'match_date': matchDate?.toUtc().toIso8601String(),
          'venue': venue?.trim().isEmpty == true ? null : venue?.trim(),
          'status': 'SCHEDULED',
        })
        .select('id')
        .single();
    return row['id'].toString();
  }
}
