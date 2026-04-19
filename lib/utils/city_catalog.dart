import 'dart:collection';

import 'package:easy_localization/easy_localization.dart';

class CityCatalog {
  static const List<Map<String, String>> _cityPairs = <Map<String, String>>[
    {'uk': 'Київ', 'en': 'Kyiv'},
    {'uk': 'Львів', 'en': 'Lviv'},
    {'uk': 'Одеса', 'en': 'Odesa'},
    {'uk': 'Харків', 'en': 'Kharkiv'},
    {'uk': 'Дніпро', 'en': 'Dnipro'},
    {'uk': 'Барселона', 'en': 'Barcelona'},
    {'uk': 'Мадрид', 'en': 'Madrid'},
    {'uk': 'Валенсія', 'en': 'Valencia'},
    {'uk': 'Лондон', 'en': 'London'},
    {'uk': 'Берлін', 'en': 'Berlin'},
    {'uk': 'Варшава', 'en': 'Warsaw'},
    {'uk': 'Прага', 'en': 'Prague'},
    {'uk': 'Париж', 'en': 'Paris'},
    {'uk': 'Рим', 'en': 'Rome'},
    {'uk': 'Лісабон', 'en': 'Lisbon'},
  ];

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<String> _allAliases({bool includeAll = false}) {
    final set = LinkedHashSet<String>();

    for (final pair in _cityPairs) {
      final uk = (pair['uk'] ?? '').trim();
      final en = (pair['en'] ?? '').trim();
      if (uk.isNotEmpty) set.add(uk);
      if (en.isNotEmpty) set.add(en);
    }

    if (includeAll) {
      // accept both languages for "all cities"
      set.add('Всі міста');
      set.add('All cities');
      set.add(tr('all_cities'));
    }

    return set.toList(growable: false);
  }

  static List<String> cities({bool includeAll = false}) {
    final aliases = _allAliases(includeAll: includeAll);
    return aliases;
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
}