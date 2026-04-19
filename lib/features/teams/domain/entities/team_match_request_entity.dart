import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum TeamMatchRequestStatus { pending, accepted, declined }

class TeamMatchRequestEntity extends Equatable {
  const TeamMatchRequestEntity({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.opponentTeamId,
    required this.opponentName,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    this.proposedRoster = const [],
  });

  final String id;
  final String matchId;
  final String teamId;
  final String opponentTeamId;
  final String opponentName;
  final String createdBy;
  final TeamMatchRequestStatus status;
  final DateTime createdAt;
  final List<String> proposedRoster;

  @override
  List<Object?> get props => [
        id,
        matchId,
        teamId,
        opponentTeamId,
        opponentName,
        createdBy,
        status,
        createdAt,
        proposedRoster,
      ];
}
