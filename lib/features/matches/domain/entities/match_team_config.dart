/// Team-formation limits for a match.
///
/// Only two teams can be formed today. The formation pipeline
/// (`_autoDistributePlayers`, `_shuffleTeams`), the multi-team results table
/// and the finish flow are all already generic over the team count, so raising
/// [kMaxMatchTeams] is the single change needed to allow 3+ teams — no other
/// formation logic has to be touched.
const int kMinMatchTeams = 2;

/// Maximum number of teams that can currently be formed for a match.
/// Bump this (e.g. to 4) to re-enable larger team splits.
const int kMaxMatchTeams = 2;

/// Whether the organizer is offered a choice of how many teams to form.
/// While the min and max are equal (two teams only) there is nothing to pick,
/// so the team-count selector is hidden.
bool get matchTeamCountIsSelectable => kMaxMatchTeams > kMinMatchTeams;
