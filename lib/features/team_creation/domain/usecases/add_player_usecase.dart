import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/player_position.dart';

/// Validates manual add / edit rules for the squad step.
class AddPlayerUseCase {
  static const int maxSquadSize = 30;

  /// Returns `null` on success, or an error message key / text.
  String? validateNewPlayer({
    required List<Player> current,
    required String name,
    required int jerseyNumber,
    required PlayerPosition position,
    int? age,
    String? nationality,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'empty_name';
    }
    if (jerseyNumber < 1 || jerseyNumber > 99) {
      return 'jersey_range';
    }
    if (current.any((p) => p.jerseyNumber == jerseyNumber)) {
      return 'jersey_taken';
    }
    if (current.length >= maxSquadSize) {
      return 'squad_max';
    }
    if (age != null && (age < 16 || age > 45)) {
      return 'age_range';
    }
    if (nationality != null && nationality.trim().length > 64) {
      return 'nationality_long';
    }
    return null;
  }

  List<Player>? tryAppendPlayer(List<Player> current, Player player) {
    final err = validateNewPlayer(
      current: current,
      name: player.name,
      jerseyNumber: player.jerseyNumber,
      position: player.position,
      age: player.age,
      nationality: player.nationality,
    );
    if (err != null) return null;
    return [...current, player];
  }

  String? validateSquadForSubmit(List<Player> squad) {
    if (squad.isEmpty) {
      return null;
    }
    if (squad.length > maxSquadSize) {
      return 'squad_too_large';
    }
    final numbers = squad.map((e) => e.jerseyNumber).toSet();
    if (numbers.length != squad.length) {
      return 'duplicate_jersey';
    }
    return null;
  }
}
