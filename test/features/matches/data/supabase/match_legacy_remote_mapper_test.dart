import 'package:flap_app/features/matches/data/supabase/match_legacy_remote_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('MatchLegacyRemoteMapper team status mapping', () {
    Map<String, dynamic> _baseRowWithTeams(List<Map<String, dynamic>> teams) {
      return <String, dynamic>{
        'id': 'match-1',
        'title': 'Team Match',
        'description': '',
        'organizer_id': 'organizer-1',
        'scheduled_at': '2026-05-07T10:00:00Z',
        'created_at': '2026-05-07T09:00:00Z',
        'updated_at': '2026-05-07T09:00:00Z',
        'location': 'Test',
        'city': 'Test City',
        'max_players': 10,
        'level': 'intermediate',
        'participation_cost': 0,
        'auto_balance': false,
        'is_private': false,
        'status': 'open',
        'is_team_match': true,
        'match_participants': const <Map<String, dynamic>>[],
        'match_invites': const <Map<String, dynamic>>[],
        'match_teams': teams,
      };
    }

    Map<String, dynamic> _teamRow({
      required int slot,
      required String teamId,
      required String name,
      required List<Map<String, dynamic>> rosters,
    }) {
      return <String, dynamic>{
        'team_slot': slot,
        'source_team_id': teamId,
        'display_name': name,
        'team_total_rating': 0,
        'match_team_rosters': rosters,
      };
    }

    Map<String, dynamic> _roster(String playerId, String status) {
      return <String, dynamic>{'player_id': playerId, 'status': status};
    }

    test('derives confirmed status when all team roster entries are confirmed', () {
      final row = _baseRowWithTeams([
        _teamRow(
          slot: 1,
          teamId: 'team-a',
          name: 'Team A',
          rosters: [_roster('a1', 'confirmed'), _roster('a2', 'confirmed')],
        ),
        _teamRow(
          slot: 2,
          teamId: 'team-b',
          name: 'Team B',
          rosters: [_roster('b1', 'pending')],
        ),
      ]);

      final mapped = MatchLegacyRemoteMapper.legacyMapFromJoinedRow(row);
      expect(mapped['teamAStatus'], 'confirmed');
      expect(mapped['teamBStatus'], 'pending');
    });

    test('derives pending status when roster statuses are mixed', () {
      final row = _baseRowWithTeams([
        _teamRow(
          slot: 1,
          teamId: 'team-a',
          name: 'Team A',
          rosters: [_roster('a1', 'confirmed'), _roster('a2', 'pending')],
        ),
        _teamRow(
          slot: 2,
          teamId: 'team-b',
          name: 'Team B',
          rosters: [_roster('b1', 'confirmed')],
        ),
      ]);

      final mapped = MatchLegacyRemoteMapper.legacyMapFromJoinedRow(row);
      expect(mapped['teamAStatus'], 'pending');
      expect(mapped['teamBStatus'], 'confirmed');
    });

    test('derives declined status when all team roster entries are declined', () {
      final row = _baseRowWithTeams([
        _teamRow(
          slot: 1,
          teamId: 'team-a',
          name: 'Team A',
          rosters: [_roster('a1', 'declined')],
        ),
        _teamRow(
          slot: 2,
          teamId: 'team-b',
          name: 'Team B',
          rosters: [_roster('b1', 'confirmed')],
        ),
      ]);

      final mapped = MatchLegacyRemoteMapper.legacyMapFromJoinedRow(row);
      expect(mapped['teamAStatus'], 'declined');
      expect(mapped['teamBStatus'], 'confirmed');
    });

    test('roster-only player visibility works after team match acceptance', () {
      // Slot-2 row is what the new accept_team_match_request RPC creates.
      // Stat aggregation and "My Matches" visibility for invited-team players
      // both hinge on a confirmed match_team_rosters row pointing back to
      // match_teams (slot 2), so this guards the contract.
      final row = _baseRowWithTeams([
        _teamRow(
          slot: 1,
          teamId: 'team-host',
          name: 'Host',
          rosters: [_roster('host-1', 'confirmed')],
        ),
        _teamRow(
          slot: 2,
          teamId: 'team-away',
          name: 'Away',
          rosters: [
            _roster('away-1', 'confirmed'),
            _roster('away-2', 'confirmed'),
          ],
        ),
      ]);

      final mapped = MatchLegacyRemoteMapper.legacyMapFromJoinedRow(row);
      expect(mapped['teamBId'], 'team-away');
      expect(
        (mapped['teamRosters'] as Map)['teamB'],
        ['away-1', 'away-2'],
        reason: 'Invited-team players must show up in teamB roster so '
            'isUserMatchMember() returns true for them.',
      );
      expect(mapped['teamBStatus'], 'confirmed');
    });

    test('maps source team ids and display names for team balance consumers', () {
      final row = _baseRowWithTeams([
        _teamRow(
          slot: 1,
          teamId: 'host-team-id',
          name: 'Host United',
          rosters: [_roster('a1', 'confirmed')],
        ),
        _teamRow(
          slot: 2,
          teamId: 'opponent-team-id',
          name: 'Opponent FC',
          rosters: [_roster('b1', 'confirmed')],
        ),
      ]);

      final mapped = MatchLegacyRemoteMapper.legacyMapFromJoinedRow(row);

      expect(mapped['teamAId'], 'host-team-id');
      expect(mapped['teamBId'], 'opponent-team-id');
      expect((mapped['teamA'] as Map<String, dynamic>)['name'], 'Host United');
      expect((mapped['teamB'] as Map<String, dynamic>)['name'], 'Opponent FC');
    });
  });
}
