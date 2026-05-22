import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_auth.dart';
import '../../../../utils/city_catalog.dart';
import '../../../../core/supabase/coin_ledger.dart';
import '../../data/models/challenge.dart';

class ChallengeService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<Challenge>> fetchActiveChallenges() async {
    final rows = await _sb
        .from('challenges')
        .select('id, status')
        .neq('status', 'completed')
        .order('created_at', ascending: false);
    return _loadChallengesFromIdRows(rows as List<dynamic>);
  }

  Future<List<Challenge>> fetchChallengesByStatus(ChallengeStatus status) async {
    final rows = await _sb
        .from('challenges')
        .select('id')
        .eq('status', status.name)
        .order('created_at', ascending: false);
    return _loadChallengesFromIdRows(rows as List<dynamic>);
  }

  Future<List<Challenge>> fetchChallengesByCity(String city) async {
    final rows = await _sb
        .from('challenges')
        .select('id, status')
        .eq('city', city)
        .neq('status', 'completed')
        .order('created_at', ascending: false);
    return _loadChallengesFromIdRows(rows as List<dynamic>);
  }

  Future<List<Challenge>> fetchChallengesByType(ChallengeType type) async {
    final slug = challengeTypeToSlug(type);
    final rows = await _sb
        .from('challenges')
        .select('id')
        .eq('type', slug)
        .order('created_at', ascending: false);
    return _loadChallengesFromIdRows(rows as List<dynamic>);
  }

  /// List rows for challenge cards (participants/submissions aggregated in one fetch).
  Future<List<Map<String, dynamic>>> fetchChallengesForListUi({
    int limit = 50,
    String? onlyCreatorUserId,
  }) async {
    var query = _sb.from('challenges').select();
    if (onlyCreatorUserId != null && onlyCreatorUserId.isNotEmpty) {
      query = query.eq('creator_id', onlyCreatorUserId);
    }
    final challengeRows = await query
        .order('created_at', ascending: false)
        .limit(limit);
    final challenges = (challengeRows as List<dynamic>)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList(growable: false);
    if (challenges.isEmpty) return const [];

    final participantsRows = await _sb
        .from('challenge_participants')
        .select('challenge_id, user_id');
    final submissionsRows = await _sb
        .from('challenge_submissions')
        .select('challenge_id, user_id');

    final participantsByChallenge = groupUserIdsByChallengeIdFromJoinRows(
      (participantsRows as List<dynamic>)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList(growable: false),
      userIdKey: 'user_id',
    );
    final submissionsByChallenge = groupUserIdsByChallengeIdFromJoinRows(
      (submissionsRows as List<dynamic>)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList(growable: false),
      userIdKey: 'user_id',
    );

    return challenges
        .map(
          (row) => mapChallengeRowForListUi(
            row,
            participantsByChallenge: participantsByChallenge,
            submissionsByChallenge: submissionsByChallenge,
          ),
        )
        .toList(growable: false);
  }

  Future<List<Challenge>> _loadChallengesFromIdRows(List<dynamic> rows) async {
    final out = <Challenge>[];
    for (final raw in rows) {
      final id = (raw as Map<String, dynamic>)['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final c = await _loadChallenge(id);
      if (c != null) out.add(c);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<Challenge?> getChallenge(String challengeId) async {
    try {
      return await _loadChallenge(challengeId);
    } catch (e) {
      print('Error getting challenge: $e');
      return null;
    }
  }

  Future<String?> createChallenge(Challenge challenge) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }

      final allowed = await _canCreateBySubscription(currentUser.id);
      if (!allowed) {
        throw Exception(tr('challenge_error_monthly_limit'));
      }

      final entryFee = challenge.entryFee;
      final coins = await coinBalance(_sb, currentUser.id);
      if (coins < entryFee) {
        throw Exception(tr('challenge_error_insufficient_coins_create'));
      }
      if (entryFee > 0) {
        await insertCoinTransaction(
          _sb,
          currentUser.id,
          'challenge_create_fee',
          -entryFee,
          tr('coin_ledger_challenge_create_fee', namedArgs: {'title': challenge.title}),
        );
      }

      final audienceId = await _resolveChallengeAudienceId(challenge.audience);
      final desc = challenge.description.trim();

      final inserted = await _sb
          .from('challenges')
          .insert(<String, dynamic>{
            'creator_id': currentUser.id,
            'title': challenge.title,
            if (desc.isNotEmpty) 'description': desc,
            'type': challengeTypeToSlug(challenge.type),
            'audience_id': audienceId,
            'city': CityCatalog.toEnglishStorageKey(challenge.city) ?? challenge.city,
            'entry_fee': entryFee,
            'max_participants': challenge.maxParticipants,
            'status': challenge.status.name,
            'starts_at': challenge.startDate.toUtc().toIso8601String(),
            'submission_deadline':
                challenge.submissionDeadline.toUtc().toIso8601String(),
            'voting_deadline':
                challenge.votingDeadline.toUtc().toIso8601String(),
            'ends_at': challenge.endDate.toUtc().toIso8601String(),
            'image_url': challenge.imageUrl,
          })
          .select('id')
          .single();
      final challengeId = inserted['id'].toString();

      await _sb.from('challenge_participants').insert(<String, dynamic>{
        'challenge_id': challengeId,
        'user_id': currentUser.id,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _sendChallengeInvitations(challengeId, challenge);
      return challengeId;
    } catch (e) {
      print('Error creating challenge: $e');
      rethrow;
    }
  }

  Future<bool> joinChallenge(String challengeId) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }
      final challenge = await _loadChallenge(challengeId);
      if (challenge == null) throw Exception(tr('challenge_error_not_found'));
      if (!challenge.canJoin) throw Exception(tr('challenge_error_cannot_join'));
      if (challenge.participants.contains(currentUser.id)) {
        throw Exception(tr('challenge_error_already_participant'));
      }

      final coins = await coinBalance(_sb, currentUser.id);
      if (coins < challenge.entryFee) {
        throw Exception(
          tr(
            'challenge_error_join_insufficient_coins',
            namedArgs: {
              'required': '${challenge.entryFee}',
              'balance': '$coins',
            },
          ),
        );
      }

      await _sb.from('challenge_participants').upsert(<String, dynamic>{
        'challenge_id': challengeId,
        'user_id': currentUser.id,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (challenge.entryFee > 0) {
        await insertCoinTransaction(
          _sb,
          currentUser.id,
          'challenge_entry_fee',
          -challenge.entryFee,
          tr('coin_ledger_challenge_entry_fee', namedArgs: {'title': challenge.title}),
        );
      }
      return true;
    } catch (e) {
      print('Error joining challenge: $e');
      rethrow;
    }
  }

  Future<bool> submitVideo(String challengeId, String videoUrl) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }
      final challenge = await _loadChallenge(challengeId);
      if (challenge == null) throw Exception(tr('challenge_error_not_found'));
      if (!challenge.canSubmit) {
        throw Exception(tr('challenge_error_cannot_submit_video'));
      }
      if (!challenge.participants.contains(currentUser.id)) {
        throw Exception(tr('challenge_error_not_participant'));
      }
      if (challenge.submissions.contains(currentUser.id)) {
        throw Exception(tr('challenge_error_already_submitted_video'));
      }

      final subDesc = challenge.description.trim();
      await _sb.from('challenge_submissions').upsert(
        <String, dynamic>{
          'challenge_id': challengeId,
          'user_id': currentUser.id,
          'video_url': videoUrl,
          'title': challenge.title,
          if (subDesc.isNotEmpty) 'description': subDesc,
          'thumbnail_url': null,
        },
        onConflict: 'challenge_id,user_id',
      );

      final creatorId = challenge.creatorId;
      if (creatorId.isNotEmpty && creatorId != currentUser.id) {
        // Backend trigger handles challenge submission notifications.
      }
      return true;
    } catch (e) {
      print('Error submitting video: $e');
      rethrow;
    }
  }

  Future<bool> voteForVideo(
    String challengeId,
    String userId,
    Map<String, double> criteria,
  ) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }
      if (currentUser.id == userId) throw Exception(tr('challenge_error_cannot_vote_self'));

      final challenge = await _loadChallenge(challengeId);
      if (challenge == null) throw Exception(tr('challenge_error_not_found'));
      if (!challenge.canVote) throw Exception(tr('challenge_error_voting_not_open'));
      if (challenge.votes.containsKey(currentUser.id)) {
        throw Exception(tr('challenge_error_already_voted'));
      }

      final submission = await _sb
          .from('challenge_submissions')
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .maybeSingle();
      if (submission == null) throw Exception(tr('challenge_error_submission_not_found'));

      final totalRating = ((criteria['technical'] ?? 0) * 0.4 +
              (criteria['creativity'] ?? 0) * 0.3 +
              (criteria['difficulty'] ?? 0) * 0.2 +
              (criteria['quality'] ?? 0) * 0.1) *
          2.0;

      await _sb.from('challenge_submission_ratings').insert(<String, dynamic>{
        'challenge_submission_id': submission['id'],
        'voter_user_id': currentUser.id,
        'overall_rating': totalRating.clamp(0, 10),
      });

      await insertCoinTransaction(
        _sb,
        currentUser.id,
        'voting_reward',
        1,
        tr('il_e461fc9a2d'),
      );
      return true;
    } catch (e) {
      print('Error voting for video: $e');
      rethrow;
    }
  }

  Future<bool> completeChallenge(String challengeId) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }
      final challenge = await _loadChallenge(challengeId);
      if (challenge == null) throw Exception(tr('challenge_error_not_found'));
      if (challenge.creatorId != currentUser.id) {
        throw Exception(tr('challenge_error_only_creator_complete'));
      }
      if (challenge.status == ChallengeStatus.completed) {
        throw Exception(tr('challenge_error_already_completed'));
      }

      final result = await _finalizeChallenge(challenge);
      await _notifyParticipantsAboutCompletion(challenge, result);
      return true;
    } catch (e) {
      print('Error completing challenge: $e');
      rethrow;
    }
  }

  Future<List<Challenge>> fetchUserChallenges(String userId) async {
    final rows = await _sb
        .from('challenge_participants')
        .select('challenge_id')
        .eq('user_id', userId);
    final ids = (rows as List<dynamic>)
        .map((raw) => (raw as Map<String, dynamic>)['challenge_id'].toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final out = <Challenge>[];
    for (final id in ids) {
      final c = await _loadChallenge(id);
      if (c != null) out.add(c);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<List<Challenge>> fetchCreatedChallenges(String userId) async {
    final rows = await _sb
        .from('challenges')
        .select('id')
        .eq('creator_id', userId)
        .order('created_at', ascending: false);
    return _loadChallengesFromIdRows(rows as List<dynamic>);
  }

  Future<bool> deleteChallenge(String challengeId) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }
      final challenge = await _loadChallenge(challengeId);
      if (challenge == null) throw Exception(tr('challenge_error_not_found'));
      if (challenge.creatorId != currentUser.id) {
        throw Exception(tr('challenge_error_only_creator_delete'));
      }
      await _sb.from('challenges').delete().eq('id', challengeId);
      return true;
    } catch (e) {
      print('Error deleting challenge: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getChallengeStats() async {
    try {
      final rows = await _sb.from('challenges').select('id, status');
      final list = rows as List<dynamic>;
      final total = list.length;
      final completed = list
          .where((r) => (r as Map<String, dynamic>)['status'] == 'completed')
          .length;
      final active = total - completed;
      return {'total': total, 'active': active, 'completed': completed};
    } catch (e) {
      print('Error getting challenge stats: $e');
      return {'total': 0, 'active': 0, 'completed': 0};
    }
  }

  Future<bool> addVideoToChallenge(String challengeId, String userId) async {
    try {
      final challenge = await _loadChallenge(challengeId);
      if (challenge == null) throw Exception(tr('challenge_error_not_found'));
      if (challenge.status == ChallengeStatus.completed) {
        throw Exception(tr('challenge_error_challenge_inactive_no_video'));
      }

      try {
        await _sb.from('challenge_participants').upsert(<String, dynamic>{
          'challenge_id': challengeId,
          'user_id': userId,
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        });
      } on PostgrestException catch (e) {
        // Some deployments restrict direct writes to participants via RLS.
        // Continue with submission upsert, which is sufficient for upload flow.
        final detailsText = e.details?.toString() ?? '';
        final isParticipantRls = e.code == '42501' &&
            (e.message.contains('challenge_participants') ||
                detailsText.contains('challenge_participants'));
        if (!isParticipantRls) {
          rethrow;
        }
      }

      final addDesc = challenge.description.trim();
      await _sb.from('challenge_submissions').upsert(
        <String, dynamic>{
          'challenge_id': challengeId,
          'user_id': userId,
          'title': challenge.title,
          if (addDesc.isNotEmpty) 'description': addDesc,
        },
        onConflict: 'challenge_id,user_id',
      );
      return true;
    } catch (e) {
      print('Error adding video to challenge: $e');
      rethrow;
    }
  }

  Future<void> _sendChallengeInvitations(
    String challengeId,
    Challenge challenge,
  ) async {
    try {
      final targetUserIds = <String>{};

      switch (challenge.audience) {
        case ChallengeAudience.friends:
          final f1 = await _sb
              .from('friendships')
              .select('friend_user_id')
              .eq('user_id', challenge.creatorId);
          for (final raw in f1 as List<dynamic>) {
            targetUserIds.add((raw as Map<String, dynamic>)['friend_user_id'].toString());
          }
          break;
        case ChallengeAudience.city:
          final cityUsers = await _sb
              .from('profiles')
              .select('id')
              .eq('city', challenge.city)
              .limit(50);
          for (final raw in cityUsers as List<dynamic>) {
            targetUserIds.add((raw as Map<String, dynamic>)['id'].toString());
          }
          break;
        case ChallengeAudience.country:
          final countryUsers = await _sb
              .from('profiles')
              .select('id')
              .eq('country', 'Ukraine')
              .limit(100);
          for (final raw in countryUsers as List<dynamic>) {
            targetUserIds.add((raw as Map<String, dynamic>)['id'].toString());
          }
          break;
        case ChallengeAudience.world:
          final worldUsers = await _sb.from('profiles').select('id').limit(200);
          for (final raw in worldUsers as List<dynamic>) {
            targetUserIds.add((raw as Map<String, dynamic>)['id'].toString());
          }
          break;
      }

      targetUserIds.remove(challenge.creatorId);
      if (targetUserIds.isEmpty) return;

      // Backend trigger handles challenge invitation notifications.
    } catch (e) {
      print('Error sending challenge invitations: $e');
    }
  }

  Future<void> checkAndFinishChallenges() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _sb
          .from('challenges')
          .select('id')
          .neq('status', 'completed')
          .lte('ends_at', now)
          .limit(25);

      for (final raw in rows as List<dynamic>) {
        final id = (raw as Map<String, dynamic>)['id'].toString();
        final challenge = await _loadChallenge(id);
        if (challenge == null) continue;
        await _finishChallenge(challenge);
      }
    } catch (e) {
      print('Error checking and finishing challenges: $e');
    }
  }

  Future<void> _finishChallenge(Challenge challenge) async {
    try {
      final result = await _finalizeChallenge(challenge);
      await _notifyParticipantsAboutCompletion(challenge, result);
      print('Challenge ${challenge.id} finished successfully');
    } catch (e) {
      print('Error finishing challenge: $e');
    }
  }

  Future<void> deleteOldFinishedChallenges() async {
    try {
      final twoDaysAgo =
          DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String();
      final rows = await _sb
          .from('challenges')
          .select('id')
          .eq('status', 'completed')
          .lte('updated_at', twoDaysAgo);
      for (final raw in rows as List<dynamic>) {
        final id = (raw as Map<String, dynamic>)['id'].toString();
        await _sb.from('challenges').delete().eq('id', id);
      }
    } catch (e) {
      print('Error deleting old challenges: $e');
    }
  }

  Future<_ChallengeWinnersPayload> _finalizeChallenge(Challenge challenge) async {
    final submissions = await _sb
        .from('challenge_submissions')
        .select('id, user_id')
        .eq('challenge_id', challenge.id);

    final scored = <({String userId, double score})>[];
    for (final raw in submissions as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final sid = row['id'].toString();
      final uid = row['user_id'].toString();
      final ratings = await _sb
          .from('challenge_submission_ratings')
          .select('overall_rating')
          .eq('challenge_submission_id', sid);
      double avg = 0;
      final list = ratings as List<dynamic>;
      if (list.isNotEmpty) {
        final sum = list.fold<double>(
          0,
          (p, e) => p + ((e as Map<String, dynamic>)['overall_rating'] as num).toDouble(),
        );
        avg = sum / list.length;
      }
      scored.add((userId: uid, score: avg));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final winners = <String>[];
    final finalScores = <String, double>{};
    final winnerPrizes = <String, int>{};
    final prizePool = _effectivePrizePool(challenge);
    final prizes = _prizeBreakdown(prizePool);

    for (int i = 0; i < scored.length && i < 3; i++) {
      final winnerId = scored[i].userId;
      final score = scored[i].score;
      final prize = prizes[i];
      winners.add(winnerId);
      finalScores[winnerId] = score;
      winnerPrizes[winnerId] = prize;

      await _sb.from('challenge_prize_places').upsert(<String, dynamic>{
        'challenge_id': challenge.id,
        'place': i + 1,
        'prize_amount': prize,
        'winner_user_id': winnerId,
      });

      if (prize > 0) {
        await insertCoinTransaction(
          _sb,
          winnerId,
          'challenge_prize',
          prize,
          'Prize for place ${i + 1} in "${challenge.title}"',
        );
      }
      // Backend trigger handles challenge result notifications.
    }

    await _sb.from('challenges').update(<String, dynamic>{
      'status': ChallengeStatus.completed.name,
    }).eq('id', challenge.id);
    await _sb.from('challenge_completions').upsert(<String, dynamic>{
      'challenge_id': challenge.id,
      'completed_by': AppAuth.currentUserId,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });

    return _ChallengeWinnersPayload(
      winners: winners,
      finalScores: finalScores,
      winnerPrizes: winnerPrizes,
    );
  }

  Future<void> _notifyParticipantsAboutCompletion(
    Challenge challenge,
    _ChallengeWinnersPayload result,
  ) async {
    final winnersSet = result.winnersSet;
    for (final participantId in challenge.participants.toSet()) {
      if (participantId.isEmpty || winnersSet.contains(participantId)) {
        continue;
      }
      // Backend trigger handles challenge completion notifications.
    }
  }

  /// Always recomputes from the live participant count instead of trusting
  /// any value carried on the entity. This avoids a class of bugs where a
  /// stale [Challenge.prizePool] (e.g. from the create-screen preview)
  /// would override the real entry-fee pot at finalization time.
  double _effectivePrizePool(Challenge challenge) {
    final participantCount = challenge.participants.isNotEmpty
        ? challenge.participants.length
        : challenge.currentParticipants;
    return computeChallengePrizePoolCoins(
      participantCount: participantCount,
      entryFee: challenge.entryFee,
    ).toDouble();
  }

  List<int> _prizeBreakdown(double prizePool) {
    final total = prizePool.round();
    if (total <= 0) {
      return [0, 0, 0];
    }
    final first = (total * 0.5).round();
    final second = (total * 0.3).round();
    final remaining = total - first - second;
    final third = remaining < 0 ? 0 : remaining;
    return [first, second, third];
  }

  Future<Challenge?> _loadChallenge(String challengeId) async {
    if (challengeId.isEmpty) return null;
    final row = await _sb
        .from('challenges')
        .select('*, challenge_audiences(code)')
        .eq('id', challengeId)
        .maybeSingle();
    if (row == null) return null;

    final participantsRows = await _sb
        .from('challenge_participants')
        .select('user_id')
        .eq('challenge_id', challengeId);
    final submissionsRows = await _sb
        .from('challenge_submissions')
        .select('user_id')
        .eq('challenge_id', challengeId);

    final participants = (participantsRows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['user_id'].toString())
        .toList(growable: false);
    final submissions = (submissionsRows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['user_id'].toString())
        .toList(growable: false);

    final creator = await _sb
        .from('profiles')
        .select('display_name,nickname')
        .eq('id', row['creator_id'])
        .maybeSingle();
    final creatorName =
        (creator?['display_name'] ?? creator?['nickname'] ?? '').toString();

    final typeCode = (row['type'] ?? 'other').toString();
    final audienceCode =
        ((row['challenge_audiences'] as Map<String, dynamic>?)?['code'] ?? 'city')
            .toString();

    final prizeRows = await _sb
        .from('challenge_prize_places')
        .select('winner_user_id, prize_amount')
        .eq('challenge_id', challengeId);
    final winnerPrizes = <String, int>{};
    for (final raw in prizeRows as List<dynamic>) {
      final r = raw as Map<String, dynamic>;
      final uid = (r['winner_user_id'] ?? '').toString();
      if (uid.isEmpty) continue;
      winnerPrizes[uid] = ((r['prize_amount'] as num?)?.toDouble() ?? 0).round();
    }

    final startDate = _parseDate(row['starts_at']);
    final endDate = _parseDate(row['ends_at']);

    return Challenge(
      id: challengeId,
      title: (row['title'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      type: parseChallengeType(typeCode),
      audience: ChallengeAudience.values.firstWhere(
        (e) => e.name == audienceCode,
        orElse: () => ChallengeAudience.city,
      ),
      creatorId: (row['creator_id'] ?? '').toString(),
      creatorName: creatorName,
      creatorVideoUrl: _nonEmptyOrNull(
        (row['video_url'] ?? row['creator_video_url'])?.toString() ?? '',
      ),
      city: (row['city'] ?? '').toString(),
      entryFee: (row['entry_fee'] as num?)?.toInt() ?? 0,
      duration: challengeDurationDaysFromSpan(startDate, endDate),
      createdAt: _parseDate(row['created_at']),
      startDate: startDate,
      submissionDeadline: _parseDate(row['submission_deadline']),
      votingDeadline: _parseDate(row['voting_deadline']),
      endDate: endDate,
      status: _statusFromString((row['status'] ?? 'recruiting').toString()),
      maxParticipants: (row['max_participants'] as num?)?.toInt() ?? 50,
      currentParticipants: participants.length,
      // Canonical prize-pool formula keeps cards, detail page, and the
      // finalization payout in lock-step.
      prizePool: computeChallengePrizePoolCoins(
        participantCount: participants.length,
        entryFee: (row['entry_fee'] as num?)?.toInt() ?? 0,
      ).toDouble(),
      participants: participants,
      submissions: submissions,
      votes: const <String, double>{},
      detailedVotes: const <String, Map<String, double>>{},
      winners: winnerPrizes.keys.toList(growable: false),
      finalScores: const <String, double>{},
      winnerPrizes: winnerPrizes,
      isActive: (row['status'] ?? '').toString() != 'completed',
      imageUrl: row['image_url']?.toString(),
      tags: const <String>[],
    );
  }

  Future<bool> _canCreateBySubscription(String userId) async {
    final planRow = await _sb
        .from('subscriptions')
        .select('subscription_plans(code)')
        .eq('user_id', userId)
        .inFilter('status', ['trial', 'active'])
        .order('starts_at', ascending: false)
        .limit(1)
        .maybeSingle();

    var limit = 1;
    if (planRow != null) {
      final code = ((planRow['subscription_plans'] as Map<String, dynamic>?)?['code'] ??
              'free')
          .toString();
      if (code == 'champions' || code == 'champions_league') {
        return true;
      }
      if (code == 'europa') {
        limit = 5;
      }
    }

    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1)
        .toUtc()
        .toIso8601String();
    final rows = await _sb
        .from('challenges')
        .select('id')
        .eq('creator_id', userId)
        .gte('created_at', monthStart);
    return (rows as List<dynamic>).length < limit;
  }

  Future<String?> _resolveChallengeAudienceId(ChallengeAudience audience) async {
    final row = await _sb
        .from('challenge_audiences')
        .select('id')
        .eq('code', audience.name)
        .maybeSingle();
    return row?['id']?.toString();
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse((value ?? '').toString());
    return parsed ?? DateTime.now();
  }

  ChallengeStatus _statusFromString(String value) {
    final normalized = value == 'finished' ? 'completed' : value;
    return ChallengeStatus.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () => ChallengeStatus.recruiting,
    );
  }

  String? _nonEmptyOrNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}

class _ChallengeWinnersPayload {
  const _ChallengeWinnersPayload({
    required this.winners,
    required this.finalScores,
    required this.winnerPrizes,
  });

  final List<String> winners;
  final Map<String, double> finalScores;
  final Map<String, int> winnerPrizes;

  Set<String> get winnersSet => winners.toSet();
}
