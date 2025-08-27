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
        id: 'striker',
        name: 'Бомбардир',
        emoji: '⚽',
        description: 'Для тих, хто любить забивати голи',
        price: 100,
        category: 'skill',
      ),
      Badge(
        id: 'defender',
        name: 'Захисник',
        emoji: '🛡️',
        description: 'Надійний як скеля',
        price: 75,
        category: 'skill',
      ),
      Badge(
        id: 'playmaker',
        name: 'Плеймейкер',
        emoji: '🎯',
        description: 'Майстер гольових передач',
        price: 120,
        category: 'skill',
      ),
      Badge(
        id: 'goalkeeper',
        name: 'Воротар',
        emoji: '🥅',
        description: 'Останній рубіж оборони',
        price: 90,
        category: 'skill',
      ),
      Badge(
        id: 'legend',
        name: 'Легенда',
        emoji: '👑',
        description: 'Для справжніх майстрів футболу',
        price: 200,
        category: 'legendary',
      ),
      Badge(
        id: 'champion',
        name: 'Чемпіон',
        emoji: '🏆',
        description: 'Переможець багатьох турнірів',
        price: 300,
        category: 'legendary',
      ),
      Badge(
        id: 'skillful',
        name: 'Технічний',
        emoji: '🤹',
        description: 'Майстер технічних елементів',
        price: 150,
        category: 'achievement',
      ),
      Badge(
        id: 'social',
        name: 'Соціальний',
        emoji: '👥',
        description: 'Душа компанії на полі',
        price: 80,
        category: 'special',
      ),
      Badge(
        id: 'veteran',
        name: 'Ветеран',
        emoji: '⭐',
        description: 'Досвідчений гравець FLAP',
        price: 250,
        category: 'legendary',
      ),
    ];
  }
}
