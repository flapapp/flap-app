import '../models/challenge.dart';
import '../services/challenge_service.dart';
import '../../domain/repositories/challenges_repository.dart';

class ChallengesRepositoryImpl implements ChallengesRepository {
  ChallengesRepositoryImpl(this._challenges);

  final ChallengeService _challenges;

  @override
  Stream<List<Challenge>> getActiveChallenges() {
    return _challenges.getActiveChallenges();
  }

  @override
  Stream<List<Challenge>> getChallengesByStatus(ChallengeStatus status) {
    return _challenges.getChallengesByStatus(status);
  }

  @override
  Stream<List<Challenge>> getChallengesByCity(String city) {
    return _challenges.getChallengesByCity(city);
  }

  @override
  Stream<List<Challenge>> getChallengesByType(ChallengeType type) {
    return _challenges.getChallengesByType(type);
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
  Stream<List<Challenge>> getUserChallenges(String userId) {
    return _challenges.getUserChallenges(userId);
  }

  @override
  Stream<List<Challenge>> getCreatedChallenges(String userId) {
    return _challenges.getCreatedChallenges(userId);
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
