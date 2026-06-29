import '../../../../core/auth/app_auth.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_session_repository.dart';
import '../datasources/auth_session_remote_datasource.dart';

class AuthSessionRepositoryImpl implements AuthSessionRepository {
  AuthSessionRepositoryImpl(this._remote);

  final AuthSessionRemoteDataSource _remote;

  @override
  AuthUser? get peekCurrentUser {
    final uid = _remote.currentUserIdOrNull;
    if (uid == null) return null;
    return AuthUser(uid: uid);
  }

  @override
  Future<AuthUser?> resolveInitialSession() async {
    final uid = await _remote.resolveInitialUserId();
    if (uid == null) return null;
    return AuthUser(uid: uid);
  }

  @override
  // Routes through AppAuth.signOut() so every logout (UI + account deletion)
  // performs the full session teardown: revoke push token, end the Supabase
  // session, and wipe all user-scoped in-memory caches/stores/blocs.
  Future<void> signOut() => AppAuth.signOut();
}
