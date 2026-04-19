import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'goalsFor': 0,
      'goalsAgainst': 0,
      'playerGoals': <String, int>{},
      'recentMatches': <Map<String, dynamic>>[],
    };
  }

  @override
  Stream<Map<String, dynamic>?> watchTeamDocument(String teamId) {
    final teams = _client
        .from('teams')
        .stream(primaryKey: ['id'])
        .eq('id', teamId);
    final members = _client
        .from('team_members')
        .stream(primaryKey: ['id'])
        .eq('team_id', teamId);
    return Rx.merge<dynamic>([teams, members]).asyncMap((_) => _bundleTeam(teamId));
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTeamsOrderedByWins() {
    return _client
        .from('teams')
        .stream(primaryKey: ['id'])
        .asyncMap((allRows) async {
          final rows = (allRows as List<dynamic>).cast<Map<String, dynamic>>();
          rows.sort((a, b) {
            final na = (a['name'] ?? '').toString();
            final nb = (b['name'] ?? '').toString();
            return na.compareTo(nb);
          });
          final out = <Map<String, dynamic>>[];
          for (final t in rows) {
            final id = t['id'] as String;
            final bundle = await _bundleTeam(id);
            if (bundle != null) {
              out.add(bundle);
            }
          }
          return out;
        });
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTeamStatsCollection() {
    return _client.from('teams').stream(primaryKey: ['id']).asyncMap((rows) async {
      final list = <Map<String, dynamic>>[];
      for (final raw in (rows as List<dynamic>)) {
        final t = raw as Map<String, dynamic>;
        final id = t['id'] as String;
        list.add(<String, dynamic>{
          'id': id,
          'teamName': t['name'],
          'wins': 0,
          'draws': 0,
          'losses': 0,
          'goalsFor': 0,
          'goalsAgainst': 0,
          'playerGoals': <String, int>{},
          'recentMatches': <Map<String, dynamic>>[],
          'updatedAt': t['updated_at'],
        });
      }
      return list;
    });
  }
}
