import 'package:supabase_flutter/supabase_flutter.dart';

import 'player_videos_remote_datasource.dart';

class PlayerVideosRemoteDataSourceImpl implements PlayerVideosRemoteDataSource {
  PlayerVideosRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> listByUserId(String userId, int limit) async {
    final rows = await _client
        .from('videos')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>).map((r) {
      final m = Map<String, dynamic>.from(r as Map<String, dynamic>);
      m['id'] = m['id']?.toString();
      m['userId'] = m['user_id'];
      m['createdAt'] = m['created_at'];
      return m;
    }).toList();
  }

  @override
  Future<List<String>> listVideoIdsForUser(String userId, int limit) async {
    final rows = await _client
        .from('videos')
        .select('id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['id'].toString())
        .toList();
  }
}
