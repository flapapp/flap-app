import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/coin_ledger.dart';
import '../../../../core/di/injection.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../data/models/submission.dart';
import 'package:flap_app/core/auth/app_auth.dart';

class SubmissionService {
  final SupabaseClient _sb = Supabase.instance.client;
  final NotificationService _notificationService;

  SubmissionService({NotificationService? notificationService})
    : _notificationService = notificationService ?? sl<NotificationService>();

  Stream<List<Submission>> getChallengeSubmissions(String challengeId) {
    return _sb
        .from('challenge_submissions')
        .stream(primaryKey: ['id'])
        .order('submitted_at', ascending: false)
        .asyncMap((rows) async {
          final filtered = rows
              .where((r) => (r['challenge_id'] ?? '').toString() == challengeId)
              .toList(growable: false);
          final out = <Submission>[];
          for (final row in filtered) {
            out.add(await _toSubmissionWithRatings(row));
          }
          return out.where((s) => s.isActive).toList(growable: false);
        });
  }

  Stream<List<Submission>> getUserSubmissions(String userId) {
    return _sb
        .from('challenge_submissions')
        .stream(primaryKey: ['id'])
        .order('submitted_at', ascending: false)
        .asyncMap((rows) async {
          final filtered = rows
              .where((r) => (r['user_id'] ?? '').toString() == userId)
              .toList(growable: false);
          final out = <Submission>[];
          for (final row in filtered) {
            out.add(await _toSubmissionWithRatings(row));
          }
          return out.where((s) => s.isActive).toList(growable: false);
        });
  }

