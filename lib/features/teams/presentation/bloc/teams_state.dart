import 'package:equatable/equatable.dart';

import 'package:flap_app/models/app_team.dart';

class TeamsState extends Equatable {
  const TeamsState({
    this.myTeams = const [],
    this.myTeamsLoading = false,
  });

  final List<AppTeam> myTeams;
  final bool myTeamsLoading;

  TeamsState copyWith({
    List<AppTeam>? myTeams,
    bool? myTeamsLoading,
  }) {
    return TeamsState(
      myTeams: myTeams ?? this.myTeams,
      myTeamsLoading: myTeamsLoading ?? this.myTeamsLoading,
    );
  }

  @override
  List<Object?> get props => [myTeams, myTeamsLoading];
}
