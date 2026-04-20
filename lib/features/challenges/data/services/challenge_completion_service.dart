import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/coin_ledger.dart';
import 'package:flap_app/app_locale_access.dart';

class ChallengeCompletionService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<void> completeChallengeAndDistributePrizes(String challengeId) async {
    try {
      final challenge = await _sb
          .from('challenges')
          .select('id, entry_fee')
          .eq('id', challengeId)
          .maybeSingle();
      if (challenge == null) return;

      final submissionRows = await _sb
          .from('challenge_submissions')
          .select('id, user_id')
          .eq('challenge_id', challengeId);
      final submissions = submissionRows as List<dynamic>;

      if (submissions.length < 2) {
        await _refundChallenge(challengeId, (challenge['entry_fee'] as num?)?.toInt() ?? 0);
        return;
      }

      final scored = <Map<String, dynamic>>[];
      for (final raw in submissions) {
        final s = raw as Map<String, dynamic>;
        final ratings = await _sb
            .from('challenge_submission_ratings')
            .select('overall_rating')
            .eq('challenge_submission_id', s['id']);
        final values = <double>[];
        for (final r in ratings as List<dynamic>) {
          values.add(((r as Map<String, dynamic>)['overall_rating'] as num).toDouble());
        }
        final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
        scored.add(<String, dynamic>{
          'submission_id': s['id'].toString(),
          'user_id': s['user_id'].toString(),
          'avg': avg,
        });
      }
      scored.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));

      var prizePool = 0;
      for (final _ in await _sb
          .from('challenge_participants')
          .select('user_id')
          .eq('challenge_id', challengeId) as List<dynamic>) {
        prizePool += (challenge['entry_fee'] as num?)?.toInt() ?? 0;
      }
      final prizes = <int>[
        (prizePool * 0.5).round(),
        (prizePool * 0.3).round(),
        (prizePool * 0.2).round(),
      ];

      for (var i = 0; i < scored.length && i < 3; i++) {
        final winnerId = scored[i]['user_id'].toString();
        final amount = i < prizes.length ? prizes[i] : 0;
        await _sb.from('challenge_prize_places').upsert(<String, dynamic>{
          'challenge_id': challengeId,
          'place': i + 1,
          'prize_amount': amount,
          'winner_user_id': winnerId,
        });
        if (amount > 0) {
          await insertCoinTransaction(
            _sb,
            winnerId,
            'challenge_prize',
            amount,
            bilingual(
              'Приз за ${i + 1}-е місце в челенджі: $amount монет',
              'Prize for ${i + 1} place in the challenge: $amount coins',
            ),
          );
        }
      }

      await _sb.from('challenges').update(<String, dynamic>{
        'status': 'completed',
        'ends_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', challengeId);
      await _sb.from('challenge_completions').upsert(<String, dynamic>{
        'challenge_id': challengeId,
        'completed_by': null,
      });
    } catch (e) {
      print('Error completing challenge: $e');
    }
  }

  Future<void> _refundChallenge(String challengeId, int entryFee) async {
    try {
      final participants = await _sb
          .from('challenge_participants')
          .select('user_id')
          .eq('challenge_id', challengeId);
      for (final raw in participants as List<dynamic>) {
        final uid = (raw as Map<String, dynamic>)['user_id'].toString();
        await insertCoinTransaction(
          _sb,
          uid,
          'challenge_refund',
          entryFee,
          tr('il_a81f02726f'),
        );
      }
      await _sb.from('challenges').update(<String, dynamic>{
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        'cancellation_reason': 'Недостатньо учасників',
      }).eq('id', challengeId);
    } catch (e) {
      print('Error refunding challenge: $e');
    }
  }

  Future<void> checkAndCompleteExpiredChallenges() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _sb
          .from('challenges')
          .select('id')
          .inFilter('status', <String>['voting', 'submission'])
          .lte('ends_at', now)
          .limit(10);
      for (final raw in rows as List<dynamic>) {
        final id = (raw as Map<String, dynamic>)['id'].toString();
        if (id.isEmpty) continue;
        await completeChallengeAndDistributePrizes(id);
      }
    } catch (e) {
      print('Error checking expired challenges: $e');
    }
  }
}
