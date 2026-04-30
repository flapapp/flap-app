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
      emoji: data['emoji'] ?? '🏆',
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
        return el.tr('il_262b4ff6af');
      case 'skill':
        return el.tr('il_6df1bb18a5');
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
    if (_skillBadgeEmojis.containsKey(id)) {
      return _trBadge('badge_skill_${id}_name', defaultName);
    }
    return _trBadge('badge_name_$id', defaultName);
  }

  // Helper method to get localized badge description
  static String _getLocalizedDescription(String id, String defaultDescription) {
    if (_skillBadgeEmojis.containsKey(id)) {
      return _trBadge('badge_skill_${id}_desc', defaultDescription);
    }
    return _trBadge('badge_desc_$id', defaultDescription);
  }

  // Default badges list (name/description follow current locale for DB seed;
  // fallbacks match en.json.)
  static List<Badge> getDefaultBadges() {
    return [
      Badge(
        id: 'rookie',
        name: _trBadge('badge_name_rookie', 'Rookie'),
        emoji: '🌟',
        description: _trBadge('badge_desc_rookie', 'First step into FLAP world'),
        price: 50,
        category: 'starter',
      ),
      Badge(
        id: 'first_goal',
        name: _trBadge('badge_name_first_goal', 'First Goal'),
        emoji: '⚽',
        description: _trBadge('badge_desc_first_goal', 'Scored your first goal!'),
        price: 30,
        category: 'starter',
      ),
      Badge(
        id: 'striker',
        name: _trBadge('badge_name_striker', 'Striker'),
        emoji: '🔥',
        description: _trBadge('badge_desc_striker', 'Master of goal moments'),
        price: 40,
        category: 'skill',
      ),
      Badge(
        id: 'defender',
        name: _trBadge('badge_name_defender', 'Defender'),
        emoji: '🛡️',
        description: _trBadge('badge_desc_defender', 'Reliable as a rock'),
        price: 33,
        category: 'skill',
      ),
      Badge(
        id: 'playmaker',
        name: _trBadge('badge_name_playmaker', 'Playmaker'),
        emoji: '🎯',
        description: _trBadge('badge_desc_playmaker', 'Master of assists and passes'),
        price: 47,
        category: 'skill',
      ),
      Badge(
        id: 'goalkeeper',
        name: _trBadge('badge_name_goalkeeper', 'Goalkeeper'),
        emoji: '🥅',
        description: _trBadge('badge_desc_goalkeeper', 'Invincible gatekeeper'),
        price: 37,
        category: 'skill',
      ),
      Badge(
        id: 'speedster',
        name: _trBadge('badge_name_speedster', 'Speedster'),
        emoji: '⚡',
        description: _trBadge('badge_desc_speedster', 'Fast as lightning'),
        price: 30,
        category: 'skill',
      ),
      Badge(
        id: 'trickster',
        name: _trBadge('badge_name_trickster', 'Trickster'),
        emoji: '🎪',
        description: _trBadge('badge_desc_trickster', 'Master of technical skills'),
        price: 130,
        category: 'achievement',
      ),
      Badge(
        id: 'social',
        name: _trBadge('badge_name_social', 'Social'),
        emoji: '👥',
        description: _trBadge('badge_desc_social', 'Soul of team and community'),
        price: 80,
        category: 'special',
      ),
      Badge(
        id: 'challenger',
        name: _trBadge('badge_name_challenger', 'Challenger'),
        emoji: '🎖️',
        description: _trBadge('badge_desc_challenger', 'Winner of 10+ challenges'),
        price: 180,
        category: 'achievement',
      ),
      Badge(
        id: 'perfectionist',
        name: _trBadge('badge_name_perfectionist', 'Perfectionist'),
        emoji: '💎',
        description: _trBadge('badge_desc_perfectionist', 'Average video rating 4.5+'),
        price: 200,
        category: 'achievement',
      ),
      Badge(
        id: 'veteran',
        name: _trBadge('badge_name_veteran', 'Veteran'),
        emoji: '⭐',
        description: _trBadge('badge_desc_veteran', 'Experienced FLAP player'),
        price: 250,
        category: 'legendary',
      ),
      Badge(
        id: 'legend',
        name: _trBadge('badge_name_legend', 'Legend'),
        emoji: '👑',
        description: _trBadge('badge_desc_legend', 'Legend of football world'),
        price: 300,
        category: 'legendary',
      ),
      Badge(
        id: 'champion',
        name: _trBadge('badge_name_champion', 'Champion'),
        emoji: '🏆',
        description: _trBadge('badge_desc_champion', 'Best of the best'),
        price: 400,
        category: 'legendary',
      ),
      Badge(
        id: 'hall_of_fame',
        name: _trBadge('badge_name_hall_of_fame', 'Hall of Fame'),
        emoji: '🌟',
        description: _trBadge('badge_desc_hall_of_fame', 'Entered FLAP Hall of Fame'),
        price: 500,
        category: 'legendary',
      ),
      ..._skillBadgeEmojis.entries.map(
        (e) => Badge(
          id: e.key,
          name: _trBadge('badge_skill_${e.key}_name', e.key),
          emoji: e.value,
          description: _trBadge('badge_skill_${e.key}_desc', ''),
          price: 3,
          category: 'skill',
        ),
      ),
    ];
  }

}

