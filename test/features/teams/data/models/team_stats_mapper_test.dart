import 'package:flap_app/features/teams/data/models/team_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks in the contract between the SQL aggregator and the Dart consumers.
/// The migration `20260508140000_team_stats_aggregation_and_history.sql`
/// writes snake_case columns and jsonb payloads; the Flutter UI reads via
/// `TeamStats.fromFirestoreMap` which expects camelCase. If this mapper
/// drifts, every team-stat surface (team hub, team details, profile) silently
/// shows zeros again — so this test exists to catch that regression early.
void main() {
  group('mapTeamStatsRowToLegacyShape', () {
    test('maps a full snake_case row into the legacy camelCase shape', () {
      final mapped = mapTeamStatsRowToLegacyShape(<String, dynamic>{
        'team_id': 'team-1',
        'team_name': 'Lions',
        'wins': 8,
        'draws': 3,
        'losses': 2,
        'goals_for': 27,
        'goals_against': 11,
        'clean_sheets': 5,
        'current_win_streak': 3,
        'current_unbeaten_streak': 5,
        'longest_win_streak': 7,
        'recent_form': ['W', 'W', 'D', 'W', 'L'],
        'recent_matches': [
          <String, dynamic>{
            'matchId': 'm1',
            'goalsFor': 3,
            'goalsAgainst': 1,
            'outcome': 'W',
          },
        ],
        'player_goals': <String, dynamic>{'p1': 5, 'p2': 3},
        'last_finished_match_at': '2026-05-07T20:00:00Z',
        'updated_at': '2026-05-08T00:00:00Z',
      });

      expect(mapped['teamName'], 'Lions');
      expect(mapped['wins'], 8);
      expect(mapped['draws'], 3);
      expect(mapped['losses'], 2);
      expect(mapped['goalsFor'], 27);
      expect(mapped['goalsAgainst'], 11);
      expect(mapped['cleanSheets'], 5);
      expect(mapped['currentWinStreak'], 3);
      expect(mapped['currentUnbeatenStreak'], 5);
      expect(mapped['longestWinStreak'], 7);
      expect(mapped['recentForm'], ['W', 'W', 'D', 'W', 'L']);
      expect((mapped['playerGoals'] as Map)['p1'], 5);
      expect((mapped['recentMatches'] as List).length, 1);
      expect(
        (mapped['recentMatches'] as List).first,
        isA<Map<String, dynamic>>(),
        reason: 'Recent matches must round-trip through Map<String, dynamic> so '
            'TeamStats.fromFirestoreMap can pass them straight through.',
      );
      expect(mapped['lastFinishedMatchAt'], '2026-05-07T20:00:00Z');
      expect(mapped['updatedAt'], '2026-05-08T00:00:00Z');
    });

    test('falls back to fallbackName when team_name is missing', () {
      final mapped = mapTeamStatsRowToLegacyShape(
        <String, dynamic>{},
        fallbackName: 'Tigers',
      );
      expect(mapped['teamName'], 'Tigers');
      expect(mapped['wins'], 0);
      expect(mapped['recentForm'], <String>[]);
      expect(mapped['playerGoals'], <String, int>{});
    });

    test('treats numeric strings as ints (defensive against jsonb edge cases)', () {
      final mapped = mapTeamStatsRowToLegacyShape(<String, dynamic>{
        'team_name': 'Owls',
        'wins': '7',
        'goals_for': '42',
        'player_goals': <String, dynamic>{'p1': '3', 'p2': 2},
      });
      expect(mapped['wins'], 7);
      expect(mapped['goalsFor'], 42);
      expect((mapped['playerGoals'] as Map)['p1'], 3);
      expect((mapped['playerGoals'] as Map)['p2'], 2);
    });

    test('round-trips via TeamStats.fromFirestoreMap with rich fields intact', () {
      final mapped = mapTeamStatsRowToLegacyShape(<String, dynamic>{
        'team_name': 'Falcons',
        'wins': 4,
        'draws': 2,
        'losses': 1,
        'goals_for': 12,
        'goals_against': 6,
        'clean_sheets': 2,
        'current_win_streak': 2,
        'current_unbeaten_streak': 3,
        'longest_win_streak': 4,
        'recent_form': ['W', 'D', 'W'],
        'updated_at': '2026-05-08T00:00:00Z',
      });

      final stats = TeamStats.fromFirestoreMap('team-falcons', mapped);
      expect(stats.teamName, 'Falcons');
      expect(stats.matchesPlayed, 7);
      expect(stats.pointsValue, 4 * 3 + 2);
      expect(stats.goalDifferenceValue, 6);
      expect(stats.winRate, closeTo(57.14, 0.01));
      expect(stats.currentUnbeatenStreak, 3);
      expect(stats.recentForm, ['W', 'D', 'W']);
    });
  });
}
