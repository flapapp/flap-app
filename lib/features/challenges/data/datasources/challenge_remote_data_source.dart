import 'package:flap_app/models/challenge.dart';

import '../../domain/entities/challenge_submission_entry.dart';

abstract class ChallengeRemoteDataSource {
  Stream<List<Challenge>> watchChallenges({int limit = 50});

  Stream<List<ChallengeSubmissionEntry>> watchSubmissions(String challengeId);

  Future<List<Map<String, dynamic>>> fetchSubmissionRowsPage(
    String challengeId, {
    int limit = 5,
    int offset = 0,
  });

  Future<Map<String, dynamic>?> fetchChallengeRow(String id);

  /// First challenge that contains a submission with this [videoId] (Firestore `videoId`).
  Future<({String challengeId, String title})?> findChallengeForVideo(String videoId);

  Future<Map<String, dynamic>?> fetchSubmissionRow({
    required String challengeId,
    required String submissionUserId,
  });

  Future<List<Map<String, dynamic>>> fetchTopSubmissionRows(
    String challengeId, {
    int limit = 3,
  });

  Future<String> rpcCreateChallenge(Challenge draft);

  Future<void> rpcAddCreatorParticipant(String challengeId);

  Future<void> rpcJoinChallenge(String challengeId);

  Future<void> rpcCompleteChallenge(String challengeId);

  Future<void> rpcDeleteChallenge(String challengeId);

  Future<void> rpcSetCreatorVideo(
    String challengeId,
    String videoUrl, {
    String? thumbnailUrl,
  });

  Future<void> rpcUpsertSubmission({
    required String challengeId,
    required String userId,
    required String videoId,
    required String videoUrl,
    required String title,
    required String authorName,
    required bool isCreatorVideo,
    String? thumbnailUrl,
  });

  Future<void> rpcSetSubmissionThumbnail({
    required String challengeId,
    required String userId,
    required String thumbnailUrl,
  });

  Future<void> rpcCastVote({
    required String challengeId,
    required String submissionUserId,
    required double rating,
    required bool awardCoin,
  });

  Future<List<Map<String, dynamic>>> fetchMyVotes(String challengeId);

  /// Live map of submission author user id → my rating for this challenge.
  Stream<Map<String, double>> watchMyVotes(String challengeId);

  Future<bool> hasCelebrationAck(String challengeId);

  Future<void> ackCelebration(String challengeId);

  Future<List<String>> fetchInvitationTargets({
    required ChallengeAudience audience,
    required String creatorId,
    required String city,
  });
}
