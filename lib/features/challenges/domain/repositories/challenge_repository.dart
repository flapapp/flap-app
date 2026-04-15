import 'package:flap_app/models/challenge.dart';

import '../entities/challenge_submission_entry.dart';

abstract class ChallengeRepository {
  Stream<List<Challenge>> watchChallenges({int limit = 50});

  Stream<List<ChallengeSubmissionEntry>> watchSubmissions(String challengeId);

  Future<List<ChallengeSubmissionEntry>> getSubmissionsPage(
    String challengeId, {
    int limit = 5,
    int offset = 0,
  });

  Future<ChallengeSubmissionEntry?> getSubmission({
    required String challengeId,
    required String submissionUserId,
  });

  Future<List<ChallengeSubmissionEntry>> getTopSubmissions(
    String challengeId, {
    int limit = 3,
  });

  Future<Challenge?> getChallenge(String id);

  Future<({String challengeId, String title})?> findChallengeForVideo(String videoId);

  /// Creates challenge (deducts creator entry fee server-side). Returns new id.
  Future<String> createChallenge(Challenge draft);

  Future<void> addCreatorParticipant(String challengeId);

  Future<void> joinChallenge(String challengeId);

  Future<void> completeChallenge(String challengeId);

  Future<void> deleteChallenge(String challengeId);

  Future<void> setCreatorVideo(
    String challengeId,
    String videoUrl, {
    String? thumbnailUrl,
  });

  Future<void> upsertSubmission({
    required String challengeId,
    required String userId,
    required String videoId,
    required String videoUrl,
    required String title,
    required String authorName,
    required bool isCreatorVideo,
    String? thumbnailUrl,
  });

  Future<void> setSubmissionThumbnail({
    required String challengeId,
    required String userId,
    required String thumbnailUrl,
  });

  Future<void> castVote({
    required String challengeId,
    required String submissionUserId,
    required double rating,
    bool awardCoin = false,
  });

  Future<Map<String, double>> loadMyVotes(String challengeId);

  Stream<Map<String, double>> watchMyVotes(String challengeId);

  Future<bool> hasCelebrationAck(String challengeId);

  Future<void> ackCelebration(String challengeId);

  /// Broad audience invitations (friends / city / country / world).
  Future<void> sendAudienceInvitations({
    required String challengeId,
    required Challenge challenge,
  });
}
