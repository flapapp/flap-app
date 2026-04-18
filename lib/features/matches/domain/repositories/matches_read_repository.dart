import '../../../../models/match.dart' as app_match;

abstract class MatchesReadRepository {
  Future<app_match.Match?> fetchMatchById(String matchId);
}
