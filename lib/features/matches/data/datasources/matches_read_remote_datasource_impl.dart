import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/match_legacy_remote_mapper.dart';
import 'matches_read_remote_datasource.dart';

class MatchesReadRemoteDataSourceImpl implements MatchesReadRemoteDataSource {
  MatchesReadRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> getMatch(String matchId) {
    return MatchLegacyRemoteMapper.load(_client, matchId);
  }
}