  Future<String?> submitVideoToChallenge({
    required String challengeId,
    required String videoUrl,
    String? thumbnailUrl,
    required String title,
    String? description,
  }) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      throw Exception(tr('submission_error_not_signed_in'));
    }

    final profile = await _sb
        .from('profiles')
        .select('display_name, avatar_url')
        .eq('id', currentUser.id)
        .maybeSingle();
    if (profile == null) {
      throw Exception(tr('submission_error_user_not_found'));
    }

    final existing = await _sb
        .from('challenge_submissions')
        .select('id')
        .eq('challenge_id', challengeId)
        .eq('user_id', currentUser.id)
        .limit(1);
    if ((existing as List<dynamic>).isNotEmpty) {
      throw Exception(tr('submission_error_already_submitted'));
    }

    final d = description?.trim() ?? '';
    final inserted = await _sb
        .from('challenge_submissions')
        .insert(<String, dynamic>{
          'challenge_id': challengeId,
          'user_id': currentUser.id,
          'video_url': videoUrl,
          'thumbnail_url': thumbnailUrl,
          'title': title,
          if (d.isNotEmpty) 'description': d,
        })
        .select('id')
        .single();
    final submissionId = inserted['id'].toString();

    await insertCoinTransaction(
      _sb,
      currentUser.id,
      'challenge_submission',
      20,
      tr('coin_ledger_challenge_entry', namedArgs: {'title': title}),
    );

    return submissionId;
  }

  Future<bool> voteForSubmission(String submissionId, double rating) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      throw Exception(tr('submission_error_not_signed_in'));
    }
    if (rating < 0.0 || rating > 5.0) {
      throw Exception(tr('submission_error_rating_range'));
    }

    final row = await _sb
        .from('challenge_submissions')
        .select('id, challenge_id, user_id, title')
        .eq('id', submissionId)
        .maybeSingle();
    if (row == null) {
      throw Exception(tr('submission_error_video_not_found'));
    }
    final ownerId = (row['user_id'] ?? '').toString();
    if (ownerId == currentUser.id) {
      throw Exception(tr('submission_error_cannot_vote_own'));
    }

    await _sb.from('challenge_submission_ratings').upsert(<String, dynamic>{
      'challenge_submission_id': submissionId,
      'voter_user_id': currentUser.id,
      'overall_rating': rating,
    });

    final voter = await _sb
        .from('profiles')
        .select('display_name, nickname')
        .eq('id', currentUser.id)
        .maybeSingle();
    final voterName = (voter?['display_name'] ?? voter?['nickname'] ?? tr('anonymous_user')).toString();
   

    await _notificationService.sendVideoVoteNotification(
      toUserId: ownerId,
      videoTitle: ((row['title'] ?? tr('video_your_video_fallback'))).toString(),
      voterName: voterName,
      rating: rating,
    );
    return true;
  }

  Future<Submission?> getSubmission(String submissionId) async {
    try {
      final row = await _sb
          .from('challenge_submissions')
          .select()
          .eq('id', submissionId)
          .maybeSingle();
      if (row == null) return null;
      return _toSubmissionWithRatings(row);
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteSubmission(String submissionId) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      throw Exception(tr('submission_error_not_signed_in'));
    }
    final row = await _sb
        .from('challenge_submissions')
        .select('id, user_id')
        .eq('id', submissionId)
        .maybeSingle();
    if (row == null) {
      throw Exception(tr('submission_error_video_not_found'));
    }
    if ((row['user_id'] ?? '').toString() != currentUser.id) {
      throw Exception(tr('submission_error_delete_own_only'));
    }
    await _sb.from('challenge_submissions').delete().eq('id', submissionId);
    return true;
  }

  Future<Map<String, dynamic>> getSubmissionStats(String submissionId) async {
    final submission = await getSubmission(submissionId);
    if (submission == null) return <String, dynamic>{};
    return <String, dynamic>{
      'submissionId': submissionId,
      'averageRating': submission.averageRating,
      'totalVotes': submission.totalVotes,
      'ratingDistribution': _calculateRatingDistribution(submission.votes),
    };
  }

  Map<String, int> _calculateRatingDistribution(Map<String, double> votes) {
    final distribution = <String, int>{
      '5': 0,
      '4': 0,
      '3': 0,
      '2': 0,
      '1': 0,
      '0': 0,
    };
    for (final rating in votes.values) {
      final rounded = rating.round().toString();
      distribution[rounded] = (distribution[rounded] ?? 0) + 1;
    }
    return distribution;
  }

  Future<bool> awardVotingCoins(String challengeId, String userId) async {
    try {
      final submissions = await _sb
          .from('challenge_submissions')
          .select('id')
          .eq('challenge_id', challengeId);
      final ids = (submissions as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['id'].toString())
          .toList(growable: false);
      if (ids.isEmpty) return false;

      final votes = await _sb
          .from('challenge_submission_ratings')
          .select('challenge_submission_id')
          .eq('voter_user_id', userId)
          .inFilter('challenge_submission_id', ids);
      final voted = (votes as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['challenge_submission_id'].toString())
          .toSet();

      if (voted.length != ids.length) return false;
      await insertCoinTransaction(
        _sb,
        userId,
        'challenge_voting_complete',
        5,
        tr('il_e9f698ce68'),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> rateSubmission(
    String submissionId,
    double rating,
    String userId,
  ) async {
    await _sb.from('challenge_submission_ratings').upsert(<String, dynamic>{
      'challenge_submission_id': submissionId,
      'voter_user_id': userId,
      'overall_rating': rating,
    });
  }

  Future<Submission> _toSubmissionWithRatings(Map<String, dynamic> row) async {
    final submissionId = (row['id'] ?? '').toString();
    final ratings = await _sb
        .from('challenge_submission_ratings')
        .select('voter_user_id, overall_rating')
        .eq('challenge_submission_id', submissionId);
    final votes = <String, double>{};
    for (final raw in ratings as List<dynamic>) {
      final r = raw as Map<String, dynamic>;
      votes[(r['voter_user_id'] ?? '').toString()] =
          ((r['overall_rating'] as num?) ?? 0).toDouble();
    }
    final totalVotes = votes.length;
    final avg = totalVotes == 0
        ? 0.0
        : votes.values.reduce((a, b) => a + b) / totalVotes;

    return Submission(
      id: submissionId,
      challengeId: (row['challenge_id'] ?? '').toString(),
      userId: (row['user_id'] ?? '').toString(),
      userName: (row['user_name'] ?? '').toString(),
      userAvatar: (row['user_avatar'] ?? '').toString(),
      videoUrl: (row['video_url'] ?? '').toString(),
      thumbnailUrl: row['thumbnail_url']?.toString(),
      title: (row['title'] ?? '').toString(),
      description: row['description']?.toString(),
      submittedAt:
          DateTime.tryParse((row['submitted_at'] ?? '').toString()) ??
          DateTime.now(),
      votes: votes,
      averageRating: avg,
      totalVotes: totalVotes,
    );
  }
}
