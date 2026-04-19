import 'package:easy_localization/easy_localization.dart';

/// Maps stored city names to [tr] keys in `assets/translations`.
String localizeCity(String cityName) {
  if (cityName.isEmpty) {
    return tr('unknown_city');
  }
  const keyByStored = <String, String>{
    'Київ': 'kyiv',
    'Харків': 'kharkiv',
    'Одеса': 'odesa',
    'Дніпро': 'dnipro',
    'Львів': 'lviv',
    'Kyiv': 'kyiv',
    'Kharkiv': 'kharkiv',
    'Odesa': 'odesa',
    'Dnipro': 'dnipro',
    'Lviv': 'lviv',
  };
  final key = keyByStored[cityName];
  if (key != null) {
    return tr(key);
  }
  return cityName;
}
