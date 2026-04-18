import '../../../../models/match.dart' as app_match;
import '../../domain/repositories/matches_read_repository.dart';
import '../datasources/matches_read_remote_datasource.dart';

class MatchesReadRepositoryImpl implements MatchesReadRepository {
  MatchesReadRepositoryImpl(this._remote);

  final MatchesReadRemoteDataSource _remote;

  @override
  Future<app_match.Match?> fetchMatchById(String matchId) async {
    final snap = await _remote.getMatch(matchId);
    if (!snap.exists) return null;
    return app_match.Match.fromFirestore(snap);
  }
}
