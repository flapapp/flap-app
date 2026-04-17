import '../../domain/repositories/team_stats_repository.dart';
import '../datasources/team_stats_remote_datasource.dart';

class TeamStatsRepositoryImpl implements TeamStatsRepository {
  TeamStatsRepositoryImpl(this._remote);

  final TeamStatsRemoteDataSource _remote;

  @override
  Stream<Map<String, dynamic>?> watchTeamStats(String teamId) {
    return _remote.watchTeamStats(teamId).map((s) => s.data());
  }
}
