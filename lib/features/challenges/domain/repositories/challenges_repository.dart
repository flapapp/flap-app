import '../../data/models/challenge.dart';

/// Challenge discovery, creation, participation, and lifecycle (domain).
abstract class ChallengesRepository {
  Future<List<Challenge>> fetchActiveChallenges();

  Future<List<Challenge>> fetchChallengesByStatus(ChallengeStatus status);

  Future<List<Challenge>> fetchChallengesByCity(String city);

  Future<List<Challenge>> fetchChallengesByType(ChallengeType type);

  /// Card/list UI rows with participant and submission aggregates.
  Future<List<Map<String, dynamic>>> fetchChallengesForListUi({
    int limit = 50,
    String? onlyCreatorUserId,
  });

  Future<Challenge?> getChallenge(String challengeId);

  Future<String?> createChallenge(Challenge challenge);

  Future<bool> joinChallenge(String challengeId);

  Future<bool> submitVideo(String challengeId, String videoUrl);

  Future<bool> voteForVideo(
    String challengeId,
    String userId,
    Map<String, double> criteria,
  );

  Future<bool> completeChallenge(String challengeId);

  Future<List<Challenge>> fetchUserChallenges(String userId);

  Future<List<Challenge>> fetchCreatedChallenges(String userId);

  Future<bool> deleteChallenge(String challengeId);

  Future<Map<String, dynamic>> getChallengeStats();

  Future<bool> addVideoToChallenge(String challengeId, String userId);

  Future<void> checkAndFinishChallenges();

  Future<void> deleteOldFinishedChallenges();
}
