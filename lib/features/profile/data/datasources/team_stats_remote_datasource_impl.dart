import 'package:supabase_flutter/supabase_flutter.dart';

import 'team_stats_remote_datasource.dart';

class TeamStatsRemoteDataSourceImpl implements TeamStatsRemoteDataSource {
  TeamStatsRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Stream<Map<String, dynamic>?> watchTeamStats(String teamId) {
    return _client
        .from('teams')
        .stream(primaryKey: ['id'])
        .eq('id', teamId)
        .asyncMap((rows) async {
          if (rows.isEmpty) {
            return null;
          }
          final row = rows.first;
          final name = (row['name'] ?? '').toString();
          return <String, dynamic>{
            'teamName': name,
            'wins': 0,
            'draws': 0,
            'losses': 0,
            'goalsFor': 0,
            'goalsAgainst': 0,
            'playerGoals': <String, int>{},
            'recentMatches': <Map<String, dynamic>>[],
            'updatedAt': row['updated_at'],
          };
        });
  }
}
