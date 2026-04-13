import 'dart:typed_data';

import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/team.dart';

abstract class TeamCreationRepository {
  /// Persists club row (via RPC) and squad; uploads [logoBytes] when provided.
  Future<String> submitTeamWithSquad({
    required String currentUserId,
    required Team team,
    required String description,
    required bool isPublic,
    required List<Player> squad,
    Uint8List? logoBytes,
  });
}
