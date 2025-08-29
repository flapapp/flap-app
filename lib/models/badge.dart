import 'package:cloud_firestore/cloud_firestore.dart';

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
        return 'Початковий';
      case 'skill':
        return 'Навичка';
      case 'achievement':
        return 'Досягнення';
      case 'legendary':
        return 'Легендарний';
      case 'special':
        return 'Спеціальний';
      default:
        return 'Звичайний';
    }
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
    ];
  }
}
