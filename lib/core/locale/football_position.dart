import 'package:easy_localization/easy_localization.dart';

/// Canonical [profiles.position] values in English (lowercase) for the database.
class FootballPosition {
  static const String goalkeeper = 'goalkeeper';
  static const String defender = 'defender';
  static const String midfielder = 'midfielder';
  static const String forward = 'forward';
  static const String utility = 'utility';

  static const List<String> allDbValues = <String>[
    goalkeeper,
    defender,
    midfielder,
    forward,
    utility,
  ];
}

/// Lowercase exact input → canonical DB value. Keys are ASCII (English words,
/// phrases, and romanized legacy position names for migration).
const Map<String, String> _positionAliases = <String, String>{
  'gk': FootballPosition.goalkeeper,
  'keeper': FootballPosition.goalkeeper,
  'goalie': FootballPosition.goalkeeper,
  'defense': FootballPosition.defender,
  'defence': FootballPosition.defender,
  'midfield': FootballPosition.midfielder,
  'mid': FootballPosition.midfielder,
  'striker': FootballPosition.forward,
  'attack': FootballPosition.forward,
  'attacker': FootballPosition.forward,
  'universal': FootballPosition.utility,
  'utility player': FootballPosition.utility,
  'vorotar': FootballPosition.goalkeeper,
  'vratar': FootballPosition.goalkeeper,
  'zakhysnyk': FootballPosition.defender,
  'pivzakhysnyk': FootballPosition.midfielder,
  'napadnyk': FootballPosition.forward,
};

/// Maps localized or legacy text to an English DB value, or null if empty.
String? positionToEnglishDb(String? raw) {
  if (raw == null) {
    return null;
  }
  final t = raw.trim();
  if (t.isEmpty) {
    return null;
  }
  final lower = t.toLowerCase();
  if (FootballPosition.allDbValues.contains(lower)) {
    return lower;
  }
  final fromAlias = _positionAliases[lower];
  if (fromAlias != null) {
    return fromAlias;
  }
  if (t == tr('il_f2d20c7ee1')) {
    return FootballPosition.goalkeeper;
  }
  if (t == tr('il_157ddc59b5')) {
    return FootballPosition.defender;
  }
  if (t == tr('il_d332e47845')) {
    return FootballPosition.midfielder;
  }
  if (t == tr('il_f1c65e1481')) {
    return FootballPosition.forward;
  }
  if (t == tr('il_ab28eea9ef')) {
    return FootballPosition.utility;
  }
  return null;
}

/// Localized display string for a stored or legacy [position] value.
String positionLabelForDisplay(String? position) {
  final db = positionToEnglishDb(position);
  if (db != null) {
    switch (db) {
      case FootballPosition.goalkeeper:
        return tr('il_f2d20c7ee1');
      case FootballPosition.defender:
        return tr('il_157ddc59b5');
      case FootballPosition.midfielder:
        return tr('il_d332e47845');
      case FootballPosition.forward:
        return tr('il_f1c65e1481');
      case FootballPosition.utility:
        return tr('il_ab28eea9ef');
    }
  }
  final s = (position ?? '').toString().trim();
  if (s.isEmpty) {
    return tr('il_a62e8c639a');
  }
  return s;
}
