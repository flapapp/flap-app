import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../teams/data/models/team_stats.dart';
import 'team_stats_remote_datasource.dart';

/// Reads aggregate stats for a single team from `public.team_stats`, joined
/// with `teams.name` so the UI keeps a friendly label even when the team is
/// renamed. The map shape returned here matches the legacy Firestore-style
/// fields TeamStats.fromFirestoreMap expects.
///
/// Stats only move when a match is finished, so this is a single-emission
/// stream fetched once per subscription; callers re-subscribe to refresh.
class TeamStatsRemoteDataSourceImpl implements TeamStatsRemoteDataSource {
  TeamStatsRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Stream<Map<String, dynamic>?> watchTeamStats(String teamId) {
    return Stream.fromFuture(_fetchTeamStats(teamId));
  }

  Future<Map<String, dynamic>?> _fetchTeamStats(String teamId) async {
    final teamRow = await _client
        .from('teams')
        .select('id,name,updated_at')
        .eq('id', teamId)
        .maybeSingle();
    final fallbackName = (teamRow?['name'] ?? '').toString();

    final statsRow = await _client
        .from('team_stats')
        .select()
        .eq('team_id', teamId)
        .maybeSingle();

    if (statsRow == null) {
      // Team exists but no aggregate row yet (first deploy / new team) —
      // hand back a zeroed shape so widgets render.
      if (teamRow == null) return null;
      return mapTeamStatsRowToLegacyShape(<String, dynamic>{
        'team_name': fallbackName,
        'updated_at': teamRow['updated_at'],
      });
    }
    final row = Map<String, dynamic>.from(statsRow);
    row['team_name'] = fallbackName;
    return mapTeamStatsRowToLegacyShape(row, fallbackName: fallbackName);
  }
}
