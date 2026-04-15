import 'profile_field_options.dart';

/// Maps UI storage strings ([ProfileFieldOptions]) ↔ Postgres enum labels in
/// `schema.sql` (`player_position`, `player_experience`).
class ProfileDbCodec {
  ProfileDbCodec._();

  static const Set<String> _dbPositions = {'GK', 'DEF', 'MID', 'FWD', 'OTHER'};
  static const Set<String> _dbExperience = {
    'BEGINNER',
    'AMATEUR',
    'EXPERIENCED',
    'PROFESSIONAL',
  };

  static const Map<String, String> _positionUiToDb = {
    'Воротар': 'GK',
    'Захисник': 'DEF',
    'Півзахисник': 'MID',
    'Нападник': 'FWD',
    'Універсал': 'OTHER',
  };

  static final Map<String, String> _positionDbToUi = {
    for (final e in _positionUiToDb.entries) e.value: e.key,
  };

  static const Map<String, String> _experienceUiToDb = {
    'Початківець': 'BEGINNER',
    'Аматор': 'AMATEUR',
    'Досвідчений': 'EXPERIENCED',
    'Професіонал': 'PROFESSIONAL',
  };

  static final Map<String, String> _experienceDbToUi = {
    for (final e in _experienceUiToDb.entries) e.value: e.key,
  };

  /// Value sent to Supabase `user_profiles.position`.
  static String? encodePositionForDb(String? uiValue) {
    if (uiValue == null || uiValue.isEmpty) return null;
    if (_dbPositions.contains(uiValue)) return uiValue;
    return _positionUiToDb[uiValue];
  }

  /// Value sent to Supabase `user_profiles.experience`.
  static String? encodeExperienceForDb(String? uiValue) {
    if (uiValue == null || uiValue.isEmpty) return null;
    if (_dbExperience.contains(uiValue)) return uiValue;
    return _experienceUiToDb[uiValue];
  }

  /// Value for domain/UI (matches [ProfileFieldOptions] storage lists).
  static String? decodePositionFromDb(String? dbValue) {
    if (dbValue == null || dbValue.isEmpty) return null;
    if (ProfileFieldOptions.positionStorageValues.contains(dbValue)) {
      return dbValue;
    }
    return _positionDbToUi[dbValue] ?? dbValue;
  }

  static String? decodeExperienceFromDb(String? dbValue) {
    if (dbValue == null || dbValue.isEmpty) return null;
    if (ProfileFieldOptions.experienceStorageValues.contains(dbValue)) {
      return dbValue;
    }
    return _experienceDbToUi[dbValue] ?? dbValue;
  }
}
