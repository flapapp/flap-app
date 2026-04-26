import '../data/models/match.dart';
import '../../teams/data/models/app_team.dart';

class CreateMatchCommand {
  const CreateMatchCommand({
    required this.currentUserId,
    required this.currentUserEmail,
    required this.title,
    required this.description,
    required this.date,
    required this.timeLabel,
    required this.location,
    required this.city,
    required this.maxPlayers,
    required this.level,
    required this.cost,
    required this.autoBalance,
    required this.isPrivate,
    required this.teamMode,
    required this.selectedInviteFriendIds,
    required this.selectedRoster,
    required this.selectedTeam,
    required this.opponentTeam,
  });

  final String currentUserId;
  final String? currentUserEmail;
  final String title;
  final String description;
  final DateTime date;
  final String timeLabel;
  final String location;
  final String city;
  final int maxPlayers;
  final MatchLevel level;
  final double cost;
  final bool autoBalance;
  final bool isPrivate;
  final bool teamMode;
  final List<String> selectedInviteFriendIds;
  final List<String> selectedRoster;
  final AppTeam? selectedTeam;
  final AppTeam? opponentTeam;
}
