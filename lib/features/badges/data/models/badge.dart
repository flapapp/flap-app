import 'package:easy_localization/easy_localization.dart' as el;
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/badge_entity.dart';

export '../../domain/entities/badge_entity.dart';

part 'badge.g.dart';

@JsonSerializable(explicitToJson: true)
class Badge extends BadgeEntity {
  const Badge({
    required super.id,
    required super.name,
    required super.emoji,
    required super.description,
    required super.price,
    required super.category,
    super.isAvailable = true,
    super.releaseDate,
  });

  // Factory constructor from Firestore
  static DateTime? _readDateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic v = value;
      final date = v?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }

  factory Badge.fromFirestore(dynamic doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    
    return Badge(
      id: (doc.id ?? '').toString(),
      name: data['name'] ?? '',
      emoji: data['emoji'] ?? '',
      description: data['description'] ?? '',
      price: data['price'] ?? 0,
      category: data['category'] ?? 'general',
      isAvailable: data['isAvailable'] ?? true,
      releaseDate: _readDateOrNull(data['releaseDate']),
    );
  }

  factory Badge.fromJson(Map<String, dynamic> json) => _$BadgeFromJson(json);

  Map<String, dynamic> toJson() => _$BadgeToJson(this);

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'emoji': emoji,
      'description': description,
      'price': price,
      'category': category,
      'isAvailable': isAvailable,
      'releaseDate': releaseDate?.toIso8601String(),
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

  /// Skill listings (football abilities) and legacy `category: skill` player-style badges.
  static bool isSkillKindCategory(String category) {
    final c = category.toLowerCase();
    return c == 'skill' || c.startsWith('skill_');
  }

  // Badge color based on category
  int get categoryColor {
    switch (category) {
      case 'starter':
        return 0xFF4CAF50; // Green
      case 'skill':
      case 'skill_technical':
      case 'skill_attacking':
      case 'skill_defensive':
      case 'skill_goalkeeper':
      case 'skill_physical':
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
        return el.tr('il_262b4ff6af');
      case 'skill':
      case 'skill_technical':
      case 'skill_attacking':
      case 'skill_defensive':
      case 'skill_goalkeeper':
      case 'skill_physical':
        return el.tr('badge_tab_skills');
      case 'achievement':
        return el.tr('il_293523c3bf');
      case 'legendary':
        return el.tr('il_c80b041f5d');
      case 'special':
        return el.tr('il_997c544f1b');
      default:
        return el.tr('il_309955e008');
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

  static String _trBadge(String key, String fallback) {
    final t = el.tr(key);
    return t == key ? fallback : t;
  }

  // Helper method to get localized badge name
  static String _getLocalizedName(String id, String defaultName) {
    final skillName = _trBadge('badge_skill_${id}_name', defaultName);
    if (skillName != defaultName) return skillName;
    return _trBadge('badge_name_$id', defaultName);
  }

  // Helper method to get localized badge description
  static String _getLocalizedDescription(String id, String defaultDescription) {
    final skillName = _trBadge('badge_skill_${id}_name', id);
    if (skillName != id) {
      return _trBadge(
        'badge_skill_peer_confirm_desc',
        'Other players can confirm this ability on your profile.',
      );
    }
    return _trBadge('badge_desc_$id', defaultDescription);
  }
}