const Map<String, String> _skillBadgeEmojis = {
  'dribbling_skill': '🕺',
  'passing_skill': '🎯',
  'shooting_skill': '💥',
  'strength_skill': '💪',
  'stamina_skill': '🏃',
  'intelligence_skill': '🧠',
  'defense_skill': '🛡️',
  'tackling_skill': '🦵',
  'technique_skill': '⚙️',
  'accuracy_skill': '🎲',
  'finishing_skill': '🥅',
  'leadership_skill': '👔',
  'saves_skill': '🧤',
  'reaction_skill': '⚡',
  'penalty_skill': '🎯',
  'freekick_skill': '🌪️',
  'speed_skill': '🚀',
  'longshot_skill': '🎇',
  'volley_skill': '🥏',
  'chip_skill': '🍟',
  'curve_skill': '🌈',
  'cross_skill': '📐',
  'vision_skill': '👀',
  'pressing_skill': '🧲',
  'marking_skill': '📎',
  'interception_skill': '✋',
  'clearance_skill': '🧱',
  'slide_skill': '🛷',
  'positioning_skill': '📍',
  'composure_skill': '🧊',
  'clutch_skill': '⚓',
  'resilience_skill': '🩹',
  'balance_skill': '⚖️',
  'agility_skill': '🤸',
  'heading_power_skill': '🧱',
  'heading_precision_skill': '🎯',
  'long_throw_skill': '🏹',
  'throwin_skill': '🤾',
  'short_pass_skill': '🔗',
  'long_pass_skill': '🛰️',
  'one_touch_skill': '☝️',
  'two_footed_skill': '🦶',
  'weak_foot_skill': '🦵',
  'first_touch_skill': '🎾',
  'hold_up_skill': '🪨',
  'linkup_skill': '🔁',
  'counter_skill': '⚡',
  'pressing_resistance_skill': '🌀',
  'ball_shield_skill': '🛡️',
  'nutmeg_skill': '🥜',
  'rabona_skill': '🪄',
  'backheel_skill': '👟',
  'bicycle_skill': '🚲',
  'flick_skill': '🎩',
  'sweeper_keeper_skill': '🚨',
  'one_on_one_save_skill': '🧱',
  'distribution_skill': '📦',
  'footwork_skill': '🦶',
  'reflex_wall_skill': '🧱',
  'communication_skill': '📣',
  'captain_skill': '🎖️',
  'mentality_skill': '🧘',
  'anticipation_skill': '🔮',
  'build_up_skill': '🏗️',
  'overlap_skill': '↗️',
  'underlap_skill': '↘️',
  'switch_play_skill': '🔄',
  'through_ball_skill': '🪟',
  'wall_pass_skill': '🧱',
  'counter_press_skill': '♻️',
};
