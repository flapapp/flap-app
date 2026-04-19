import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<void> deleteAllChallenges() async {
    await _client.from('challenges').delete().gte(
          'created_at',
          '1970-01-01T00:00:00Z',
        );
  }
}
