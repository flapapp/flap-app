import 'package:flap_app/models/challenge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/challenge_failure.dart';
import '../../domain/entities/challenge_submission_entry.dart';
import 'challenge_remote_data_source.dart';

class SupabaseChallengeRemoteDataSource implements ChallengeRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Stream<List<Challenge>> watchChallenges({int limit = 50}) {
    return _client
        .from('challenges')
        .stream(primaryKey: ['id'])
        .map((raw) {
          final list = (raw as List)
              .map((e) => Challenge.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (list.length > limit) {
            return list.sublist(0, limit);
          }
          return list;
        });
  }

  @override
  Stream<List<ChallengeSubmissionEntry>> watchSubmissions(String challengeId) {
    return _client
        .from('submissions')
        .stream(primaryKey: ['id'])
        .eq('challenge_id', challengeId)
        .map((raw) {
          final rows = (raw as List).cast<Map>();
          final entries = rows
              .map((e) =>
                  ChallengeSubmissionEntry.fromSupabaseRow(Map<String, dynamic>.from(e)))
              .where((s) => s.userId.isNotEmpty)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return entries;
        });
  }

  @override
  Future<Map<String, dynamic>?> fetchChallengeRow(String id) {
    return _client.from('challenges').select().eq('id', id).maybeSingle();
  }

