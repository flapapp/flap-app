import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/i18n.dart';

class Badge {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int price;
  final String category;
  final bool isAvailable;
  final DateTime? releaseDate;

  Badge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.price,
    required this.category,
    this.isAvailable = true,
    this.releaseDate,
  });

  // Factory constructor from Firestore
  factory Badge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Badge(
      id: doc.id,
      name: data['name'] ?? '',
      emoji: data['emoji'] ?? '🏆',
      description: data['description'] ?? '',
      price: data['price'] ?? 0,
      category: data['category'] ?? 'general',
      isAvailable: data['isAvailable'] ?? true,
      releaseDate: data['releaseDate'] != null 
          ? (data['releaseDate'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'emoji': emoji,
      'description': description,
      'price': price,
      'category': category,
      'isAvailable': isAvailable,
      'releaseDate': releaseDate != null 
          ? Timestamp.fromDate(releaseDate!) 
          : null,
    };
  }

  // Copy with changes
  Badge copyWith({
    String? id,
    String? name,
    String? emoji,
    String? description,
    int? price,
    String? category,
    bool? isAvailable,
    DateTime? releaseDate,
  }) {
    return Badge(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      releaseDate: releaseDate ?? this.releaseDate,
    );
  }

  // Badge color based on category
  int get categoryColor {
    switch (category) {
      case 'starter':
        return 0xFF4CAF50; // Green
      case 'skill':
        return 0xFF2196F3; // Blue
      case 'achievement':
        return 0xFFFF9800; // Orange
      case 'legendary':
        return 0xFF9C27B0; // Purple
      case 'special':
        return 0xFFE91E63; // Pink
      default:
        return 0xFF757575; // Gray
    }
  }

  // Badge rarity text
  String get rarityText {
    switch (category) {
      case 'starter':
        return I18n.inline('Початковий', 'Starter');
      case 'skill':
        return I18n.inline('Навичка', 'Skill');
      case 'achievement':
        return I18n.inline('Досягнення', 'Achievement');
      case 'legendary':
        return I18n.inline('Легендарний', 'Legendary');
      case 'special':
        return I18n.inline('Спеціальний', 'Special');
      default:
        return I18n.inline('Звичайний', 'Common');
    }
  }

  // Localized name
  String get localizedName {
    return _getLocalizedName(id, name);
  }

  // Localized description
  String get localizedDescription {
    return _getLocalizedDescription(id, description);
  }

  // Helper method to get localized badge name
  static String _getLocalizedName(String id, String defaultName) {
    final lang = I18n.language.value;
    final skillData = _skillLocalizations[id];
    if (skillData != null) {
      return lang == 'uk'
          ? skillData['name_uk'] ?? defaultName
          : skillData['name_en'] ?? defaultName;
    }
    final Map<String, Map<String, String>> badgeNames = {
      'rookie': {'uk': 'Новачок', 'en': 'Rookie'},
      'first_goal': {'uk': 'Перший гол', 'en': 'First Goal'},
      'striker': {'uk': 'Бомбардир', 'en': 'Striker'},
      'defender': {'uk': 'Захисник', 'en': 'Defender'},
      'playmaker': {'uk': 'Плеймейкер', 'en': 'Playmaker'},
      'goalkeeper': {'uk': 'Воротар', 'en': 'Goalkeeper'},
      'speedster': {'uk': 'Спідстер', 'en': 'Speedster'},
      'trickster': {'uk': 'Фінтер', 'en': 'Trickster'},
      'social': {'uk': 'Соціальний', 'en': 'Social'},
      'challenger': {'uk': 'Челенджер', 'en': 'Challenger'},
      'perfectionist': {'uk': 'Перфекціоніст', 'en': 'Perfectionist'},
      'veteran': {'uk': 'Ветеран', 'en': 'Veteran'},
      'legend': {'uk': 'Легенда', 'en': 'Legend'},
      'champion': {'uk': 'Чемпіон', 'en': 'Champion'},
      'hall_of_fame': {'uk': 'Зала слави', 'en': 'Hall of Fame'},
      'dribbling_skill': {'uk': 'Дриблінг', 'en': 'Dribbling'},
      'passing_skill': {'uk': 'Пас', 'en': 'Passing'},
      'shooting_skill': {'uk': 'Удар', 'en': 'Shooting'},
      'strength_skill': {'uk': 'Сила', 'en': 'Strength'},
      'stamina_skill': {'uk': 'Витривалість', 'en': 'Stamina'},
      'intelligence_skill': {'uk': 'Футбольний інтелект', 'en': 'Football Intelligence'},
      'defense_skill': {'uk': 'Захист', 'en': 'Defense'},
      'tackling_skill': {'uk': 'Підкат', 'en': 'Tackling'},
      'technique_skill': {'uk': 'Техніка', 'en': 'Technique'},
      'accuracy_skill': {'uk': 'Точність', 'en': 'Accuracy'},
      'finishing_skill': {'uk': 'Реалізація', 'en': 'Finishing'},
      'leadership_skill': {'uk': 'Лідерство', 'en': 'Leadership'},
      'saves_skill': {'uk': 'Сейв', 'en': 'Saves'},
      'reaction_skill': {'uk': 'Реакція', 'en': 'Reaction'},
      'penalty_skill': {'uk': 'Пенальті', 'en': 'Penalty'},
      'freekick_skill': {'uk': 'Штрафні', 'en': 'Free Kick'},
      'speed_skill': {'uk': 'Швидкість', 'en': 'Speed'},
    };
    
    return badgeNames[id]?[lang] ?? defaultName;
  }

  // Helper method to get localized badge description
  static String _getLocalizedDescription(String id, String defaultDescription) {
    final lang = I18n.language.value;
    final skillData = _skillLocalizations[id];
    if (skillData != null) {
      return lang == 'uk'
          ? skillData['desc_uk'] ?? defaultDescription
          : skillData['desc_en'] ?? defaultDescription;
    }
    final Map<String, Map<String, String>> badgeDescriptions = {
      'rookie': {'uk': 'Перший крок у світ FLAP', 'en': 'First step into FLAP world'},
      'first_goal': {'uk': 'Забили свій перший гол!', 'en': 'Scored your first goal!'},
      'striker': {'uk': 'Майстер голевих моментів', 'en': 'Master of goal moments'},
      'defender': {'uk': 'Надійний як скеля', 'en': 'Reliable as a rock'},
      'playmaker': {'uk': 'Майстер асистів і передач', 'en': 'Master of assists and passes'},
      'goalkeeper': {'uk': 'Непереможний страж воріт', 'en': 'Invincible gatekeeper'},
      'speedster': {'uk': 'Швидкий як блискавка', 'en': 'Fast as lightning'},
      'trickster': {'uk': 'Майстер технічних фінтів', 'en': 'Master of technical skills'},
      'social': {'uk': 'Душа команди та спільноти', 'en': 'Soul of team and community'},
      'challenger': {'uk': 'Переможець 10+ челенджів', 'en': 'Winner of 10+ challenges'},
      'perfectionist': {'uk': 'Середня оцінка відео 4.5+', 'en': 'Average video rating 4.5+'},
      'veteran': {'uk': 'Досвідчений гравець FLAP', 'en': 'Experienced FLAP player'},
      'legend': {'uk': 'Легенда футбольного світу', 'en': 'Legend of football world'},
      'champion': {'uk': 'Найкращий з найкращих', 'en': 'Best of the best'},
      'hall_of_fame': {'uk': 'Увійшли в залу слави FLAP', 'en': 'Entered FLAP Hall of Fame'},
      'dribbling_skill': {'uk': 'Майстерність обведення', 'en': 'Dribbling mastery'},
      'passing_skill': {'uk': 'Точність передач', 'en': 'Passing accuracy'},
      'shooting_skill': {'uk': 'Потужність удару', 'en': 'Shot power'},
      'strength_skill': {'uk': 'Фізична сила', 'en': 'Physical strength'},
      'stamina_skill': {'uk': 'Витривалість на полі', 'en': 'Stamina on the field'},
      'intelligence_skill': {'uk': 'Тактичне мислення', 'en': 'Tactical thinking'},
      'defense_skill': {'uk': 'Оборонна майстерність', 'en': 'Defensive mastery'},
      'tackling_skill': {'uk': 'Майстерність відбору м\'яча', 'en': 'Ball tackling mastery'},
      'technique_skill': {'uk': 'Технічна майстерність', 'en': 'Technical mastery'},
      'accuracy_skill': {'uk': 'Точність виконання', 'en': 'Execution accuracy'},
      'finishing_skill': {'uk': 'Ефективність у завершенні атак', 'en': 'Attack finishing efficiency'},
      'leadership_skill': {'uk': 'Лідерські якості', 'en': 'Leadership qualities'},
      'saves_skill': {'uk': 'Майстерність воротаря', 'en': 'Goalkeeper mastery'},
      'reaction_skill': {'uk': 'Швидкість реакції', 'en': 'Reaction speed'},
      'penalty_skill': {'uk': 'Майстерність одинадцятиметрових', 'en': 'Penalty kick mastery'},
      'freekick_skill': {'uk': 'Майстерність штрафних ударів', 'en': 'Free kick mastery'},
      'speed_skill': {'uk': 'Швидкість пересування', 'en': 'Movement speed'},
    };
    
    return badgeDescriptions[id]?[lang] ?? defaultDescription;
  }

  // Default badges list
  static List<Badge> getDefaultBadges() {
    return [
      Badge(
        id: 'rookie',
        name: 'Новачок',
        emoji: '🌟',
        description: 'Перший крок у світ FLAP',
        price: 50,
        category: 'starter',
      ),
      Badge(
        id: 'first_goal',
        name: 'Перший гол',
        emoji: '⚽',
        description: 'Забили свій перший гол!',
        price: 30,
        category: 'starter',
      ),
      Badge(
        id: 'striker',
        name: 'Бомбардир',
        emoji: '🔥',
        description: 'Майстер голевих моментів',
        price: 120,
        category: 'skill',
      ),
      Badge(
        id: 'defender',
        name: 'Захисник',
        emoji: '🛡️',
        description: 'Надійний як скеля',
        price: 100,
        category: 'skill',
      ),
      Badge(
        id: 'playmaker',
        name: 'Плеймейкер',
        emoji: '🎯',
        description: 'Майстер асистів і передач',
        price: 140,
        category: 'skill',
      ),
      Badge(
        id: 'goalkeeper',
        name: 'Воротар',
        emoji: '🥅',
        description: 'Непереможний страж воріт',
        price: 110,
        category: 'skill',
      ),
      Badge(
        id: 'speedster',
        name: 'Спідстер',
        emoji: '⚡',
        description: 'Швидкий як блискавка',
        price: 90,
        category: 'skill',
      ),
      Badge(
        id: 'trickster',
        name: 'Фінтер',
        emoji: '🎪',
        description: 'Майстер технічних фінтів',
        price: 130,
        category: 'achievement',
      ),
      Badge(
        id: 'social',
        name: 'Соціальний',
        emoji: '👥',
        description: 'Душа команди та спільноти',
        price: 80,
        category: 'special',
      ),
      Badge(
        id: 'challenger',
        name: 'Челенджер',
        emoji: '🎖️',
        description: 'Переможець 10+ челенджів',
        price: 180,
        category: 'achievement',
      ),
      Badge(
        id: 'perfectionist',
        name: 'Перфекціоніст',
        emoji: '💎',
        description: 'Середня оцінка відео 4.5+',
        price: 200,
        category: 'achievement',
      ),
      Badge(
        id: 'veteran',
        name: 'Ветеран',
        emoji: '⭐',
        description: 'Досвідчений гравець FLAP',
        price: 250,
        category: 'legendary',
      ),
      Badge(
        id: 'legend',
        name: 'Легенда',
        emoji: '👑',
        description: 'Легенда футбольного світу',
        price: 300,
        category: 'legendary',
      ),
      Badge(
        id: 'champion',
        name: 'Чемпіон',
        emoji: '🏆',
        description: 'Найкращий з найкращих',
        price: 400,
        category: 'legendary',
      ),
      Badge(
        id: 'hall_of_fame',
        name: 'Зала слави',
        emoji: '🌟',
        description: 'Увійшли в залу слави FLAP',
        price: 500,
        category: 'legendary',
      ),
      ..._skillLocalizations.entries.map(
        (entry) => Badge(
          id: entry.key,
          name: entry.value['name_uk']!,
          emoji: entry.value['emoji']!,
          description: entry.value['desc_uk']!,
          price: 10,
          category: 'skill',
        ),
      ),
    ];
  }
}

