import 'package:flutter_countries/flutter_countries.dart';

/// Cached access to country/city lists from [flutter_countries] (offline JSON).
class WorldLocationService {
  WorldLocationService._();

  static List<Country>? _countries;
  static final Map<String, List<String>> _citiesByCountry = {};

  static Future<List<String>> countryNames() async {
    _countries ??= await Countries.all;
    final names = _countries!
        .map((c) => c.name?.trim())
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Cities whose [City.countryName] exactly matches [countryName].
  static Future<List<String>> cityNamesForCountry(String countryName) async {
    final key = countryName.trim();
    if (key.isEmpty) return const [];
    final cached = _citiesByCountry[key];
    if (cached != null) return cached;

    final raw = await Cities.byCountryName(key);
    final names = raw
        .where((c) => (c.countryName ?? '').trim() == key)
        .map((c) => c.name?.trim())
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    _citiesByCountry[key] = names;
    return names;
  }
}
