import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../domain/repositories/player_videos_repository.dart';
import '../datasources/player_videos_remote_datasource.dart';

class PlayerVideosRepositoryImpl implements PlayerVideosRepository {
  PlayerVideosRepositoryImpl(this._remote, this._authSession);

  final PlayerVideosRemoteDataSource _remote;
  final AuthSessionRepository _authSession;

  @override
  Future<List<Map<String, dynamic>>> listVideosForUser(String userId, int limit) {
    return _remote.listByUserId(userId, limit);
  }

  @override
  Future<List<Map<String, dynamic>>> listMyVideos(int limit) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) return [];
    return _remote.listByUserId(uid, limit);
  }

  @override
  Future<List<String>> listMyVideoIds(int limit) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) return [];
    return _remote.listVideoIdsForUser(uid, limit);
  }
}
