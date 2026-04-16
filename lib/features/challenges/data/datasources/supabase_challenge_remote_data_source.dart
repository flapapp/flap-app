import 'package:flap_app/models/challenge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/challenge_failure.dart';
import '../../domain/entities/challenge_submission_entry.dart';
import 'challenge_remote_data_source.dart';

class SupabaseChallengeRemoteDataSource implements ChallengeRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  String _audienceToSchema(ChallengeAudience audience) {
    switch (audience) {
      case ChallengeAudience.friends:
        return 'FRIENDS';
      case ChallengeAudience.city:
        return 'CITY';
      case ChallengeAudience.country:
        return 'COUNTRY';
      case ChallengeAudience.world:
        return 'WORLDWIDE';
    }
  }

  Map<String, dynamic> _buildPrizeDistributionJson(Challenge draft) {
    final pool = draft.prizePool > 0 ? draft.prizePool : (draft.entryFee * 20).toDouble();
    final first = (pool * 0.5).round();
    final second = (pool * 0.3).round();
    final third = (pool * 0.2).round();
    return <String, dynamic>{
      'currency': 'COINS',
      'total_pool': pool,
      'distribution': <Map<String, dynamic>>[
        <String, dynamic>{'position': 1, 'percent': 50, 'amount': first},
        <String, dynamic>{'position': 2, 'percent': 30, 'amount': second},
        <String, dynamic>{'position': 3, 'percent': 20, 'amount': third},
      ],
    };
  }

  @override
  Stream<List<Challenge>> watchChallenges({int limit = 50}) {
    return _client
        .from('challenges')
        .stream(primaryKey: ['id'])
        .asyncMap((raw) async {
          final challengeRows = (raw as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (challengeRows.isEmpty) return <Challenge>[];
          final challengeIds = challengeRows.map((e) => e['id'].toString()).toList();
          final submissionRows = await _client
              .from('challenge_submissions')
              .select('challenge_id, user_id, rank, is_winner')
              .inFilter('challenge_id', challengeIds);
          final byChallenge = <String, List<Map<String, dynamic>>>{};
          for (final rawSubmission in (submissionRows as List)) {
            final row = Map<String, dynamic>.from(rawSubmission as Map);
            final challengeId = row['challenge_id']?.toString() ?? '';
            if (challengeId.isEmpty) continue;
            byChallenge.putIfAbsent(challengeId, () => <Map<String, dynamic>>[]).add(row);
          }

          final list = challengeRows.map((row) {
            final cid = row['id']?.toString() ?? '';
            final creatorId = row['user_id']?.toString() ?? '';
            final rowsForChallenge = byChallenge[cid] ?? const <Map<String, dynamic>>[];
            final participantIds = rowsForChallenge
                .map((e) => e['user_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();
            if (creatorId.isNotEmpty && !participantIds.contains(creatorId)) {
              participantIds.add(creatorId);
            }
            final sortedWinners = rowsForChallenge
                .where((e) => e['is_winner'] == true)
                .toList()
              ..sort((a, b) {
                final ar = (a['rank'] as num?)?.toInt() ?? 999;
                final br = (b['rank'] as num?)?.toInt() ?? 999;
                return ar.compareTo(br);
              });
            final winners = sortedWinners
                .map((e) => e['user_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();

            return Challenge.fromJson(<String, dynamic>{
              ...row,
              'participants': participantIds,
              'submission_user_ids': rowsForChallenge
                  .map((e) => e['user_id']?.toString() ?? '')
                  .where((id) => id.isNotEmpty)
                  .toList(),
              'current_participants': participantIds.length,
              'winners': winners,
            });
          }).toList()
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
        .from('challenge_submissions')
        .stream(primaryKey: ['id'])
        .eq('challenge_id', challengeId)
        .asyncMap((raw) async {
          final rows = (raw as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final enriched = await _enrichSubmissionRows(challengeId, rows);
          final entries = enriched
              .map(ChallengeSubmissionEntry.fromSupabaseRow)
              .where((s) => s.userId.isNotEmpty)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return entries;
        });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSubmissionRowsPage(
    String challengeId, {
    int limit = 5,
    int offset = 0,
  }) async {
    final safeLimit = limit <= 0 ? 5 : limit;
    final safeOffset = offset < 0 ? 0 : offset;
    final rows = await _client
        .from('challenge_submissions')
        .select()
        .eq('challenge_id', challengeId)
        .order('created_at', ascending: false)
        .range(safeOffset, safeOffset + safeLimit - 1);
    final rawRows = List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return _enrichSubmissionRows(challengeId, rawRows);
  }

  Future<List<Map<String, dynamic>>> _enrichSubmissionRows(
    String challengeId,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return <Map<String, dynamic>>[];

    final challengeRow = await _client
        .from('challenges')
        .select('user_id')
        .eq('id', challengeId)
        .maybeSingle();
    final creatorId = challengeRow?['user_id']?.toString() ?? '';

    final userIds = rows
        .map((e) => e['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final submissionIds = rows
        .map((e) => e['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final displayNameByUserId = <String, String>{};
    if (userIds.isNotEmpty) {
      final profileRows = await _client
          .from('user_profiles')
          .select('id, display_name, username')
          .inFilter('id', userIds);
      for (final rawProfile in (profileRows as List)) {
        final profile = Map<String, dynamic>.from(rawProfile as Map);
        final userId = profile['id']?.toString() ?? '';
        if (userId.isEmpty) continue;
        final name = (profile['display_name'] ?? profile['username'] ?? '').toString();
        if (name.isNotEmpty) {
          displayNameByUserId[userId] = name;
        }
      }
    }

    var voteStats = <String, Map<String, dynamic>>{};
    if (submissionIds.isNotEmpty) {
      final voteRows = await _client
          .from('challenge_votes')
          .select('submission_id, rating')
          .inFilter('submission_id', submissionIds);
      final grouped = <String, List<double>>{};
      for (final rawVote in (voteRows as List)) {
        final vote = Map<String, dynamic>.from(rawVote as Map);
        final sid = vote['submission_id']?.toString() ?? '';
        if (sid.isEmpty) continue;
        final rating = (vote['rating'] as num?)?.toDouble();
        if (rating == null) continue;
        grouped.putIfAbsent(sid, () => <double>[]).add(rating);
      }
      voteStats = grouped.map((key, ratings) {
        final count = ratings.length;
        final avg = count == 0 ? 0.0 : ratings.reduce((a, b) => a + b) / count;
        return MapEntry(
          key,
          <String, dynamic>{'average_rating': avg, 'vote_count': count},
        );
      });
    }

    return rows.map((row) {
      final userId = row['user_id']?.toString() ?? '';
      final id = row['id']?.toString() ?? '';
      return <String, dynamic>{
        ...row,
        'title': (row['title'] ?? '').toString(),
        'author_name': (displayNameByUserId[userId] ?? row['author_name'] ?? '').toString(),
        'thumbnail_url': (row['thumbnail_url'] ?? '').toString(),
        'is_creator_video': creatorId.isNotEmpty && creatorId == userId,
        ...?voteStats[id],
      };
    }).toList();
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
        .from('challenge_submissions')
        .select('challenge_id')
        .or('video_storage_path.eq.$videoId,video_url.eq.$videoId')
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
  }) async {
    final row = await _client
        .from('challenge_submissions')
        .select()
        .eq('challenge_id', challengeId)
        .eq('user_id', submissionUserId)
        .maybeSingle();
    if (row == null) return null;
    final enriched = await _enrichSubmissionRows(
      challengeId,
      <Map<String, dynamic>>[Map<String, dynamic>.from(row)],
    );
    if (enriched.isEmpty) return null;
    return enriched.first;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTopSubmissionRows(
    String challengeId, {
    int limit = 3,
  }) async {
    final rows = await _client
        .from('challenge_submissions')
        .select()
        .eq('challenge_id', challengeId)
        .eq('status', 'APPROVED')
        .order('rank', ascending: true)
        .limit(limit);
    final rawRows = List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return _enrichSubmissionRows(challengeId, rawRows);
  }

  @override
  Future<String> rpcCreateChallenge(Challenge draft) async {
    try {
      try {
        await _client.auth.refreshSession();
      } on AuthException catch (_) {
        // Keep going; insert may still work if the access token is valid.
      }
      final uid = _uid;
      if (uid == null) {
        throw const ChallengeFailure(code: 'not-authenticated', message: 'Not signed in.');
      }
      // Supply id and skip .select() so PostgREST does not run INSERT … RETURNING.
      // Returning the row re-applies SELECT RLS (visibility helper + recursion).
      final id = const Uuid().v4();
      await _client.from('challenges').insert(<String, dynamic>{
        'id': id,
        'user_id': uid,
        'title': draft.title,
        'description': draft.description,
        'type': challengeTypeToSlug(draft.type).toUpperCase(),
        'audience': _audienceToSchema(draft.audience),
        'entry_fee': draft.entryFee.toDouble(),
        'max_participants': draft.maxParticipants,
        'winner_count': 3,
        'submit_due_date': draft.submissionDeadline.toUtc().toIso8601String(),
        'vote_start_date': draft.votingDeadline.toUtc().toIso8601String(),
        'vote_end_date': draft.endDate.toUtc().toIso8601String(),
        'prize_distribution': _buildPrizeDistributionJson(draft),
        'status': challengeStatusToSchema(draft.status),
        'is_active': draft.isActive,
      });
      return id;
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcAddCreatorParticipant(String challengeId) async {
    return;
  }

  @override
  Future<void> rpcJoinChallenge(String challengeId) async {
    try {
      await _client.rpc<void>(
        'join_challenge',
        params: <String, dynamic>{'_challenge_id': challengeId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcCompleteChallenge(String challengeId) async {
    try {
      await _client.from('challenges').update(<String, dynamic>{
        'status': 'ENDED',
      }).eq('id', challengeId);
      await _client.rpc<dynamic>(
        'calculate_challenge_rankings',
        params: {'_challenge_id': challengeId},
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    }
  }

  @override
  Future<void> rpcDeleteChallenge(String challengeId) async {
    try {
      await _client.from('challenges').delete().eq('id', challengeId);
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
      await _client.from('challenges').update(<String, dynamic>{
        'video_url': videoUrl,
        'video_storage_path': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'thumbnail_generated': thumbnailUrl != null && thumbnailUrl.isNotEmpty,
      }).eq('id', challengeId);
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
      if (!isCreatorVideo) {
        await rpcJoinChallenge(challengeId);
      }
      await _client.from('challenge_submissions').upsert(
        <String, dynamic>{
          'challenge_id': challengeId,
          'user_id': userId,
          'video_url': videoUrl,
          'video_storage_path': videoId.isEmpty ? videoUrl : videoId,
          'thumbnail_url': thumbnailUrl,
          'thumbnail_storage_path': thumbnailUrl,
          'thumbnail_generated': thumbnailUrl != null && thumbnailUrl.isNotEmpty,
          'status': 'PENDING',
        },
        onConflict: 'challenge_id,user_id',
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
      await _client.from('challenge_submissions').update(<String, dynamic>{
        'thumbnail_url': thumbnailUrl,
        'thumbnail_storage_path': thumbnailUrl,
        'thumbnail_generated': true,
      }).eq('challenge_id', challengeId).eq('user_id', userId);
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
      final uid = _uid;
      if (uid == null) {
        throw const ChallengeFailure(code: 'not-authenticated', message: 'Not signed in.');
      }
      final subRow = await _client
          .from('challenge_submissions')
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('user_id', submissionUserId)
          .maybeSingle();
      final submissionId = subRow?['id']?.toString();
      if (submissionId == null || submissionId.isEmpty) {
        throw const ChallengeFailure(code: 'submission-not-found', message: 'Submission not found.');
      }
      await _client.from('challenge_votes').upsert(
        <String, dynamic>{
          'challenge_id': challengeId,
          'submission_id': submissionId,
          'voter_id': uid,
          'rating': rating.round().clamp(1, 5),
        },
        onConflict: 'challenge_id,voter_id',
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
        .select('submission_id, rating')
        .eq('challenge_id', challengeId)
        .eq('voter_id', uid);
    final voteRows = List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final submissionIds = voteRows
        .map((e) => e['submission_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (submissionIds.isEmpty) return const <Map<String, dynamic>>[];
    final submissionRows = await _client
        .from('challenge_submissions')
        .select('id, user_id')
        .inFilter('id', submissionIds);
    final userBySubmissionId = <String, String>{};
    for (final raw in (submissionRows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final sid = row['id']?.toString() ?? '';
      final userId = row['user_id']?.toString() ?? '';
      if (sid.isNotEmpty && userId.isNotEmpty) {
        userBySubmissionId[sid] = userId;
      }
    }
    return voteRows
        .map((voteRow) {
          final sid = voteRow['submission_id']?.toString() ?? '';
          final userId = userBySubmissionId[sid];
          if (userId == null) return null;
          return <String, dynamic>{
            'submission_user_id': userId,
            'rating': voteRow['rating'],
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
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
        .asyncMap((raw) async {
          final rows = (raw as List).cast<Map>();
          final mine = rows.where((e) => e['voter_id']?.toString() == uid).toList();
          final submissionIds = mine
              .map((e) => e['submission_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          if (submissionIds.isEmpty) return <String, double>{};
          final submissionRows = await _client
              .from('challenge_submissions')
              .select('id, user_id')
              .inFilter('id', submissionIds);
          final userBySubmissionId = <String, String>{};
          for (final rawRow in (submissionRows as List)) {
            final row = Map<String, dynamic>.from(rawRow as Map);
            final sid = row['id']?.toString() ?? '';
            final sidUser = row['user_id']?.toString() ?? '';
            if (sid.isNotEmpty && sidUser.isNotEmpty) {
              userBySubmissionId[sid] = sidUser;
            }
          }
          final m = <String, double>{};
          for (final e in mine) {
            final submissionId = e['submission_id']?.toString() ?? '';
            final userId = userBySubmissionId[submissionId];
            if (userId == null || userId.isEmpty) continue;
            m[userId] = (e['rating'] as num?)?.toDouble() ?? 0.0;
          }
          return m;
        });
  }

  @override
  Future<bool> hasCelebrationAck(String challengeId) async {
    return false;
  }

  @override
  Future<void> ackCelebration(String challengeId) async {
    return;
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
            .from('friendships')
            .select('friend_id')
            .eq('user_id', creatorId);
        return (rows as List)
            .map((e) => (e as Map)['friend_id'].toString())
            .where((id) => id.isNotEmpty && id != creatorId)
            .toList();
      case ChallengeAudience.city:
        final rows = await _client
            .from('user_profiles')
            .select('id')
            .eq('city', city)
            .neq('id', creatorId)
            .limit(50);
        return (rows as List).map((e) => (e as Map)['id'].toString()).toList();
      case ChallengeAudience.country:
        final profile = await _client
            .from('user_profiles')
            .select('country')
            .eq('id', creatorId)
            .maybeSingle();
        final country = profile?['country']?.toString() ?? '';
        if (country.isEmpty) return const <String>[];
        final rows = await _client
            .from('user_profiles')
            .select('id')
            .eq('country', country)
            .neq('id', creatorId)
            .limit(100);
        return (rows as List).map((e) => (e as Map)['id'].toString()).toList();
      case ChallengeAudience.world:
        final rows =
            await _client.from('user_profiles').select('id').neq('id', creatorId).limit(200);
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
    if (msg.contains('challenge entry fee not paid')) {
      return const ChallengeFailure(
        code: 'entry-not-paid',
        message: 'Entry fee not paid.',
      );
    }
    if (msg.contains('challenge owner cannot join')) {
      return const ChallengeFailure(
        code: 'owner-cannot-join',
        message: 'Organizers use the creator flow.',
      );
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
