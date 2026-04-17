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
}
