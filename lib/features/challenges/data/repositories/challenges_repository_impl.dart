import '../models/challenge.dart';
import '../services/challenge_service.dart';
import '../../domain/repositories/challenges_repository.dart';

class ChallengesRepositoryImpl implements ChallengesRepository {
  ChallengesRepositoryImpl(this._challenges);

  final ChallengeService _challenges;

  @override
  Future<List<Challenge>> fetchActiveChallenges() {
    return _challenges.fetchActiveChallenges();
  }

  @override
  Future<List<Challenge>> fetchChallengesByStatus(ChallengeStatus status) {
    return _challenges.fetchChallengesByStatus(status);
  }

  @override
  Future<List<Challenge>> fetchChallengesByCity(String city) {
    return _challenges.fetchChallengesByCity(city);
  }

  @override
  Future<List<Challenge>> fetchChallengesByType(ChallengeType type) {
    return _challenges.fetchChallengesByType(type);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChallengesForListUi({
    int limit = 50,
    String? onlyCreatorUserId,
  }) {
    return _challenges.fetchChallengesForListUi(
      limit: limit,
      onlyCreatorUserId: onlyCreatorUserId,
    );
  }

  @override
  Future<Challenge?> getChallenge(String challengeId) {
    return _challenges.getChallenge(challengeId);
  }

  @override
  Future<String?> createChallenge(Challenge challenge) {
    return _challenges.createChallenge(challenge);
  }

  @override
  Future<bool> joinChallenge(String challengeId) {
    return _challenges.joinChallenge(challengeId);
  }

  @override
  Future<bool> submitVideo(String challengeId, String videoUrl) {
    return _challenges.submitVideo(challengeId, videoUrl);
  }

  @override
  Future<bool> voteForVideo(
    String challengeId,
    String userId,
    Map<String, double> criteria,
  ) {
    return _challenges.voteForVideo(challengeId, userId, criteria);
  }

  @override
  Future<bool> completeChallenge(String challengeId) {
    return _challenges.completeChallenge(challengeId);
  }

  @override
  Future<List<Challenge>> fetchUserChallenges(String userId) {
    return _challenges.fetchUserChallenges(userId);
  }

  @override
  Future<List<Challenge>> fetchCreatedChallenges(String userId) {
    return _challenges.fetchCreatedChallenges(userId);
  }

  @override
  Future<bool> deleteChallenge(String challengeId) {
    return _challenges.deleteChallenge(challengeId);
  }

  @override
  Future<Map<String, dynamic>> getChallengeStats() {
    return _challenges.getChallengeStats();
  }

  @override
  Future<bool> addVideoToChallenge(String challengeId, String userId) {
    return _challenges.addVideoToChallenge(challengeId, userId);
  }

  @override
  Future<void> checkAndFinishChallenges() {
    return _challenges.checkAndFinishChallenges();
  }

  @override
  Future<void> deleteOldFinishedChallenges() {
    return _challenges.deleteOldFinishedChallenges();
  }
}
