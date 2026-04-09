import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/admin_failure.dart';
import 'admin_remote_data_source.dart';

class SupabaseAdminRemoteDataSource implements AdminRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> deleteAllChallengesAndSubmissions() async {
    try {
      await _client.rpc<void>('admin_delete_all_challenge_data');
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final code = e.code?.toLowerCase();
      if (code == 'p0001' ||
          msg.contains('not_authenticated') ||
          msg.contains('not authenticated')) {
        throw const AdminFailure(
          code: 'not-authenticated',
          message: 'Sign in required.',
        );
      }
      if (msg.contains('forbidden')) {
        throw const AdminFailure(
          code: 'forbidden',
          message: 'Admin privileges required.',
        );
      }
      throw AdminFailure(
        code: e.code ?? 'admin-error',
        message: e.message,
      );
    }
  }
}
