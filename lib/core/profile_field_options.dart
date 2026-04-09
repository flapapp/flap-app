import '../utils/i18n.dart';

/// Shared labels for field position and experience (stored values match Ukrainian keys).
class ProfileFieldOptions {
  ProfileFieldOptions._();

  static List<String> get positionLabels => [
    I18n.inline('Воротар', 'Goalkeeper'),
    I18n.inline('Захисник', 'Defender'),
    I18n.inline('Півзахисник', 'Midfielder'),
    I18n.inline('Нападник', 'Forward'),
    I18n.inline('Універсал', 'Universal'),
  ];

  /// Stored `position` values (Ukrainian) aligned with [positionLabels] indices.
  static const List<String> positionStorageValues = [
    'Воротар',
    'Захисник',
    'Півзахисник',
    'Нападник',
    'Універсал',
  ];

  static List<String> get experienceLabels => [
    I18n.inline('Початківець', 'Beginner'),
    I18n.inline('Аматор', 'Amateur'),
    I18n.inline('Досвідчений', 'Experienced'),
    I18n.inline('Професіонал', 'Professional'),
  ];

  static const List<String> experienceStorageValues = [
    'Початківець',
    'Аматор',
    'Досвідчений',
    'Професіонал',
  ];
}
