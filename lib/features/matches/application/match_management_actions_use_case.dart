import '../data/models/match.dart';
import '../domain/repositories/matches_repository.dart';

class MatchManagementActionsUseCase {
  const MatchManagementActionsUseCase(this._matchesRepository);

  final MatchesRepository _matchesRepository;

  Future<bool> acceptApplication({
    required String matchId,
    required String userId,
  }) {
    return _matchesRepository.acceptApplication(matchId, userId);
  }

  Future<bool> rejectApplication({
    required String matchId,
    required String userId,
  }) {
    return _matchesRepository.rejectApplication(matchId, userId);
  }

  Future<bool> startMatch(String matchId) {
    return _matchesRepository.startMatch(matchId);
  }

  Future<bool> finishMatch({
    required String matchId,
    required MatchResult result,
    required int teamAScore,
    required int teamBScore,
    Map<String, int> goalsByPlayer = const {},
  }) {
    return _matchesRepository.finishMatch(
      matchId,
      result,
      teamAScore,
      teamBScore,
      goalsByPlayer: goalsByPlayer,
    );
  }
}