const Map<String, Map<String, String>> _skillLocalizations = {
  'dribbling_skill': {
    'emoji': '🕺',
    'name_uk': 'Дриблінг',
    'name_en': 'Dribbling',
    'desc_uk': 'Майстерність обведення суперника',
    'desc_en': 'Ability to glide past defenders',
  },
  'passing_skill': {
    'emoji': '🎯',
    'name_uk': 'Пас',
    'name_en': 'Passing',
    'desc_uk': 'Точні різнопланові передачі',
    'desc_en': 'Pinpoint short and long passing',
  },
  'shooting_skill': {
    'emoji': '💥',
    'name_uk': 'Удар',
    'name_en': 'Shooting',
    'desc_uk': 'Потужні та точні удари',
    'desc_en': 'Powerful and accurate strikes',
  },
  'strength_skill': {
    'emoji': '💪',
    'name_uk': 'Сила',
    'name_en': 'Strength',
    'desc_uk': 'Виграє єдиноборства корпусом',
    'desc_en': 'Dominates physical duels',
  },
  'stamina_skill': {
    'emoji': '🏃',
    'name_uk': 'Витривалість',
    'name_en': 'Stamina',
    'desc_uk': 'Біжить до фінального свистка',
    'desc_en': 'Keeps running until the whistle',
  },
  'intelligence_skill': {
    'emoji': '🧠',
    'name_uk': 'Футбольний інтелект',
    'name_en': 'Football IQ',
    'desc_uk': 'Читає гру на кілька кроків вперед',
    'desc_en': 'Reads the game several steps ahead',
  },
  'defense_skill': {
    'emoji': '🛡️',
    'name_uk': 'Захист',
    'name_en': 'Defense',
    'desc_uk': 'Надійна оборонна позиція',
    'desc_en': 'Rock-solid defensive positioning',
  },
  'tackling_skill': {
    'emoji': '🦵',
    'name_uk': 'Підкат',
    'name_en': 'Tackling',
    'desc_uk': 'Чисті відбори у складних моментах',
    'desc_en': 'Clean tackles in tight spots',
  },
  'technique_skill': {
    'emoji': '⚙️',
    'name_uk': 'Техніка',
    'name_en': 'Technique',
    'desc_uk': 'Відмінний контроль м’яча',
    'desc_en': 'Silky ball control',
  },
  'accuracy_skill': {
    'emoji': '🎲',
    'name_uk': 'Точність',
    'name_en': 'Accuracy',
    'desc_uk': 'Влучає куди потрібно',
    'desc_en': 'Hits the intended spot',
  },
  'finishing_skill': {
    'emoji': '🥅',
    'name_uk': 'Реалізація',
    'name_en': 'Finishing',
    'desc_uk': 'Перетворює моменти на голи',
    'desc_en': 'Turns chances into goals',
  },
  'leadership_skill': {
    'emoji': '👔',
    'name_uk': 'Лідерство',
    'name_en': 'Leadership',
    'desc_uk': 'Надихає партнерів на полі',
    'desc_en': 'Inspires teammates on the pitch',
  },
  'saves_skill': {
    'emoji': '🧤',
    'name_uk': 'Сейв',
    'name_en': 'Shot-stopper',
    'desc_uk': 'Витягує небезпечні удари',
    'desc_en': 'Parries unstoppable shots',
  },
  'reaction_skill': {
    'emoji': '⚡',
    'name_uk': 'Реакція',
    'name_en': 'Reaction',
    'desc_uk': 'Миттєво реагує на зміни',
    'desc_en': 'Instantly reacts to chaos',
  },
  'penalty_skill': {
    'emoji': '🎯',
    'name_uk': 'Пенальті',
    'name_en': 'Penalty',
    'desc_uk': 'Холоднокровність з точки',
    'desc_en': 'Ice-cold from the spot',
  },
  'freekick_skill': {
    'emoji': '🌪️',
    'name_uk': 'Штрафні',
    'name_en': 'Free-kick',
    'desc_uk': 'Згинає траєкторію як хоче',
    'desc_en': 'Bends it at will',
  },
  'speed_skill': {
    'emoji': '🚀',
    'name_uk': 'Швидкість',
    'name_en': 'Speed',
    'desc_uk': 'Вибуховий старт і спринт',
    'desc_en': 'Explosive pace and sprinting',
  },
  'longshot_skill': {
    'emoji': '🎇',
    'name_uk': 'Дальній удар',
    'name_en': 'Long shot',
    'desc_uk': 'Посилає ракети здалеку',
    'desc_en': 'Launches rockets from range',
  },
  'volley_skill': {
    'emoji': '🥏',
    'name_uk': 'Волей',
    'name_en': 'Volley',
    'desc_uk': 'Б’є з льоту без підготовки',
    'desc_en': 'Hits volleys without prep',
  },
  'chip_skill': {
    'emoji': '🍟',
    'name_uk': 'Чіп',
    'name_en': 'Chip shot',
    'desc_uk': 'Перекидає воротаря м’яко',
    'desc_en': 'Lobs keepers with ease',
  },
  'curve_skill': {
    'emoji': '🌈',
    'name_uk': 'Закрут',
    'name_en': 'Curler',
    'desc_uk': 'Крутить м’яч навколо стінки',
    'desc_en': 'Swings the ball around walls',
  },
  'cross_skill': {
    'emoji': '📐',
    'name_uk': 'Навіс',
    'name_en': 'Crossing',
    'desc_uk': 'Постачає ідеальні навіси',
    'desc_en': 'Drops dimes into the box',
  },
  'vision_skill': {
    'emoji': '👀',
    'name_uk': 'Бачення поля',
    'name_en': 'Vision',
    'desc_uk': 'Помічає приховані коридори',
    'desc_en': 'Spots unseen passing lanes',
  },
  'pressing_skill': {
    'emoji': '🧲',
    'name_uk': 'Пресинг',
    'name_en': 'Pressing',
    'desc_uk': 'Змушує суперника помилятись',
    'desc_en': 'Forces mistakes high up',
  },
  'marking_skill': {
    'emoji': '📎',
    'name_uk': 'Опіка',
    'name_en': 'Marking',
    'desc_uk': 'Не відпускає опонента ні на крок',
    'desc_en': 'Sticks tight to attackers',
  },
  'interception_skill': {
    'emoji': '✋',
    'name_uk': 'Перехоплення',
    'name_en': 'Interception',
    'desc_uk': 'Читає передачі суперника',
    'desc_en': 'Cuts out dangerous passes',
  },
  'clearance_skill': {
    'emoji': '🧱',
    'name_uk': 'Винос',
    'name_en': 'Clearance',
    'desc_uk': 'Очищає штрафний майданчик',
    'desc_en': 'Cleans the penalty area',
  },
  'slide_skill': {
    'emoji': '🛷',
    'name_uk': 'Ковзний відбір',
    'name_en': 'Slide tackle',
    'desc_uk': 'Чисті підкати без фолу',
    'desc_en': 'Perfect sliding challenges',
  },
  'positioning_skill': {
    'emoji': '📍',
    'name_uk': 'Позиція',
    'name_en': 'Positioning',
    'desc_uk': 'Завжди у правильній зоні',
    'desc_en': 'Always in the right pocket',
  },
  'composure_skill': {
    'emoji': '🧊',
    'name_uk': 'Холоднокровність',
    'name_en': 'Composure',
    'desc_uk': 'Спокій під тиском',
    'desc_en': 'Calm under pressure',
  },
  'clutch_skill': {
    'emoji': '⚓',
    'name_uk': 'Клатч',
    'name_en': 'Clutch',
    'desc_uk': 'Вирішує матч у вирішальний момент',
    'desc_en': 'Delivers when it matters most',
  },
  'resilience_skill': {
    'emoji': '🩹',
    'name_uk': 'Нескорений',
    'name_en': 'Resilience',
    'desc_uk': 'Встає після жорстких зіткнень',
    'desc_en': 'Bounces back from hits',
  },
  'balance_skill': {
    'emoji': '⚖️',
    'name_uk': 'Баланс',
    'name_en': 'Balance',
    'desc_uk': 'Тримається на ногах у боротьбі',
    'desc_en': 'Stays upright in duels',
  },
  'agility_skill': {
    'emoji': '🤸',
    'name_uk': 'Гнучкість',
    'name_en': 'Agility',
    'desc_uk': 'Різко змінює напрямок',
    'desc_en': 'Rapidly shifts directions',
  },
  'heading_power_skill': {
    'emoji': '🧱',
    'name_uk': 'Силовий удар головою',
    'name_en': 'Power Header',
    'desc_uk': 'Розстрілює ворота головою',
    'desc_en': 'Thunders headers on goal',
  },
  'heading_precision_skill': {
    'emoji': '🎯',
    'name_uk': 'Точний удар головою',
    'name_en': 'Accurate Header',
    'desc_uk': 'Спрямовує м’яч у кутки',
    'desc_en': 'Places headers into corners',
  },
  'long_throw_skill': {
    'emoji': '🏹',
    'name_uk': 'Довгий аут',
    'name_en': 'Long throw',
    'desc_uk': 'Запускає аути як удари',
    'desc_en': 'Launches throw-ins deep',
  },
  'throwin_skill': {
    'emoji': '🤾',
    'name_uk': 'Аут',
    'name_en': 'Throw-in',
    'desc_uk': 'Швидко вводить м’яч у гру',
    'desc_en': 'Restarts play instantly',
  },
  'short_pass_skill': {
    'emoji': '🔗',
    'name_uk': 'Короткий пас',
    'name_en': 'Short passing',
    'desc_uk': 'Будує комбінації на малих просторах',
    'desc_en': 'Builds play in tight spaces',
  },
  'long_pass_skill': {
    'emoji': '🛰️',
    'name_uk': 'Довгий пас',
    'name_en': 'Long passing',
    'desc_uk': 'Змінює фланг одним пасом',
    'desc_en': 'Switches play effortlessly',
  },
  'one_touch_skill': {
    'emoji': '☝️',
    'name_uk': 'В один дотик',
    'name_en': 'One-touch',
    'desc_uk': 'Розганяє комбінації першим дотиком',
    'desc_en': 'Accelerates play first time',
  },
  'two_footed_skill': {
    'emoji': '🦶',
    'name_uk': 'Двуногий',
    'name_en': 'Two-footed',
    'desc_uk': 'Володіє обома ногами однаково',
    'desc_en': 'Equally strong with both feet',
  },
  'weak_foot_skill': {
    'emoji': '🦵',
    'name_uk': 'Слабка нога',
    'name_en': 'Weaker foot',
    'desc_uk': 'Прокачав слабшу ногу',
    'desc_en': 'Boosted weaker-foot ability',
  },
  'first_touch_skill': {
    'emoji': '🎾',
    'name_uk': 'Перший дотик',
    'name_en': 'First touch',
    'desc_uk': 'Прийом м’яча на рівні еліти',
    'desc_en': 'Elite-level ball reception',
  },
  'hold_up_skill': {
    'emoji': '🪨',
    'name_uk': 'Утримання м’яча',
    'name_en': 'Hold-up play',
    'desc_uk': 'Прикриває м’яч корпусом для партнерів',
    'desc_en': 'Shields the ball for teammates',
  },
  'linkup_skill': {
    'emoji': '🔁',
    'name_uk': 'Комбінаторика',
    'name_en': 'Link-up',
    'desc_uk': 'Зв’язує атаки в єдине ціле',
    'desc_en': 'Connects attacking moves',
  },
  'counter_skill': {
    'emoji': '⚡',
    'name_uk': 'Контратака',
    'name_en': 'Counter pace',
    'desc_uk': 'Мчить у відповідьній атаці',
    'desc_en': 'Leads devastating counters',
  },
  'pressing_resistance_skill': {
    'emoji': '🌀',
    'name_uk': 'Антипресинг',
    'name_en': 'Press-resistance',
    'desc_uk': 'Не губиться під тиском суперника',
    'desc_en': 'Escapes tight pressing traps',
  },
  'ball_shield_skill': {
    'emoji': '🛡️',
    'name_uk': 'Щит м’яча',
    'name_en': 'Ball shield',
    'desc_uk': 'Прикриває м’яч корпусом як стіна',
    'desc_en': 'Shields possession like a wall',
  },
  'nutmeg_skill': {
    'emoji': '🥜',
    'name_uk': 'П’ятак',
    'name_en': 'Nutmeg',
    'desc_uk': 'Пропускає м’яч між ногами суперника',
    'desc_en': 'Slides the ball through legs',
  },
  'rabona_skill': {
    'emoji': '🪄',
    'name_uk': 'Рабона',
    'name_en': 'Rabona',
    'desc_uk': 'Виконує рабону як шоу',
    'desc_en': 'Performs rabonas for flair',
  },
  'backheel_skill': {
    'emoji': '👟',
    'name_uk': 'П’ятка',
    'name_en': 'Backheel',
    'desc_uk': 'Передачі й удари п’ятою',
    'desc_en': 'Backheel passes and shots',
  },
  'bicycle_skill': {
    'emoji': '🚲',
    'name_uk': 'Байсайкл',
    'name_en': 'Bicycle kick',
    'desc_uk': 'Філігранні удари через себе',
    'desc_en': 'Spectacular overhead kicks',
  },
  'flick_skill': {
    'emoji': '🎩',
    'name_uk': 'Флік',
    'name_en': 'Flicks',
    'desc_uk': 'Легким дотиком перекидає опіку',
    'desc_en': 'Beats markers with flicks',
  },
  'sweeper_keeper_skill': {
    'emoji': '🚨',
    'name_uk': 'Ліберо-кіпер',
    'name_en': 'Sweeper keeper',
    'desc_uk': 'Є ще одним польовим гравцем',
    'desc_en': 'Acts as an extra outfield player',
  },
  'one_on_one_save_skill': {
    'emoji': '🧱',
    'name_uk': '1v1 сейви',
    'name_en': '1v1 saves',
    'desc_uk': 'Перемагає дуелі з нападниками',
    'desc_en': 'Wins one-on-one duels',
  },
  'distribution_skill': {
    'emoji': '📦',
    'name_uk': 'Розіграш від воротаря',
    'name_en': 'Distribution',
    'desc_uk': 'Починає атаки точними передачами',
    'desc_en': 'Starts attacks with passes',
  },
  'footwork_skill': {
    'emoji': '🦶',
    'name_uk': 'Футворк',
    'name_en': 'Footwork',
    'desc_uk': 'Маневрує по лінії воріт',
    'desc_en': 'Floats across the goal line',
  },
  'reflex_wall_skill': {
    'emoji': '🧱',
    'name_uk': 'Рефлекторна стіна',
    'name_en': 'Reflex wall',
    'desc_uk': 'Миттєві реакції на лінії',
    'desc_en': 'Lightning saves on the line',
  },
  'communication_skill': {
    'emoji': '📣',
    'name_uk': 'Комунікація',
    'name_en': 'Communication',
    'desc_uk': 'Організовує партнерів голосом',
    'desc_en': 'Guides teammates vocally',
  },
  'captain_skill': {
    'emoji': '🎖️',
    'name_uk': 'Капітан',
    'name_en': 'Captaincy',
    'desc_uk': 'Веде команду вперед',
    'desc_en': 'Leads the squad forward',
  },
  'mentality_skill': {
    'emoji': '🧘',
    'name_uk': 'Менталітет',
    'name_en': 'Mentality',
    'desc_uk': 'Не ламається у складні моменти',
    'desc_en': 'Never breaks under adversity',
  },
  'anticipation_skill': {
    'emoji': '🔮',
    'name_uk': 'Передбачення',
    'name_en': 'Anticipation',
    'desc_uk': 'Випереджає розвиток епізоду',
    'desc_en': 'Anticipates the next move',
  },
  'build_up_skill': {
    'emoji': '🏗️',
    'name_uk': 'Білдап',
    'name_en': 'Build-up',
    'desc_uk': 'Запускає позиційні атаки',
    'desc_en': 'Orchestrates build-up play',
  },
  'overlap_skill': {
    'emoji': '↗️',
    'name_uk': 'Підключення',
    'name_en': 'Overlap',
    'desc_uk': 'Створює чисельну перевагу на фланзі',
    'desc_en': 'Overlaps to overload flanks',
  },
  'underlap_skill': {
    'emoji': '↘️',
    'name_uk': 'Атака всередину',
    'name_en': 'Underlap',
    'desc_uk': 'Вривається у напівфланг',
    'desc_en': 'Cuts inside from the flank',
  },
  'switch_play_skill': {
    'emoji': '🔄',
    'name_uk': 'Переключення',
    'name_en': 'Switch of play',
    'desc_uk': 'Миттєво змінює напрямок атаки',
    'desc_en': 'Swings attacks across the pitch',
  },
  'through_ball_skill': {
    'emoji': '🪟',
    'name_uk': 'Прохідна передача',
    'name_en': 'Through ball',
    'desc_uk': 'Розрізає оборону передачею',
    'desc_en': 'Slices defenses with through balls',
  },
  'wall_pass_skill': {
    'emoji': '🧱',
    'name_uk': 'Стіночка',
    'name_en': 'Wall pass',
    'desc_uk': 'Грає в стінку на швидкості',
    'desc_en': 'Executes rapid one-twos',
  },
  'counter_press_skill': {
    'emoji': '♻️',
    'name_uk': 'Контрпресинг',
    'name_en': 'Counter-press',
    'desc_uk': 'Повертає м’яч одразу після втрати',
    'desc_en': 'Wins the ball back instantly',
  },
};
