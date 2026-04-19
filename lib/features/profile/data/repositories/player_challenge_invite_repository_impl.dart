import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/player_challenge_invite_repository.dart';

class PlayerChallengeInviteRepositoryImpl implements PlayerChallengeInviteRepository {
  PlayerChallengeInviteRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> listInvitableChallenges({
    required String creatorUserId,
    required String targetPlayerId,
  }) async {
    final rows = await _client
        .from('challenges')
        .select()
        .eq('creator_id', creatorUserId)
        .limit(50);
    final out = <Map<String, dynamic>>[];
    for (final raw in rows as List<dynamic>) {
      final c = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final id = c['id'] as String;
      final part = await _client
          .from('challenge_participants')
          .select('user_id')
          .eq('challenge_id', id)
          .eq('user_id', targetPlayerId)
          .maybeSingle();
      if (part == null) {
        c['id'] = id;
        c['creatorId'] = c['creator_id'];
        out.add(c);
      }
    }
    return out;
  }
}
