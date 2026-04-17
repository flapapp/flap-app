import '../../../../models/app_team.dart';
import '../../../../models/team_invite.dart';
import '../../../../services/team_service.dart';
import '../../domain/repositories/profile_team_membership_repository.dart';

class ProfileTeamMembershipRepositoryImpl
    implements ProfileTeamMembershipRepository {
  ProfileTeamMembershipRepositoryImpl(this._teams);

  final TeamService _teams;

  @override
  Future<List<AppTeam>> fetchUserTeams(String userId) {
    return _teams.fetchUserTeams(userId);
  }

  @override
  Stream<List<AppTeam>> watchUserTeams(String userId) {
    return _teams.watchUserTeams(userId);
  }

  @override
  Stream<List<TeamInvite>> watchInvites(String userId) {
    return _teams.watchInvites(userId);
  }

  @override
  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  }) {
    return _teams.respondToInvite(invite: invite, accept: accept);
  }

  @override
  Future<AppTeam?> getTeam(String teamId) {
    return _teams.getTeam(teamId);
  }
}
