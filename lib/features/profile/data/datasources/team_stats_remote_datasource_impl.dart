import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../teams/data/models/team_stats.dart';
import 'team_stats_remote_datasource.dart';

/// Streams aggregate stats for a single team from `public.team_stats`,
/// joined live with `teams.name` so the UI keeps a friendly label even when
/// the team is renamed. The map shape returned here matches the legacy
/// Firestore-style fields TeamStats.fromFirestoreMap expects.
class TeamStatsRemoteDataSourceImpl implements TeamStatsRemoteDataSource {
  TeamStatsRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Stream<Map<String, dynamic>?> watchTeamStats(String teamId) {
    return _client
        .from('team_stats')
        .stream(primaryKey: ['team_id'])
        .eq('team_id', teamId)
        .asyncMap((rows) async {
          final teamRow = await _client
              .from('teams')
              .select('id,name,updated_at')
              .eq('id', teamId)
              .maybeSingle();
          final fallbackName = (teamRow?['name'] ?? '').toString();
          if (rows.isEmpty) {
            // Team exists but no aggregate row yet (first deploy / new team) —
            // hand back a zeroed shape so widgets render.
            if (teamRow == null) return null;
            return mapTeamStatsRowToLegacyShape(<String, dynamic>{
              'team_name': fallbackName,
              'updated_at': teamRow['updated_at'],
            });
          }
          final row = Map<String, dynamic>.from(rows.first);
          row['team_name'] = fallbackName;
          return mapTeamStatsRowToLegacyShape(row, fallbackName: fallbackName);
        });
  }
}
