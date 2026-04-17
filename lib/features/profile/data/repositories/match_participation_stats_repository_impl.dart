import '../../domain/repositories/match_participation_stats_repository.dart';
import '../datasources/match_participation_stats_remote_datasource.dart';

class MatchParticipationStatsRepositoryImpl
    implements MatchParticipationStatsRepository {
  MatchParticipationStatsRepositoryImpl(this._remote);

  final MatchParticipationStatsRemoteDataSource _remote;

  @override
  Future<Map<String, dynamic>> loadFinishedMatchStats(String userId) {
    return _remote.loadFinishedMatchStats(userId);
  }
}
