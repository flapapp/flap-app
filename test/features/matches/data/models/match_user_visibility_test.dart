import 'package:flap_app/features/matches/data/models/match.dart';
import 'package:flutter_test/flutter_test.dart';

Match _minimalMatch({
  List<String> participants = const [],
  Map<String, List<String>> teamRosters = const {},
  Map<String, Map<String, String>> teamRosterStatus = const {},
}) {
  final now = DateTime.parse('2026-05-07T12:00:00Z');
  return Match(
    id: 'm1',
    title: 'Team match',
    description: '',
    organizerId: 'org-1',
    organizerName: 'Org',
    date: now,
    time: '12:00',
    location: '',
    city: '',
    currentPlayers: 0,
    maxPlayers: 10,
    participants: participants,
    level: MatchLevel.intermediate,
    cost: 0,
    autoBalance: false,
    isPrivate: false,
    status: MatchStatus.open,
    isTeamMatch: true,
    teamRosters: teamRosters,
    teamRosterStatus: teamRosterStatus,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('isUserOnActiveTeamRoster is true for confirmed roster status', () {
    final m = _minimalMatch(
      teamRosterStatus: {
        'teamB': {'player-x': 'confirmed'},
      },
    );
    expect(m.isUserOnActiveTeamRoster('player-x'), isTrue);
  });

  test('isUserOnActiveTeamRoster is false when user declined', () {
    final m = _minimalMatch(
      teamRosterStatus: {
        'teamB': {'player-x': 'declined'},
      },
    );
    expect(m.isUserOnActiveTeamRoster('player-x'), isFalse);
  });

  test('isUserOnActiveTeamRoster falls back to teamRosters lists', () {
    final m = _minimalMatch(
      teamRosters: {
        'teamA': ['player-y'],
      },
    );
    expect(m.isUserOnActiveTeamRoster('player-y'), isTrue);
  });

  test('isUserMatchMember includes roster-only players', () {
    final m = _minimalMatch(
      participants: const [],
      teamRosterStatus: {
        'teamA': {'captain': 'pending'},
      },
    );
    expect(m.isUserMatchMember('captain'), isTrue);
    expect(m.isParticipant('captain'), isFalse);
  });
}
