import 'dart:math';

import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/services/squad_generator.dart';

class GenerateSquadUseCase {
  GenerateSquadUseCase({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<Player> call() {
    return SquadGenerator.generateBalancedSquad(_random);
  }
}
