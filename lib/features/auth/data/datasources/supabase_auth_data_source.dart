import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth_failure.dart';
import '../../domain/entities/app_user.dart';
import 'auth_remote_data_source.dart';

class SupabaseAuthDataSource implements AuthRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  static AppUser _mapUser(User u) {
    final meta = u.userMetadata;
    final name = meta == null
        ? null
        : (meta['display_name'] ?? meta['full_name'] ?? meta['name'])
            as String?;
    final avatar = meta == null ? null : meta['avatar_url'] as String?;
    return AppUser(
      id: u.id,
      email: u.email,
      displayName: name,
      photoUrl: avatar,
    );
  }

  @override
  AppUser? get currentUser {
    final u = _client.auth.currentUser;
    if (u == null) return null;
    return _mapUser(u);
  }

  @override
  Stream<AppUser?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) {
        final u = data.session?.user;
        if (u == null) return null;
        return _mapUser(u);
      });

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(code: e.message, message: e.message);
    }
  }

  static bool _isDuplicateSignupError(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase();
    return msg.contains('already registered') ||
        msg.contains('already been registered') ||
        msg.contains('user already exists') ||
        code == 'user_already_exists' ||
        code == 'email_exists';
  }

  @override
  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      final u = res.user;
      if (u == null) {
        throw const AuthFailure(
          code: 'signup-incomplete',
          message: 'Confirm your email or disable email confirmation in project auth settings',
        );
      }
      // With email confirmation on, Supabase often returns 200 + a stub user with no
      // identities so the address is not enumerable. That can still create a session.
      final identities = u.identities;
      if (identities == null || identities.isEmpty) {
        await _client.auth.signOut();
        throw const AuthFailure(
          code: 'email-already-in-use',
          message: '',
        );
      }
      return _mapUser(u);
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      if (_isDuplicateSignupError(e)) {
        await _client.auth.signOut();
        throw const AuthFailure(
          code: 'email-already-in-use',
          message: '',
        );
      }
      throw AuthFailure(
        code: e.code ?? 'auth-error',
        message: e.message,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> setWebPersistenceLocal() async {
    // supabase_flutter persists session by default (platform storage).
  }
}
