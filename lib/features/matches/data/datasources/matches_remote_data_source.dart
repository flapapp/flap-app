import 'package:flap_app/models/match.dart';

abstract class MatchesRemoteDataSource {
  Future<String> insertMatch(Match match);

  Future<void> saveMatch(Match match);

  Future<Match?> fetchMatch(String id);

  Future<void> deleteMatchRow(String id);

  Stream<List<Match>> watchMatchesTable();

  Future<List<Map<String, dynamic>>> fetchFixtures(String matchId);

  Future<void> deleteAllFixtures(String matchId);

  Future<void> insertFixturesLegacy(String matchId, List<Map<String, dynamic>> fixtures);

  Future<void> updateFixtureScores({
    required String matchId,
    required String fixtureId,
    required int scoreA,
    required int scoreB,
    required String status,
  });

  Future<bool> allFixturesFinished(String matchId);

  Future<void> markMatchFinished(String matchId);

  /// Marks match cancelled with legacy `unplayed` flags in `document` jsonb.
  Future<void> cancelMatchAsUnplayed(String matchId);

  /// Merges keys into `document` jsonb (preserves fields not modeled on [Match]).
  Future<void> patchDocumentOnly(String matchId, Map<String, dynamic> patch);
}
