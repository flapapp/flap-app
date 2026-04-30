import 'package:easy_localization/easy_localization.dart';

import 'utils/city_catalog.dart';

/// Localized label for a stored city value (Ukrainian/English name, English slug,
/// or other form matching [CityCatalog]).
///
/// All UI that shows a user's or entity's city should use this (or the same
/// logic via [CityCatalog]) so labels follow the current app locale.
String localizeCity(String cityName) {
  final trimmed = cityName.trim();
  if (trimmed.isEmpty) {
    return tr('unknown_city');
  }
  final slug = CityCatalog.toEnglishStorageKey(trimmed);
  if (slug != null && slug.isNotEmpty) {
    return CityCatalog.labelForDisplay(slug);
  }
  return CityCatalog.labelForDisplay(trimmed);
}
