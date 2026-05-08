import 'package:flutter_test/flutter_test.dart';

import 'package:flap_app/features/challenges/data/models/challenge.dart';

void main() {
  group('computeChallengePrizePoolCoins', () {
    test('multiplies participant count by entry fee', () {
      expect(
        computeChallengePrizePoolCoins(participantCount: 5, entryFee: 10),
        50,
      );
    });

    test('returns 0 when no participants joined yet', () {
      expect(
        computeChallengePrizePoolCoins(participantCount: 0, entryFee: 10),
        0,
      );
    });

    test('returns 0 when entry fee is 0 (free challenge)', () {
      expect(
        computeChallengePrizePoolCoins(participantCount: 5, entryFee: 0),
        0,
      );
    });

    test('clamps negative inputs to 0 instead of throwing', () {
      expect(
        computeChallengePrizePoolCoins(participantCount: -1, entryFee: 10),
        0,
      );
      expect(
        computeChallengePrizePoolCoins(participantCount: 5, entryFee: -1),
        0,
      );
    });

    test('handles large but plausible values without overflow', () {
      // 1000 players × 1000 coins still fits comfortably in a 32-bit int.
      expect(
        computeChallengePrizePoolCoins(
          participantCount: 1000,
          entryFee: 1000,
        ),
        1000000,
      );
    });
  });

  group('computeChallengeMaxPrizePoolCoins', () {
    test('returns max participants × entry fee', () {
      expect(
        computeChallengeMaxPrizePoolCoins(
          maxParticipants: 100,
          entryFee: 5,
        ),
        500,
      );
    });

    test('returns 0 for non-positive inputs', () {
      expect(
        computeChallengeMaxPrizePoolCoins(
          maxParticipants: 0,
          entryFee: 10,
        ),
        0,
      );
      expect(
        computeChallengeMaxPrizePoolCoins(
          maxParticipants: 100,
          entryFee: 0,
        ),
        0,
      );
    });
  });

  group('groupUserIdsByChallengeIdFromJoinRows', () {
    test('groups challenge_participants rows by challenge_id', () {
      final rows = <Map<String, dynamic>>[
        {'challenge_id': 'c1', 'user_id': 'u1'},
        {'challenge_id': 'c1', 'user_id': 'u2'},
        {'challenge_id': 'c2', 'user_id': 'u3'},
      ];
      final m = groupUserIdsByChallengeIdFromJoinRows(
        rows,
        userIdKey: 'user_id',
      );
      expect(m['c1'], ['u1', 'u2']);
      expect(m['c2'], ['u3']);
    });
  });

  group('mapChallengeRowForListUi', () {
    test('uses join-table counts, not phantom challenge columns', () {
      final row = <String, dynamic>{
        'id': 'cid',
        'entry_fee': 10,
        'max_participants': 50,
        'status': 'recruiting',
      };
      final participantsBy = <String, List<String>>{
        'cid': ['a', 'b', 'c'],
      };
      final submissionsBy = <String, List<String>>{
        'cid': ['x'],
      };
      final m = mapChallengeRowForListUi(
        row,
        participantsByChallenge: participantsBy,
        submissionsByChallenge: submissionsBy,
      );
      expect(m['currentParticipants'], 3);
      expect(m['participantCount'], 3);
      expect((m['participants'] as List).length, 3);
      expect(m['submissionCount'], 1);
      expect(m['prizePool'], 30.0);
    });
  });
}
