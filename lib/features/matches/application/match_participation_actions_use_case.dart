import '../domain/repositories/matches_repository.dart';

class MatchParticipationActionsUseCase {
  const MatchParticipationActionsUseCase(this._matchesRepository);

  final MatchesRepository _matchesRepository;

  Future<bool> applyForMatch({
    required String matchId,
    required String userId,
  }) {
    return _matchesRepository.applyForMatch(matchId, userId);
  }

  Future<bool> leaveMatch({
    required String matchId,
    required String userId,
  }) {
    return _matchesRepository.leaveMatch(matchId, userId);
  }

  Future<bool> joinMatch({
    required String matchId,
    required String userId,
  }) {
    return _matchesRepository.joinMatch(matchId, userId);
  }
}
