import 'package:flutter/foundation.dart';

/// Minimal in-app i18n without Flutter delegates.
/// Usage: I18n.language.addListener(...) or I18n.t('key').
class I18n {
  static final ValueNotifier<String> language = ValueNotifier<String>('uk'); // 'uk' | 'en'

  static void setLanguage(String langCode) {
    if (langCode == 'uk' || langCode == 'en') {
      language.value = langCode;
    }
  }

  static String t(String key) {
    final lang = language.value;
    final map = _strings[key];
    if (map == null) return key;
    return map[lang] ?? map['uk'] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    // General
    'app_name': {'uk': 'FLAP', 'en': 'FLAP'},
    'feel_like_a_pro': {
      'uk': 'Твоя футбольна соціальна мережа',
      'en': 'Your football social network',
    },
    'login': {'uk': 'УВІЙТИ', 'en': 'LOG IN'},
    'register': {'uk': 'РЕЄСТРАЦІЯ', 'en': 'REGISTER'},
    'videos': {'uk': 'Відео', 'en': 'Videos'},
    'challenges': {'uk': 'Челенджі', 'en': 'Challenges'},
    'matches': {'uk': 'Матчі', 'en': 'Matches'},
    'notifications': {'uk': 'Сповіщення', 'en': 'Notifications'},
    'friends': {'uk': 'Друзі', 'en': 'Friends'},

    // Matches tabs
    'find_match': {'uk': 'Знайти матч', 'en': 'Find match'},
    'my_matches': {'uk': 'Мої матчі', 'en': 'My matches'},
    'history': {'uk': 'Історія', 'en': 'History'},
    'ratings': {'uk': 'Рейтинги', 'en': 'Ratings'},

    // Common UI
    'reset_filters': {'uk': 'Скинути фільтри', 'en': 'Reset filters'},
    'city': {'uk': 'Місто', 'en': 'City'},
    'level': {'uk': 'Рівень', 'en': 'Level'},
    'time': {'uk': 'Час', 'en': 'Time'},
    'search': {'uk': 'Пошук', 'en': 'Search'},
    'rating': {'uk': 'Рейтинг', 'en': 'Rating'},
    'matches_played': {'uk': 'матчів', 'en': 'matches'},
    'unknown': {'uk': 'Невідомо', 'en': 'Unknown'},

    // Ratings
    'overall_rating': {'uk': 'Загальний рейтинг', 'en': 'Overall rating'},
    'by_city': {'uk': 'За містом', 'en': 'By city'},
    'by_position': {'uk': 'За позицією', 'en': 'By position'},
    'my_stats': {'uk': 'Моя статистика', 'en': 'My stats'},

    // Login screen
    'login_subtitle': {
      'uk': 'Увійдіть до своєї футбольної спільноти',
      'en': 'Sign in to your football community',
    },
    'email_or_phone': {'uk': 'Email або телефон', 'en': 'Email or phone'},
    'enter_email': {'uk': 'Введіть email', 'en': 'Enter email'},
    'password': {'uk': 'Пароль', 'en': 'Password'},
    'enter_password': {'uk': 'Введіть пароль', 'en': 'Enter password'},
    'password_recovery_later': {
      'uk': 'Відновлення паролю буде додано пізніше',
      'en': 'Password recovery will be added later',
    },
    'forgot_password': {'uk': 'Забули пароль?', 'en': 'Forgot password?'},
    'invalid_email_or_password': {
      'uk': 'Невірний email або пароль',
      'en': 'Invalid email or password',
    },
    'too_many_requests': {
      'uk': 'Забагато спроб. Спробуйте пізніше',
      'en': 'Too many attempts. Try again later',
    },
    'login_error': {'uk': 'Помилка входу', 'en': 'Login error'},
    'no_account_register': {
      'uk': 'Немає акаунта? Зареєструватися',
      'en': "Don't have an account? Register",
    },
  };
}


