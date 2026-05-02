import 'dart:collection';

import 'package:easy_localization/easy_localization.dart';

class CityCatalog {
  /// Each row: optional [slug] (translation key, lowercase) and English [en] name.
  /// DB stores [toEnglishStorageKey] as lowercase slug from [en].
  static const List<Map<String, String>> _cityPairs = <Map<String, String>>[
    {'slug': 'kyiv', 'en': 'Kyiv'},
    {'slug': 'lviv', 'en': 'Lviv'},
    {'slug': 'odesa', 'en': 'Odesa'},
    {'slug': 'kharkiv', 'en': 'Kharkiv'},
    {'slug': 'dnipro', 'en': 'Dnipro'},
    {'slug': 'barcelona', 'en': 'Barcelona'},
    {'slug': 'madrid', 'en': 'Madrid'},
    {'slug': 'valencia', 'en': 'Valencia'},
    {'slug': 'london', 'en': 'London'},
    {'slug': 'berlin', 'en': 'Berlin'},
    {'slug': 'warsaw', 'en': 'Warsaw'},
    {'slug': 'prague', 'en': 'Prague'},
    {'slug': 'paris', 'en': 'Paris'},
    {'slug': 'rome', 'en': 'Rome'},
    {'slug': 'lisbon', 'en': 'Lisbon'},
  ];

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _pairEn(Map<String, String> pair) =>
      (pair['en'] ?? '').trim();

  static String _pairSlug(Map<String, String> pair) =>
      (pair['slug'] ?? '').trim();

  static List<String> _allAliases({bool includeAll = false}) {
    final set = LinkedHashSet<String>();

    for (final pair in _cityPairs) {
      final en = _pairEn(pair);
      final slug = _pairSlug(pair);
      if (en.isNotEmpty) {
        set.add(en);
      }
      if (slug.isNotEmpty && trExists(slug)) {
        set.add(tr(slug));
      }
    }

    if (includeAll) {
      set.add(tr('all_cities'));
    }

    return set.toList(growable: false);
  }

  static List<String> cities({bool includeAll = false}) {
    final out = LinkedHashSet<String>();

    if (includeAll) {
      out.add(tr('all_cities'));
    }

    for (final pair in _cityPairs) {
      final en = _pairEn(pair);
      final slug = _pairSlug(pair);
      if (slug.isNotEmpty && trExists(slug)) {
        out.add(tr(slug));
      } else if (en.isNotEmpty) {
        out.add(en);
      }
    }

    return out.toList(growable: false);
  }

  static List<String> suggest(
    String query, {
    bool includeAll = false,
    int minChars = 2,
    int limit = 12,
  }) {
    final q = _norm(query);
    if (q.length < minChars) return const [];

    final src = _allAliases(includeAll: includeAll);
    final exactStart = <String>[];
    final contains = <String>[];

    for (final city in src) {
      final c = _norm(city);
      if (c.startsWith(q)) {
        exactStart.add(city);
      } else if (c.contains(q)) {
        contains.add(city);
      }
    }

    return <String>[...exactStart, ...contains]
        .take(limit)
        .toList(growable: false);
  }

  static bool isAllowed(String value, {bool includeAll = false}) {
    final v = _norm(value);
    if (v.isEmpty) return false;

    final aliases = _allAliases(includeAll: includeAll).map(_norm).toSet();
    return aliases.contains(v);
  }

  /// Lowercase English slug: `kyiv`, `london`, `barcelona`. Used for Supabase
  /// columns, filters, and [get_videos_feed]. Returns null for empty, "all",
  /// or if input cannot be matched to the catalog.
  static String? toEnglishStorageKey(String? value) {
    if (value == null) {
      return null;
    }
    final t = value.trim();
    if (t.isEmpty) {
      return null;
    }
    for (final all in <String>[
      'all cities',
      tr('all_cities'),
      tr('filter_all_cities_alt'),
    ]) {
      if (t == all) {
        return null;
      }
    }
    final n = _norm(t);
    if (n == _norm(tr('all_cities')) ||
        n == _norm(tr('filter_all_cities_alt')) ||
        n == 'all cities') {
      return null;
    }
    for (final pair in _cityPairs) {
      final en = _pairEn(pair);
      final slug = _pairSlug(pair);
      if (en.isEmpty) {
        continue;
      }
      final localized =
          slug.isNotEmpty && trExists(slug) ? tr(slug) : '';
      if (n == _norm(en) ||
          (localized.isNotEmpty && n == _norm(localized))) {
        return _norm(en).replaceAll(' ', '_');
      }
    }
    if (n.length <= 40 && RegExp(r'^[a-z0-9_ ]+$').hasMatch(n)) {
      return n.replaceAll(' ', '_');
    }
    return null;
  }

  /// Localized label for UI. [dbValue] is English slug from the database.
  static String labelForDisplay(String? dbValue) {
    final s = (dbValue ?? '').trim();
    if (s.isEmpty) {
      return '';
    }
    final n = s.toLowerCase();
    for (final pair in _cityPairs) {
      final en = _pairEn(pair);
      final slug = _pairSlug(pair);
      if (en.isEmpty) {
        continue;
      }
      final key = _norm(en).replaceAll(' ', '_');
      if (n == key || n == _norm(en)) {
        if (slug.isNotEmpty && trExists(slug)) {
          final localized = tr(slug);
          if (localized != slug) {
            return localized;
          }
        }
        return en;
      }
    }
    final t = tr(n);
    if (t != n) {
      return t;
    }
    if (n.isNotEmpty) {
      return s[0].toUpperCase() + s.substring(1);
    }
    return s;
  }
}
