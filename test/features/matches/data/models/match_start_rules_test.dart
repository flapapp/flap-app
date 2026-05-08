import 'package:flap_app/features/matches/data/models/match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Match _baseMatch({
    required bool isTeamMatch,
    required List<String> participants,
    String? teamAStatus,
    String? teamBStatus,
    Map<String, List<String>> teamRosters = const {},
  }) {
    return Match(
      id: 'm1',
      title: 'Test',
      description: '',
      organizerId: 'u1',
      organizerName: 'Org',
      date: DateTime.parse('2026-05-07T10:00:00Z'),
      time: '10:00',
      location: 'Loc',
      city: 'City',
      currentPlayers: participants.length,
      maxPlayers: 10,
      participants: participants,
      level: MatchLevel.intermediate,
      cost: 0,
      autoBalance: false,
      isPrivate: false,
      status: MatchStatus.open,
      isTeamMatch: isTeamMatch,
      teamAStatus: teamAStatus,
      teamBStatus: teamBStatus,
      teamRosters: teamRosters,
      createdAt: DateTime.parse('2026-05-07T09:00:00Z'),
      updatedAt: DateTime.parse('2026-05-07T09:00:00Z'),
    );
  }

  test('team match can start without formed rosters when both teams accepted', () {
    final match = _baseMatch(
      isTeamMatch: true,
      participants: const ['u1'],
      teamAStatus: 'confirmed',
      teamBStatus: 'accepted',
      teamRosters: const {'teamA': [], 'teamB': []},
    );

    expect(MatchUtils.canStartMatch(match), isTrue);
  });

  test('team match cannot start if opponent team not accepted/confirmed', () {
    final match = _baseMatch(
      isTeamMatch: true,
      participants: const ['u1'],
      teamAStatus: 'confirmed',
      teamBStatus: 'pending',
    );

    expect(MatchUtils.canStartMatch(match), isFalse);
  });

  test('non-team match still requires full formed teams', () {
    final match = _baseMatch(
      isTeamMatch: false,
      participants: const ['u1', 'u2'],
      teamRosters: const {'teamA': ['u1'], 'teamB': []},
    );

    expect(MatchUtils.canStartMatch(match), isFalse);
  });
}
