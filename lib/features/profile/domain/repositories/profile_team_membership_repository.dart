import '../../../../models/app_team.dart';
import '../../../../models/team_invite.dart';

/// Current user's teams, invites, and team document reads (domain).
abstract class ProfileTeamMembershipRepository {
  Future<List<AppTeam>> fetchUserTeams(String userId);

  Stream<List<AppTeam>> watchUserTeams(String userId);

  Stream<List<TeamInvite>> watchInvites(String userId);

  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  });

  Future<AppTeam?> getTeam(String teamId);
}
