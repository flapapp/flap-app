import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import 'app_navigator_key.dart';

/// [EasyLocalization] is below [MaterialApp]; use the root [Navigator] context.
Locale? get currentAppLocaleOrNull {
  final c = appNavigatorKey.currentContext;
  if (c == null) return null;
  return EasyLocalization.of(c)?.locale;
}

/// `uk` / `en` when the app is up; defaults to `en` if context is unavailable.
String currentAppLanguageCode() =>
    currentAppLocaleOrNull?.languageCode ?? 'en';

/// Ukrainian vs English string pair (dynamic templates with `$` interpolation).
/// Prefer adding keys to `assets/translations` and using [tr] when possible.
String bilingual(String uk, String en) =>
    currentAppLanguageCode() == 'uk' ? uk : en;
