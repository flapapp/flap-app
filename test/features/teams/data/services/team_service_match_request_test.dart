import 'package:flap_app/features/teams/data/services/team_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks in the Supabase RPC contract used by the team-match-acceptance flow.
/// These RPCs are SECURITY DEFINER and the parameter shapes here must stay
/// aligned with migration
/// `20260508120000_team_match_acceptance_rpc_and_backfill.sql`. Roster
/// propagation drives both `can_view_match` ("My Matches" visibility) and
/// player/team statistics aggregation, so any drift here silently regresses
/// team-match participation across the app.
void main() {
  group('buildAcceptTeamMatchRpcParams', () {
    test('passes only request id when roster is empty', () {
      final params = buildAcceptTeamMatchRpcParams(
        requestId: 'req-1',
        confirmedRoster: const <String>[],
      );
      expect(params, <String, dynamic>{'p_request_id': 'req-1'});
      expect(
        params.containsKey('p_roster'),
        isFalse,
        reason:
            'When the client passes no explicit roster the RPC must fall '
            'back to team_match_request_players or full team_members.',
      );
    });

    test('forwards a deduplicated, trimmed roster', () {
      final params = buildAcceptTeamMatchRpcParams(
        requestId: 'req-2',
        confirmedRoster: const <String>['p1', ' p2 ', '', 'p1', 'p2'],
      );
      final roster = (params['p_roster'] as List<dynamic>).cast<String>();
      expect(params['p_request_id'], 'req-2');
      expect(roster, containsAll(<String>['p1', 'p2']));
      expect(roster.length, 2);
      expect(roster.contains(''), isFalse);
    });
  });

  group('buildDeclineTeamMatchRpcParams', () {
    test('only carries the request id', () {
      expect(
        buildDeclineTeamMatchRpcParams(requestId: 'req-3'),
        <String, dynamic>{'p_request_id': 'req-3'},
      );
    });
  });

  group('buildCancelTeamMatchRpcParams', () {
    test('only carries the request id', () {
      expect(
        buildCancelTeamMatchRpcParams(requestId: 'req-4'),
        <String, dynamic>{'p_request_id': 'req-4'},
      );
    });
  });
}
