import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session_remote_datasource.dart';

class AuthSessionRemoteDataSourceImpl implements AuthSessionRemoteDataSource {
  AuthSessionRemoteDataSourceImpl();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  String? get currentUserIdOrNull {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> resolveInitialUserId() async {
    try {
      var user = _client.auth.currentUser;
      if (user != null) {
        return user.id;
      }
      final session = _client.auth.currentSession;
      return session?.user.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
