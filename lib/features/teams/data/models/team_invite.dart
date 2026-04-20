import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/team_invite_entity.dart';

export '../../domain/entities/team_invite_entity.dart';

part 'team_invite.g.dart';

@JsonSerializable(explicitToJson: true)
class TeamInvite extends TeamInviteEntity {
  const TeamInvite({
    required super.id,
    required super.teamId,
    required super.teamName,
    required super.userId,
    required super.invitedBy,
    required super.status,
    required super.createdAt,
  });

  factory TeamInvite.fromDoc(dynamic doc) {
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
    return TeamInvite(
      id: id,
      teamId: (data['teamId'] ?? '').toString(),
      teamName: (data['teamName'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      invitedBy: (data['invitedBy'] ?? '').toString(),
      status: _statusFromString((data['status'] ?? 'pending').toString()),
      createdAt: parseDate(data['createdAt']),
    );
  }

  factory TeamInvite.fromJson(Map<String, dynamic> json) =>
      _$TeamInviteFromJson(json);

  Map<String, dynamic> toJson() => _$TeamInviteToJson(this);

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'userId': userId,
      'invitedBy': invitedBy,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static TeamInviteStatus _statusFromString(String value) {
    switch (value) {
      case 'accepted':
        return TeamInviteStatus.accepted;
      case 'declined':
        return TeamInviteStatus.declined;
      default:
        return TeamInviteStatus.pending;
    }
  }
}











