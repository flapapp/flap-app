import 'package:flap_app/features/matches/data/models/match.dart';
import 'package:flap_app/features/matches/presentation/pages/finish_match_flow_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Match _baseMatch({String? teamAId, String? teamBId}) {
    return Match(
      id: 'match-1',
      title: 'Team Match',
      description: '',
      organizerId: 'org-1',
      organizerName: 'Organizer',
      date: DateTime.parse('2026-05-07T10:00:00Z'),
      time: '10:00',
      location: 'Test',
      city: 'Test',
      currentPlayers: 2,
      maxPlayers: 10,
      participants: const ['u1', 'u2'],
      level: MatchLevel.intermediate,
      cost: 0,
      autoBalance: false,
      isPrivate: false,
      status: MatchStatus.open,
      isTeamMatch: true,
      teamAId: teamAId,
      teamBId: teamBId,
      createdAt: DateTime.parse('2026-05-07T09:00:00Z'),
      updatedAt: DateTime.parse('2026-05-07T09:00:00Z'),
    );
  }

  test('resolveFinishTeamIds uses invite ids when match ids are missing', () {
    final match = _baseMatch();
    final ids = resolveFinishTeamIds(match, [
      {
        'requesting_team_id': 'team-host',
        'target_team_id': 'team-away',
        'status': 'accepted',
        'created_at': '2026-05-07T11:00:00Z',
        'created_by': 'org-1',
      },
    ]);

    expect(ids.teamAId, 'team-host');
    expect(ids.teamBId, 'team-away');
  });

  test('resolveFinishTeamIds keeps explicit match host team id', () {
    final match = _baseMatch(teamAId: 'team-host-fixed');
    final ids = resolveFinishTeamIds(match, [
      {
        'requesting_team_id': 'team-host-old',
        'target_team_id': 'team-away',
        'status': 'accepted',
        'created_at': '2026-05-07T11:00:00Z',
        'created_by': 'org-1',
      },
    ]);

    expect(ids.teamAId, 'team-host-fixed');
    expect(ids.teamBId, 'team-away');
  });

  group('mergeFinishMatchRosterLists', () {
    test('uses fetched members when match rosters are empty', () {
      final m = mergeFinishMatchRosterLists(
        matchRosterA: const [],
        matchRosterB: const [],
        fetchedMembersA: const ['a1', 'a2'],
        fetchedMembersB: const ['b1'],
      );
      expect(m.rosterA, ['a1', 'a2']);
      expect(m.rosterB, ['b1']);
    });

    test('prefers explicit match rosters over fetched members', () {
      final m = mergeFinishMatchRosterLists(
        matchRosterA: const ['x1'],
        matchRosterB: const ['y1', 'y2'],
        fetchedMembersA: const ['a1'],
        fetchedMembersB: const ['b1'],
      );
      expect(m.rosterA, ['x1']);
      expect(m.rosterB, ['y1', 'y2']);
    });

    test('removes overlap so a player is not assigned to both teams', () {
      final m = mergeFinishMatchRosterLists(
        matchRosterA: const [],
        matchRosterB: const [],
        fetchedMembersA: const ['u1', 'u2'],
        fetchedMembersB: const ['u1', 'u3'],
      );
      expect(m.rosterA, ['u1', 'u2']);
      expect(m.rosterB, ['u3']);
    });
  });
}
