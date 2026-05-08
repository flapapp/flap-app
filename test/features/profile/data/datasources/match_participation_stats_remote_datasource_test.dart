import 'package:flap_app/features/profile/data/datasources/match_participation_stats_remote_datasource_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rosterStatusCountsForMatchStats', () {
    test('declined does not count', () {
      expect(rosterStatusCountsForMatchStats('declined'), isFalse);
    });

    test('confirmed and pending count', () {
      expect(rosterStatusCountsForMatchStats('confirmed'), isTrue);
      expect(rosterStatusCountsForMatchStats('pending'), isTrue);
    });

    test('null or empty counts (legacy rows)', () {
      expect(rosterStatusCountsForMatchStats(null), isTrue);
      expect(rosterStatusCountsForMatchStats(''), isTrue);
      expect(rosterStatusCountsForMatchStats('   '), isTrue);
    });
  });
}
