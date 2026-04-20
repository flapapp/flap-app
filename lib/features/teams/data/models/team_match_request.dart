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

  factory TeamMatchRequest.fromDoc(dynamic doc) {
    final id = (doc.id ?? '').toString();
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map? ?? const {});
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      final parsed = DateTime.tryParse((v ?? '').toString());
      return parsed ?? DateTime.now();
    }
    return TeamMatchRequest(
      id: id,
      matchId: (data['matchId'] ?? '').toString(),
      teamId: (data['teamId'] ?? '').toString(),
      opponentTeamId: (data['opponentTeamId'] ?? '').toString(),
      opponentName: (data['opponentName'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      status: _statusFromString((data['status'] ?? 'pending').toString()),
      createdAt: parseDate(data['createdAt']),
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
      'createdAt': createdAt.toIso8601String(),
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











