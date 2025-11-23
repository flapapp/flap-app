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
    
    final lang = I18n.language.value;
    return badgeNames[id]?[lang] ?? defaultName;
  }

  // Helper method to get localized badge description
  static String _getLocalizedDescription(String id, String defaultDescription) {
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
    
    final lang = I18n.language.value;
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
      
      // Нові бейджі скілів по 20 монет
      Badge(
        id: 'dribbling_skill',
        name: 'Дриблінг',
        emoji: '🕺',
        description: 'Майстерність обведення',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'passing_skill',
        name: 'Пас',
        emoji: '🎯',
        description: 'Точність передач',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'shooting_skill',
        name: 'Удар',
        emoji: '⚡',
        description: 'Потужність удару',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'strength_skill',
        name: 'Сила',
        emoji: '💪',
        description: 'Фізична сила',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'stamina_skill',
        name: 'Витривалість',
        emoji: '🏃',
        description: 'Витривалість на полі',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'intelligence_skill',
        name: 'Футбольний інтелект',
        emoji: '🧠',
        description: 'Тактичне мислення',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'defense_skill',
        name: 'Захист',
        emoji: '🛡️',
        description: 'Оборонна майстерність',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'tackling_skill',
        name: 'Підкат',
        emoji: '🦵',
        description: 'Майстерність відбору м\'яча',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'technique_skill',
        name: 'Техніка',
        emoji: '⚙️',
        description: 'Технічна майстерність',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'accuracy_skill',
        name: 'Точність',
        emoji: '🎲',
        description: 'Точність виконання',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'finishing_skill',
        name: 'Реалізація',
        emoji: '🥅',
        description: 'Ефективність у завершенні атак',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'leadership_skill',
        name: 'Лідерство',
        emoji: '👨‍✈️',
        description: 'Лідерські якості',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'saves_skill',
        name: 'Сейв',
        emoji: '🧤',
        description: 'Майстерність воротаря',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'reaction_skill',
        name: 'Реакція',
        emoji: '⚡',
        description: 'Швидкість реакції',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'penalty_skill',
        name: 'Пенальті',
        emoji: '🎯',
        description: 'Майстерність одинадцятиметрових',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'freekick_skill',
        name: 'Штрафні',
        emoji: '🌪️',
        description: 'Майстерність штрафних ударів',
        price: 20,
        category: 'skill',
      ),
      Badge(
        id: 'speed_skill',
        name: 'Швидкість',
        emoji: '🚀',
        description: 'Швидкість пересування',
        price: 20,
        category: 'skill',
      ),
    ];
  }
}

