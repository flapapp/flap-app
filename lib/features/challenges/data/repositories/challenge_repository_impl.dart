import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/models/challenge.dart';

import '../../domain/entities/challenge_submission_entry.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../datasources/challenge_remote_data_source.dart';

class ChallengeRepositoryImpl implements ChallengeRepository {
  ChallengeRepositoryImpl(this._remote);

  final ChallengeRemoteDataSource _remote;
  final NotificationService _notifications = NotificationService();

  @override
  Stream<List<Challenge>> watchChallenges({int limit = 50}) =>
      _remote.watchChallenges(limit: limit);

  @override
  Stream<List<ChallengeSubmissionEntry>> watchSubmissions(String challengeId) =>
      _remote.watchSubmissions(challengeId);

  @override
  Future<Challenge?> getChallenge(String id) async {
    final row = await _remote.fetchChallengeRow(id);
    if (row == null) return null;
    return Challenge.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<({String challengeId, String title})?> findChallengeForVideo(String videoId) =>
      _remote.findChallengeForVideo(videoId);

  @override
  Future<ChallengeSubmissionEntry?> getSubmission({
    required String challengeId,
    required String submissionUserId,
  }) async {
    final row = await _remote.fetchSubmissionRow(
      challengeId: challengeId,
      submissionUserId: submissionUserId,
    );
    if (row == null) return null;
    return ChallengeSubmissionEntry.fromSupabaseRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<ChallengeSubmissionEntry>> getTopSubmissions(
    String challengeId, {
    int limit = 3,
  }) async {
    final rows = await _remote.fetchTopSubmissionRows(challengeId, limit: limit);
    return rows.map((e) => ChallengeSubmissionEntry.fromSupabaseRow(e)).toList();
  }

  @override
  Future<String> createChallenge(Challenge draft) async {
    final id = await _remote.rpcCreateChallenge(draft);
    final full = await getChallenge(id) ?? draft.copyWith(id: id);
    await sendAudienceInvitations(challengeId: id, challenge: full);
    return id;
  }

  @override
  Future<void> addCreatorParticipant(String challengeId) =>
      _remote.rpcAddCreatorParticipant(challengeId);

  @override
  Future<void> joinChallenge(String challengeId) =>
      _remote.rpcJoinChallenge(challengeId);

  @override
  Future<void> completeChallenge(String challengeId) async {
    await _remote.rpcCompleteChallenge(challengeId);
    final c = await getChallenge(challengeId);
    if (c == null) return;
    final winners = c.winners.toSet();
    for (final pid in c.participants.toSet()) {
      if (pid.isEmpty || winners.contains(pid)) continue;
      await _notifications.sendChallengeCompletedNotification(
        toUserId: pid,
        challengeTitle: c.title,
        challengeId: challengeId,
      );
    }
    for (var i = 0; i < c.winners.length; i++) {
      final wid = c.winners[i];
      final prize = c.winnerPrizes[wid] ?? 0;
      if (wid.isEmpty || prize <= 0) continue;
      await _notifications.sendChallengeResultNotification(
        toUserId: wid,
        challengeTitle: c.title,
        challengeId: challengeId,
        position: i + 1,
        coinsWon: prize,
      );
    }
  }

  @override
  Future<void> deleteChallenge(String challengeId) =>
      _remote.rpcDeleteChallenge(challengeId);

  @override
  Future<void> setCreatorVideo(
    String challengeId,
    String videoUrl, {
    String? thumbnailUrl,
  }) =>
      _remote.rpcSetCreatorVideo(challengeId, videoUrl, thumbnailUrl: thumbnailUrl);

  @override
  Future<void> upsertSubmission({
    required String challengeId,
    required String userId,
    required String videoId,
    required String videoUrl,
    required String title,
    required String authorName,
    required bool isCreatorVideo,
    String? thumbnailUrl,
  }) =>
      _remote.rpcUpsertSubmission(
        challengeId: challengeId,
        userId: userId,
        videoId: videoId,
        videoUrl: videoUrl,
        title: title,
        authorName: authorName,
        isCreatorVideo: isCreatorVideo,
        thumbnailUrl: thumbnailUrl,
      );

  @override
  Future<void> setSubmissionThumbnail({
    required String challengeId,
    required String userId,
    required String thumbnailUrl,
  }) =>
      _remote.rpcSetSubmissionThumbnail(
        challengeId: challengeId,
        userId: userId,
        thumbnailUrl: thumbnailUrl,
      );

  @override
  Future<void> castVote({
    required String challengeId,
    required String submissionUserId,
    required double rating,
    bool awardCoin = false,
  }) =>
      _remote.rpcCastVote(
        challengeId: challengeId,
        submissionUserId: submissionUserId,
        rating: rating,
        awardCoin: awardCoin,
      );

  @override
  Future<Map<String, double>> loadMyVotes(String challengeId) async {
    final rows = await _remote.fetchMyVotes(challengeId);
    final out = <String, double>{};
    for (final r in rows) {
      final sid = r['submission_user_id']?.toString();
      final rt = (r['rating'] as num?)?.toDouble();
      if (sid != null && rt != null) {
        out[sid] = rt;
      }
    }
    return out;
  }

  @override
  Stream<Map<String, double>> watchMyVotes(String challengeId) =>
      _remote.watchMyVotes(challengeId);

  @override
  Future<bool> hasCelebrationAck(String challengeId) =>
      _remote.hasCelebrationAck(challengeId);

  @override
  Future<void> ackCelebration(String challengeId) => _remote.ackCelebration(challengeId);

  @override
  Future<void> sendAudienceInvitations({
    required String challengeId,
    required Challenge challenge,
  }) async {
    final ids = await _remote.fetchInvitationTargets(
      audience: challenge.audience,
      creatorId: challenge.creatorId,
      city: challenge.city,
    );
    if (ids.isEmpty) return;
    await _notifications.sendBulkChallengeInvitations(
      userIds: ids,
      challengeId: challengeId,
      challengeTitle: challenge.title,
      creatorName: challenge.creatorName,
      challengeType: challengeTypeToSlug(challenge.type),
    );
  }
}