  @override
  Future<({String challengeId, String title})?> findChallengeForVideo(
    String videoId,
  ) async {
    if (videoId.isEmpty) return null;
    final rows = await _client
        .from('submissions')
        .select('challenge_id')
        .eq('video_id', videoId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final cid = (list.first as Map)['challenge_id']?.toString();
    if (cid == null || cid.isEmpty) return null;
    final crow = await _client
        .from('challenges')
        .select('title')
        .eq('id', cid)
        .maybeSingle();
    final t = crow?['title']?.toString() ?? '';
    return (challengeId: cid, title: t);
  }

  @override
  Future<Map<String, dynamic>?> fetchSubmissionRow({
    required String challengeId,
    required String submissionUserId,
  }) {
    return _client
        .from('submissions')
        .select()
        .eq('challenge_id', challengeId)
        .eq('user_id', submissionUserId)
        .maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTopSubmissionRows(
    String challengeId, {
    int limit = 3,
  }) async {
    final rows = await _client
        .from('submissions')
        .select()
        .eq('challenge_id', challengeId)
        .eq('is_active', true)
        .order('average_rating', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  @override
  Future<String> rpcCreateChallenge(Challenge draft) async {
    try {
      final res = await _client.rpc<dynamic>(
        'create_challenge',
        params: <String, dynamic>{
          'p_title': draft.title,
          'p_description': draft.description,
          'p_type': challengeTypeToSlug(draft.type),
          'p_audience': draft.audience.toString().split('.').last,
          'p_creator_name': draft.creatorName,
          'p_city': draft.city,
          'p_entry_fee': draft.entryFee,
          'p_duration': draft.duration,
          'p_start_date': draft.startDate.toUtc().toIso8601String(),
          'p_submission_deadline': draft.submissionDeadline.toUtc().toIso8601String(),
          'p_voting_deadline': draft.votingDeadline.toUtc().toIso8601String(),
          'p_end_date': draft.endDate.toUtc().toIso8601String(),
          'p_max_participants': draft.maxParticipants,
          'p_status': draft.status.toString().split('.').last,
          'p_tags': draft.tags,
        },
      );
      return res.toString();
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcAddCreatorParticipant(String challengeId) async {
    try {
      await _client.rpc<void>(
        'challenge_add_creator_participant',
        params: {'p_challenge_id': challengeId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcJoinChallenge(String challengeId) async {
    try {
      await _client.rpc<void>(
        'join_challenge',
        params: {'p_challenge_id': challengeId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcCompleteChallenge(String challengeId) async {
    try {
      await _client.rpc<void>(
        'complete_challenge',
        params: {'p_challenge_id': challengeId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcDeleteChallenge(String challengeId) async {
    try {
      await _client.rpc<void>(
        'delete_challenge',
        params: {'p_challenge_id': challengeId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcSetCreatorVideo(
    String challengeId,
    String videoUrl, {
    String? thumbnailUrl,
  }) async {
    try {
      await _client.rpc<void>(
        'challenge_set_creator_video',
        params: <String, dynamic>{
          'p_challenge_id': challengeId,
          'p_creator_video_url': videoUrl,
          'p_creator_thumbnail_url': thumbnailUrl,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcUpsertSubmission({
    required String challengeId,
    required String userId,
    required String videoId,
    required String videoUrl,
    required String title,
    required String authorName,
    required bool isCreatorVideo,
    String? thumbnailUrl,
  }) async {
    try {
      await _client.rpc<void>(
        'upsert_challenge_submission',
        params: <String, dynamic>{
          'p_challenge_id': challengeId,
          'p_user_id': userId,
          'p_video_id': videoId,
          'p_video_url': videoUrl,
          'p_title': title,
          'p_author_name': authorName,
          'p_is_creator_video': isCreatorVideo,
          'p_thumbnail_url': thumbnailUrl,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcSetSubmissionThumbnail({
    required String challengeId,
    required String userId,
    required String thumbnailUrl,
  }) async {
    try {
      await _client.rpc<void>(
        'challenge_submission_set_thumbnail',
        params: <String, dynamic>{
          'p_challenge_id': challengeId,
          'p_user_id': userId,
          'p_thumbnail_url': thumbnailUrl,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcCastVote({
    required String challengeId,
    required String submissionUserId,
    required double rating,
    required bool awardCoin,
  }) async {
    try {
      await _client.rpc<void>(
        'cast_challenge_vote',
        params: <String, dynamic>{
          'p_challenge_id': challengeId,
          'p_submission_user_id': submissionUserId,
          'p_rating': rating,
          'p_award_coin': awardCoin,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMyVotes(String challengeId) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('challenge_votes')
        .select('submission_user_id, rating')
        .eq('challenge_id', challengeId)
        .eq('voter_id', uid);
    return List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  @override
  Stream<Map<String, double>> watchMyVotes(String challengeId) {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(<String, double>{});
    }
    return _client
        .from('challenge_votes')
        .stream(primaryKey: ['id'])
        .eq('challenge_id', challengeId)
        .map((raw) {
          final rows = (raw as List).cast<Map>();
          final m = <String, double>{};
          for (final e in rows) {
            if (e['voter_id']?.toString() != uid) continue;
            final sid = e['submission_user_id']?.toString() ?? '';
            if (sid.isEmpty) continue;
            m[sid] = (e['rating'] as num?)?.toDouble() ?? 0.0;
          }
          return m;
        });
  }

  @override
  Future<bool> hasCelebrationAck(String challengeId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _client
        .from('challenge_celebration_ack')
        .select('user_id')
        .eq('user_id', uid)
        .eq('challenge_id', challengeId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> ackCelebration(String challengeId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('challenge_celebration_ack').upsert(<String, dynamic>{
      'user_id': uid,
      'challenge_id': challengeId,
      'shown_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<String>> fetchInvitationTargets({
    required ChallengeAudience audience,
    required String creatorId,
    required String city,
  }) async {
    switch (audience) {
      case ChallengeAudience.friends:
        final rows = await _client
            .from('user_friends')
            .select('friend_id')
            .eq('user_id', creatorId);
        return (rows as List)
            .map((e) => (e as Map)['friend_id'].toString())
            .where((id) => id.isNotEmpty && id != creatorId)
            .toList();
      case ChallengeAudience.city:
        final rows = await _client
            .from('profiles')
            .select('id')
            .eq('city', city)
            .neq('id', creatorId)
            .limit(50);
        return (rows as List).map((e) => (e as Map)['id'].toString()).toList();
      case ChallengeAudience.country:
        final rows = await _client
            .from('profiles')
            .select('id')
            .eq('country', 'Україна')
            .neq('id', creatorId)
            .limit(100);
        return (rows as List).map((e) => (e as Map)['id'].toString()).toList();
      case ChallengeAudience.world:
        final rows =
            await _client.from('profiles').select('id').neq('id', creatorId).limit(200);
        return (rows as List).map((e) => (e as Map)['id'].toString()).toList();
    }
  }

  ChallengeFailure _mapPostgrest(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase();
    if (code == '23505' || msg.contains('unique')) {
      return ChallengeFailure(code: 'duplicate', message: e.message);
    }
    if (msg.contains('not_authenticated')) {
      return const ChallengeFailure(code: 'not-authenticated', message: 'Not signed in.');
    }
    if (msg.contains('insufficient_coins')) {
      return const ChallengeFailure(code: 'insufficient-coins', message: 'Not enough coins.');
    }
    if (msg.contains('challenge_monthly_limit')) {
      return const ChallengeFailure(
        code: 'monthly-limit',
        message: 'Monthly challenge limit reached.',
      );
    }
    if (msg.contains('already_joined')) {
      return const ChallengeFailure(code: 'already-joined', message: 'Already joined.');
    }
    if (msg.contains('cannot_vote_self')) {
      return const ChallengeFailure(code: 'cannot-vote-self', message: 'Cannot vote for yourself.');
    }
    if (msg.contains('voting_not_open')) {
      return const ChallengeFailure(code: 'voting-closed', message: 'Voting is not open.');
    }
    if (msg.contains('forbidden') || msg.contains('not_in_voting')) {
      return ChallengeFailure(code: 'forbidden', message: e.message);
    }
    return ChallengeFailure(code: e.code ?? 'challenge-error', message: e.message);
  }
}
