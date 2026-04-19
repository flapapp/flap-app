import '../../data/models/challenge.dart';

/// Challenge discovery, creation, participation, and lifecycle (domain).
abstract class ChallengesRepository {
  Stream<List<Challenge>> getActiveChallenges();

  Stream<List<Challenge>> getChallengesByStatus(ChallengeStatus status);

  Stream<List<Challenge>> getChallengesByCity(String city);

  Stream<List<Challenge>> getChallengesByType(ChallengeType type);

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

  Stream<List<Challenge>> getUserChallenges(String userId);

  Stream<List<Challenge>> getCreatedChallenges(String userId);

  Future<bool> deleteChallenge(String challengeId);

  Future<Map<String, dynamic>> getChallengeStats();

  Future<bool> addVideoToChallenge(String challengeId, String userId);

  Future<void> checkAndFinishChallenges();

  Future<void> deleteOldFinishedChallenges();
}
