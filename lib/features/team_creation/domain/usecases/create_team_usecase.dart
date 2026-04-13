import 'dart:typed_data';

import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/team.dart';
import 'package:flap_app/features/team_creation/domain/repositories/team_creation_repository.dart';

class CreateTeamUseCase {
  CreateTeamUseCase(this._repository);

  final TeamCreationRepository _repository;

  Future<String> call({
    required String currentUserId,
    required Team team,
    required String description,
    required bool isPublic,
    required List<Player> squad,
    Uint8List? logoBytes,
  }) {
    return _repository.submitTeamWithSquad(
      currentUserId: currentUserId,
      team: team,
      description: description,
      isPublic: isPublic,
      squad: squad,
      logoBytes: logoBytes,
    );
  }
}
