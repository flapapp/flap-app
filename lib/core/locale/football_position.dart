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
  const staticMap = <String, String>{
    'воротар': FootballPosition.goalkeeper,
    'вратар': FootballPosition.goalkeeper,
    'захисник': FootballPosition.defender,
    'півзахисник': FootballPosition.midfielder,
    'нападник': FootballPosition.forward,
    'універсал': FootballPosition.utility,
    'utility player': FootballPosition.utility,
  };
  if (staticMap.containsKey(lower)) {
    return staticMap[lower];
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

/// Localized display string for a DB [position] value.
String positionLabelForDisplay(String? position) {
  final p = (position ?? '').toString().trim().toLowerCase();
  switch (p) {
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
    default:
      return (position ?? '').toString();
  }
}
