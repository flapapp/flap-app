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
    'profile': {'uk': 'Профіль', 'en': 'Profile'},
    'settings': {'uk': 'Налаштування', 'en': 'Settings'},
    'logout': {'uk': 'Вийти', 'en': 'Logout'},
    'player': {'uk': 'Гравець', 'en': 'Player'},
    'join': {'uk': 'Приєднатися', 'en': 'Join'},
    'pay': {'uk': 'Оплатити', 'en': 'Pay'},
    'add_friend': {'uk': 'Додати друга', 'en': 'Add friend'},
    'accept': {'uk': 'Прийняти', 'en': 'Accept'},
    'reject': {'uk': 'Відхилити', 'en': 'Reject'},
    'remove': {'uk': 'Видалити', 'en': 'Remove'},
    'invite_to_match': {'uk': 'Запросити на матч', 'en': 'Invite to match'},
    'remove_friend': {'uk': 'Видалити з друзів', 'en': 'Remove friend'},
    'no_users_found': {'uk': 'Користувачів не знайдено', 'en': 'No users found'},
    'profile_not_found': {'uk': 'Профіль не знайдено', 'en': 'Profile not found'},

    // Buttons / common actions
    'create_match': {'uk': 'Створити матч', 'en': 'Create match'},
    'manage': {'uk': 'Управління', 'en': 'Manage'},
    'details': {'uk': 'Деталі', 'en': 'Details'},
    'cancel': {'uk': 'Скасувати', 'en': 'Cancel'},
    'confirm': {'uk': 'Підтвердити', 'en': 'Confirm'},
    'save': {'uk': 'Зберегти', 'en': 'Save'},
    'delete': {'uk': 'Видалити', 'en': 'Delete'},
    'edit': {'uk': 'Редагувати', 'en': 'Edit'},
    'upload': {'uk': 'Завантажити', 'en': 'Upload'},
    'submit': {'uk': 'Надіслати', 'en': 'Submit'},
    'send': {'uk': 'Надіслати', 'en': 'Send'},
    'close': {'uk': 'Закрити', 'en': 'Close'},
    'back': {'uk': 'Назад', 'en': 'Back'},
    'next': {'uk': 'Далі', 'en': 'Next'},
    'skip': {'uk': 'Пропустити', 'en': 'Skip'},
    'done': {'uk': 'Готово', 'en': 'Done'},
    'error': {'uk': 'Помилка', 'en': 'Error'},
    'success': {'uk': 'Успіх', 'en': 'Success'},
    'loading': {'uk': 'Завантаження...', 'en': 'Loading...'},
    'uploading': {'uk': 'Завантаження...', 'en': 'Uploading...'},
    'no_data': {'uk': 'Немає даних', 'en': 'No data'},
    'empty': {'uk': 'Порожньо', 'en': 'Empty'},
    'need_sign_in': {'uk': 'Потрібно увійти в систему', 'en': 'You need to sign in'},

    // Mode selection
    'select_mode': {'uk': 'Оберіть режим', 'en': 'Select mode'},
    'video_mode': {'uk': 'Режим відео', 'en': 'Video mode'},
    'matches_mode': {'uk': 'Режим матчів', 'en': 'Matches mode'},

    // Matches flow messages
    'applied_wait': {
      'uk': 'Заявку подано! Очікуйте відповіді організатора.',
      'en': 'Application sent! Wait for organizer response.'
    },
    'already_applied': {
      'uk': 'Ви вже подали заявку на участь у цьому матчі.',
      'en': 'You have already applied for this match.'
    },
    'left_match': {'uk': 'Ви вийшли з матчу', 'en': 'You have left the match'},
    'leave_failed': {'uk': 'Не вдалося вийти з матчу', 'en': 'Failed to leave the match'},
    'teams_balanced': {'uk': 'Команди сформовано', 'en': 'Teams balanced'},
    'teams_balance_failed': {'uk': 'Не вдалося сформувати команди', 'en': 'Failed to balance teams'},
    'match_started': {'uk': 'Матч розпочато', 'en': 'Match started'},
    'match_start_failed': {'uk': 'Не вдалося розпочати матч', 'en': 'Failed to start match'},
    'finish_match': {'uk': 'Завершити матч', 'en': 'Finish match'},
    'goals_team_a': {'uk': 'Голи команди A', 'en': 'Goals of Team A'},
    'goals_team_b': {'uk': 'Голи команди B', 'en': 'Goals of Team B'},
    'enter_valid_scores': {
      'uk': 'Введіть коректні рахунки',
      'en': 'Enter valid scores'
    },
    'match_finished': {'uk': 'Матч завершено', 'en': 'Match finished'},
    'match_finish_failed': {'uk': 'Не вдалося завершити матч', 'en': 'Failed to finish match'},
    'organizer': {'uk': 'Організатор', 'en': 'Organizer'},
    'participant': {'uk': 'Учасник', 'en': 'Participant'},
    'participants': {'uk': 'Учасники', 'en': 'Participants'},
    'leave_match': {'uk': 'Вийти з матчу', 'en': 'Leave match'},
    'join_match': {'uk': 'Приєднатися', 'en': 'Join'},
    'apply': {'uk': 'Подати заявку', 'en': 'Apply'},

    // Matches tabs
    'find_match': {'uk': 'Знайти матч', 'en': 'Find match'},
    'my_matches': {'uk': 'Мої матчі', 'en': 'My matches'},
    'history': {'uk': 'Історія', 'en': 'History'},
    'ratings': {'uk': 'Рейтинги', 'en': 'Ratings'},
    'all': {'uk': 'Всі', 'en': 'All'},
    'organized': {'uk': 'Організовані', 'en': 'Organized'},
    'participation': {'uk': 'Участь', 'en': 'Participation'},

    // Statuses
    'status_open': {'uk': 'Відкрито', 'en': 'Open'},
    'status_full': {'uk': 'Заповнено', 'en': 'Full'},
    'status_in_progress': {'uk': 'В процесі', 'en': 'In progress'},
    'status_finished': {'uk': 'Завершено', 'en': 'Finished'},
    'status_cancelled': {'uk': 'Скасовано', 'en': 'Cancelled'},

    // Common UI
    'reset_filters': {'uk': 'Скинути фільтри', 'en': 'Reset filters'},
    'city': {'uk': 'Місто', 'en': 'City'},
    'level': {'uk': 'Рівень', 'en': 'Level'},
    'time': {'uk': 'Час', 'en': 'Time'},
    'date': {'uk': 'Дата', 'en': 'Date'},
    'location': {'uk': 'Локація', 'en': 'Location'},
    'search': {'uk': 'Пошук', 'en': 'Search'},
    'rating': {'uk': 'Рейтинг', 'en': 'Rating'},
    'matches_played': {'uk': 'матчів', 'en': 'matches'},
    'unknown': {'uk': 'Невідомо', 'en': 'Unknown'},
    'yes': {'uk': 'Так', 'en': 'Yes'},
    'no': {'uk': 'Ні', 'en': 'No'},

    // Ratings
    'overall_rating': {'uk': 'Загальний рейтинг', 'en': 'Overall rating'},
    'by_city': {'uk': 'За містом', 'en': 'By city'},
    'by_position': {'uk': 'За позицією', 'en': 'By position'},
    'my_stats': {'uk': 'Моя статистика', 'en': 'My stats'},
    'my_rating': {'uk': 'Мій рейтинг', 'en': 'My rating'},
    'rating_history': {'uk': 'Історія рейтингу', 'en': 'Rating history'},
    'top_players': {'uk': 'Топ гравців', 'en': 'Top players'},

    // Videos
    'upload_video': {'uk': 'Завантажити відео', 'en': 'Upload video'},
    'my_videos': {'uk': 'Мої відео', 'en': 'My videos'},
    'all_videos': {'uk': 'Всі відео', 'en': 'All videos'},
    'categories': {'uk': 'Категорії', 'en': 'Categories'},
    'title': {'uk': 'Назва', 'en': 'Title'},
    'description': {'uk': 'Опис', 'en': 'Description'},
    'category': {'uk': 'Категорія', 'en': 'Category'},
    'select_video': {'uk': 'Оберіть відео', 'en': 'Select video'},
    'video_title': {'uk': 'Назва відео', 'en': 'Video title'},
    'video_description': {'uk': 'Опис відео', 'en': 'Video description'},
    'video_uploaded': {'uk': 'Відео завантажено!', 'en': 'Video uploaded!'},
    'video_upload_failed': {'uk': 'Помилка завантаження відео', 'en': 'Video upload failed'},
    'comments': {'uk': 'Коментарі', 'en': 'Comments'},
    'add_comment': {'uk': 'Додати коментар', 'en': 'Add comment'},
    'likes': {'uk': 'Лайки', 'en': 'Likes'},
    'views': {'uk': 'Перегляди', 'en': 'Views'},
    'share': {'uk': 'Поділитися', 'en': 'Share'},
    'vote': {'uk': 'Проголосувати', 'en': 'Vote'},
    'voted': {'uk': 'Проголосовано', 'en': 'Voted'},

    // Challenges
    'create_challenge': {'uk': 'Створити челендж', 'en': 'Create challenge'},
    'my_challenges': {'uk': 'Мої челенджі', 'en': 'My challenges'},
    'active_challenges': {'uk': 'Активні', 'en': 'Active'},
    'completed_challenges': {'uk': 'Завершені', 'en': 'Completed'},
    'challenge_title': {'uk': 'Назва челенджу', 'en': 'Challenge title'},
    'challenge_description': {'uk': 'Опис челенджу', 'en': 'Challenge description'},
    'prize_pool': {'uk': 'Призовий фонд', 'en': 'Prize pool'},
    'submissions': {'uk': 'Подання', 'en': 'Submissions'},
    'submit_video': {'uk': 'Подати відео', 'en': 'Submit video'},
    'vote_for_winner': {'uk': 'Голосувати', 'en': 'Vote'},
    'winner': {'uk': 'Переможець', 'en': 'Winner'},

    // Friends
    'friend_requests': {'uk': 'Запити в друзі', 'en': 'Friend requests'},
    'my_friends': {'uk': 'Мої друзі', 'en': 'My friends'},
    'find_friends': {'uk': 'Знайти друзів', 'en': 'Find friends'},
    'friend_added': {'uk': 'Друга додано', 'en': 'Friend added'},
    'request_sent': {'uk': 'Запит надіслано', 'en': 'Request sent'},

    // Profile
    'edit_profile': {'uk': 'Редагувати профіль', 'en': 'Edit profile'},
    'my_profile': {'uk': 'Мій профіль', 'en': 'My profile'},
    'display_name': {'uk': 'Ім\'я', 'en': 'Display name'},
    'email': {'uk': 'Email', 'en': 'Email'},
    'phone': {'uk': 'Телефон', 'en': 'Phone'},
    'position': {'uk': 'Позиція', 'en': 'Position'},
    'avatar': {'uk': 'Аватар', 'en': 'Avatar'},
    'change_avatar': {'uk': 'Змінити аватар', 'en': 'Change avatar'},
    'stats': {'uk': 'Статистика', 'en': 'Stats'},
    'achievements': {'uk': 'Досягнення', 'en': 'Achievements'},
    'badges': {'uk': 'Значки', 'en': 'Badges'},

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

    // Register screen
    'create_account': {'uk': 'Створити акаунт', 'en': 'Create account'},
    'full_name': {'uk': 'Повне ім\'я', 'en': 'Full name'},
    'enter_name': {'uk': 'Введіть ім\'я', 'en': 'Enter name'},
    'confirm_password': {'uk': 'Підтвердіть пароль', 'en': 'Confirm password'},
    'passwords_dont_match': {'uk': 'Паролі не співпадають', 'en': 'Passwords don\'t match'},
    'already_have_account': {'uk': 'Вже є акаунт? Увійти', 'en': 'Already have an account? Log in'},

    // Notifications
    'no_notifications': {'uk': 'Немає сповіщень', 'en': 'No notifications'},
    'mark_read': {'uk': 'Позначити прочитаним', 'en': 'Mark as read'},
    'clear_all': {'uk': 'Очистити всі', 'en': 'Clear all'},

    // Coins & Subscription
    'my_coins': {'uk': 'Мої монети', 'en': 'My coins'},
    'coins': {'uk': 'Монети', 'en': 'Coins'},
    'subscription': {'uk': 'Підписка', 'en': 'Subscription'},
    'upgrade': {'uk': 'Підвищити', 'en': 'Upgrade'},
    'premium': {'uk': 'Преміум', 'en': 'Premium'},

    // Errors & validation
    'field_required': {'uk': 'Поле обов\'язкове', 'en': 'Field is required'},
    'invalid_email': {'uk': 'Невірний email', 'en': 'Invalid email'},
    'invalid_phone': {'uk': 'Невірний телефон', 'en': 'Invalid phone'},
    'something_went_wrong': {'uk': 'Щось пішло не так', 'en': 'Something went wrong'},
    'try_again': {'uk': 'Спробуйте ще раз', 'en': 'Try again'},
    'connection_error': {'uk': 'Помилка з\'єднання', 'en': 'Connection error'},

    // Extended keys
    'all_tab': {'uk': 'Всі', 'en': 'All'},
    'trending': {'uk': 'Тренди', 'en': 'Trending'},
    'my': {'uk': 'Мої', 'en': 'My'},
    'all_cities': {'uk': 'Всі міста', 'en': 'All cities'},
    'kyiv': {'uk': 'Київ', 'en': 'Kyiv'},
    'lviv': {'uk': 'Львів', 'en': 'Lviv'},
    'odesa': {'uk': 'Одеса', 'en': 'Odesa'},
    'kharkiv': {'uk': 'Харків', 'en': 'Kharkiv'},
    'dnipro': {'uk': 'Дніпро', 'en': 'Dnipro'},
    'all_categories': {'uk': 'Всі категорії', 'en': 'All categories'},
    'technique': {'uk': 'Техніка', 'en': 'Technique'},
    'physics': {'uk': 'Фізика', 'en': 'Physics'},
    'tactics': {'uk': 'Тактика', 'en': 'Tactics'},
    'teamplay': {'uk': 'Командна гра', 'en': 'Teamplay'},
    'freestyle': {'uk': 'Фрістайл', 'en': 'Freestyle'},
    'other': {'uk': 'Інше', 'en': 'Other'},
    'all_ratings': {'uk': 'Всі рейтинги', 'en': 'All ratings'},
    'all_levels': {'uk': 'Всі рівні', 'en': 'All levels'},
    'beginner': {'uk': 'Початковий', 'en': 'Beginner'},
    'intermediate': {'uk': 'Середній', 'en': 'Intermediate'},
    'advanced': {'uk': 'Високий', 'en': 'Advanced'},
    'professional': {'uk': 'Професійний', 'en': 'Professional'},
    'anytime': {'uk': 'Будь-коли', 'en': 'Anytime'},
    'city_label': {'uk': '🏙️ Місто', 'en': '🏙️ City'},
    'level_label': {'uk': '📊 Рівень', 'en': '📊 Level'},
    'time_label': {'uk': '⏰ Час', 'en': '⏰ Time'},
    'search_label': {'uk': '🔍 Пошук', 'en': '🔍 Search'},
    'search_matches': {'uk': 'Пошук матчів...', 'en': 'Search matches...'},
    'match_history': {'uk': '📊 Історія матчів', 'en': '📊 Match history'},
    'match_history_empty': {'uk': 'Історія матчів порожня', 'en': 'Match history is empty'},
    'ratings_title': {'uk': 'Рейтинги', 'en': 'Ratings'},
    'top_players_label': {'uk': '🏆 Топ гравці', 'en': '🏆 Top players'},
    'current_rating': {'uk': 'Поточний рейтинг', 'en': 'Current rating'},
    'match_rating_70': {'uk': 'Рейтинг з матчів (70%)', 'en': 'Match rating (70%)'},
    'video_rating_30': {'uk': 'Рейтинг з відео/челенджів (30%)', 'en': 'Video/challenge rating (30%)'},
    'average_rating': {'uk': 'Середній рейтинг', 'en': 'Average rating'},
    'level_colon': {'uk': 'Рівень:', 'en': 'Level:'},
    'your_rating': {'uk': 'Ваш рейтинг:', 'en': 'Your rating:'},
    'score': {'uk': 'Рахунок:', 'en': 'Score:'},
    'match_details': {'uk': 'Деталі матчу', 'en': 'Match details'},
    'rate_players': {'uk': 'Оцінити гравців', 'en': 'Rate players'},
    'leave_match_confirm': {'uk': 'Вийти з матчу?', 'en': 'Leave match?'},
    'leave_match_sure': {'uk': 'Ви впевнені, що хочете вийти?', 'en': 'Are you sure you want to leave?'},
    'leaving': {'uk': 'Вихід…', 'en': 'Leaving…'},
    'mode_colon': {'uk': 'Режим:', 'en': 'Mode:'},
    'simple': {'uk': 'Простий', 'en': 'Simple'},
    'advanced_mode': {'uk': 'Розширений', 'en': 'Advanced'},
    'rate_all_for_fair': {
      'uk': 'Оцініть всіх гравців для справедливого рейтингу',
      'en': 'Rate all players for fair rating'
    },
    'my_matches_title': {'uk': '⚽ Мої матчі', 'en': '⚽ My matches'},
    'goto_my_matches': {'uk': 'Перейти до моїх матчів', 'en': 'Go to my matches'},
    'my_videos_title': {'uk': '🎬 Мої відео', 'en': '🎬 My videos'},
    'view_uploaded_videos': {'uk': 'Переглянути завантажені відео', 'en': 'View uploaded videos'},
    'my_challenges_title': {'uk': '🏆 Мої челенджі', 'en': '🏆 My challenges'},
    'view_challenges': {'uk': 'Переглянути створені челенджі', 'en': 'View created challenges'},
    'statistics_title': {'uk': '📊 Статистика', 'en': '📊 Statistics'},
    'detailed_statistics': {'uk': 'Детальна статистика гравця', 'en': 'Detailed player statistics'},
    'subscriptions_title': {'uk': '👑 Підписки', 'en': '👑 Subscriptions'},
    'manage_subscription': {'uk': 'Керувати підпискою та планами', 'en': 'Manage subscription and plans'},
    'settings_title': {'uk': '⚙️ Налаштування', 'en': '⚙️ Settings'},
    'profile_settings': {'uk': 'Налаштування профілю', 'en': 'Profile settings'},
    'logout_title': {'uk': '🚪 Вийти', 'en': '🚪 Logout'},
    'logout_from_account': {'uk': 'Вийти з акаунту', 'en': 'Logout from account'},
    'logout_confirm': {'uk': 'Вийти з акаунту?', 'en': 'Logout from account?'},
    'friends_count': {'uk': 'Друзі', 'en': 'Friends'},
    'invitations': {'uk': 'Запрошення', 'en': 'Invitations'},
    'sent': {'uk': 'Надіслані', 'en': 'Sent'},
    'manage_friends': {'uk': 'Керування друзями', 'en': 'Manage friends'},
    'no_rating_history': {
      'uk': 'Поки що немає історії змін рейтингу',
      'en': 'No rating history yet'
    },
    'top_videos_by_views': {'uk': 'Топ відео за переглядами', 'en': 'Top videos by views'},
    'first_goal': {'uk': 'Перший гол', 'en': 'First goal'},
    'victory': {'uk': 'Перемога', 'en': 'Victory'},
    'defeat': {'uk': 'Поразка', 'en': 'Defeat'},
    'draw': {'uk': 'Нічия', 'en': 'Draw'},
    'badges_title': {'uk': 'Значки', 'en': 'Badges'},
    'current_subscription': {'uk': 'Поточна підписка', 'en': 'Current subscription'},
    'available_plans': {'uk': 'Доступні плани', 'en': 'Available plans'},
    'free_plan': {'uk': 'Безкоштовна', 'en': 'Free'},
    'choose_plan': {'uk': 'ОБРАТИ ПЛАН', 'en': 'CHOOSE PLAN'},
    'cancel_subscription': {'uk': 'Скасувати підписку', 'en': 'Cancel subscription'},
    'join_challenge': {'uk': 'Прийняти участь', 'en': 'Join'},
    'participant_videos': {'uk': 'Відео учасників:', 'en': 'Participant videos:'},
    'days_left': {'uk': 'Залишилось:', 'en': 'Days left:'},
    'days': {'uk': 'днів', 'en': 'days'},
    'active_status': {'uk': 'АКТИВНА', 'en': 'ACTIVE'},
    'overall_rating_tab': {'uk': 'Загальний рейтинг', 'en': 'Overall rating'},
    'by_city_tab': {'uk': 'За містом', 'en': 'By city'},
    'by_position_tab': {'uk': 'За позицією', 'en': 'By position'},
    'my_stats_tab': {'uk': 'Моя статистика', 'en': 'My stats'},
    'view': {'uk': 'Переглянути', 'en': 'View'},
  };
}


