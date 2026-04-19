import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/team_match_request_entity.dart';

export '../../domain/entities/team_match_request_entity.dart';

part 'team_match_request.g.dart';

@JsonSerializable(explicitToJson: true)
class TeamMatchRequest extends TeamMatchRequestEntity {
  const TeamMatchRequest({
    required super.id,
    required super.matchId,
    required super.teamId,
    required super.opponentTeamId,
    required super.opponentName,
    required super.createdBy,
    required super.status,
    required super.createdAt,
    super.proposedRoster = const [],
  });

  factory TeamMatchRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamMatchRequest(
      id: doc.id,
      matchId: (data['matchId'] ?? '').toString(),
      teamId: (data['teamId'] ?? '').toString(),
      opponentTeamId: (data['opponentTeamId'] ?? '').toString(),
      opponentName: (data['opponentName'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      status: _statusFromString((data['status'] ?? 'pending').toString()),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      proposedRoster: List<String>.from(data['proposedRoster'] ?? const []),
    );
  }

  factory TeamMatchRequest.fromJson(Map<String, dynamic> json) =>
      _$TeamMatchRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TeamMatchRequestToJson(this);

  Map<String, dynamic> toFirestore() {
    return {
      'matchId': matchId,
      'teamId': teamId,
      'opponentTeamId': opponentTeamId,
      'opponentName': opponentName,
      'createdBy': createdBy,
      'status': status.name,
      'proposedRoster': proposedRoster,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static TeamMatchRequestStatus _statusFromString(String value) {
    switch (value) {
      case 'accepted':
        return TeamMatchRequestStatus.accepted;
      case 'declined':
        return TeamMatchRequestStatus.declined;
      default:
        return TeamMatchRequestStatus.pending;
    }
  }
}











