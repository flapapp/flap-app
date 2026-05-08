import 'package:flap_app/features/matches/data/services/match_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks in the parameter contract for the SECURITY DEFINER RPC
/// `public.create_team_match` defined in
/// `supabase/migrations/20260508160000_create_team_match_rpc.sql`. If this
/// shape drifts the team-match create flow regresses to the multi-step path
/// that produced RLS rejections + orphan matches.
void main() {
  group('buildCreateTeamMatchRpcParams', () {
    test('produces every named param the SQL function expects', () {
      final params = buildCreateTeamMatchRpcParams(
        title: 'Friendly Cup',
        description: 'Saturday clash',
        scheduledAt: DateTime.utc(2026, 5, 10, 18, 30),
        location: 'Central Park Field 3',
        city: 'kyiv',
        latitude: 50.45,
        longitude: 30.52,
        maxPlayers: 14,
        cost: 0,
        level: 'intermediate',
        isPrivate: false,
        hostTeamId: 'team-host',
        hostRoster: const ['p1', 'p2'],
        opponentTeamId: 'team-opp',
        opponentProposedRoster: const ['o1'],
      );

      expect(params['p_title'], 'Friendly Cup');
      expect(params['p_description'], 'Saturday clash');
      expect(params['p_scheduled_at'], '2026-05-10T18:30:00.000Z');
      expect(params['p_location'], 'Central Park Field 3');
      expect(params['p_city'], 'kyiv');
      expect(params['p_latitude'], 50.45);
      expect(params['p_longitude'], 30.52);
      expect(params['p_max_players'], 14);
      expect(params['p_participation_cost'], 0);
      expect(params['p_level'], 'intermediate');
      expect(params['p_is_private'], false);
      expect(params['p_host_team_id'], 'team-host');
      expect(params['p_host_roster'], ['p1', 'p2']);
      expect(params['p_opponent_team_id'], 'team-opp');
      expect(params['p_opponent_proposed_roster'], ['o1']);
    });

    test('omits opponent team id when blank but keeps roster array', () {
      final params = buildCreateTeamMatchRpcParams(
        title: 'Solo Mode',
        description: '',
        scheduledAt: DateTime.utc(2026, 5, 10),
        location: '',
        city: '',
        maxPlayers: 10,
        cost: 0,
        level: 'beginner',
        isPrivate: false,
        hostTeamId: 'team-host',
        opponentTeamId: '   ',
      );
      expect(params.containsKey('p_opponent_team_id'), isFalse);
      expect(params['p_host_roster'], <String>[]);
      expect(params['p_opponent_proposed_roster'], <String>[]);
    });

    test('trims and dedups roster ids while preserving order', () {
      final params = buildCreateTeamMatchRpcParams(
        title: 't',
        description: '',
        scheduledAt: DateTime.utc(2026, 5, 10),
        location: '',
        city: '',
        maxPlayers: 10,
        cost: 0,
        level: 'beginner',
        isPrivate: false,
        hostTeamId: 'team-host',
        hostRoster: const ['p1', ' p2 ', '', 'p1', 'p3'],
        opponentTeamId: 'team-opp',
        opponentProposedRoster: const ['o1', 'o1', 'o2'],
      );
      expect(params['p_host_roster'], ['p1', 'p2', 'p3']);
      expect(params['p_opponent_proposed_roster'], ['o1', 'o2']);
    });

    test('always serialises scheduled_at as UTC ISO-8601', () {
      final localDate = DateTime(2026, 5, 10, 21, 15); // local time
      final params = buildCreateTeamMatchRpcParams(
        title: 't',
        description: '',
        scheduledAt: localDate,
        location: '',
        city: '',
        maxPlayers: 10,
        cost: 0,
        level: 'beginner',
        isPrivate: false,
        hostTeamId: 'team-host',
      );
      final iso = params['p_scheduled_at'] as String;
      expect(iso.endsWith('Z'), isTrue,
          reason: 'Postgres compares timestamptz against UTC; the client '
              'must send UTC instants or scheduled times will drift across '
              'time zones.');
    });
  });
}
