import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../features/challenges/domain/entities/challenge_entity.dart';

enum VideoCategory {
  goal,
  shotPower,
  pass,
  longPass,
  dribbling,
  tackle,
  defending,
  penalty,
  save,
  wall,
  strategy,
  trick,
  other,
}

String videoCategoryToSlug(VideoCategory category) {
  switch (category) {
    case VideoCategory.goal:
      return 'goal';
    case VideoCategory.shotPower:
      return 'shot_power';
    case VideoCategory.pass:
      return 'pass';
    case VideoCategory.longPass:
      return 'long_pass';
    case VideoCategory.dribbling:
      return 'dribbling';
    case VideoCategory.tackle:
      return 'tackle';
    case VideoCategory.defending:
      return 'defending';
    case VideoCategory.penalty:
      return 'penalty';
    case VideoCategory.save:
      return 'save';
    case VideoCategory.wall:
      return 'wall';
    case VideoCategory.strategy:
      return 'strategy';
    case VideoCategory.trick:
      return 'trick';
    case VideoCategory.other:
      return 'other';
  }
}

class VideoCategoryDefinition {
  final VideoCategory category;
  final Color color;
  final List<String> keywords;
  final bool showInQuickFilters;

  const VideoCategoryDefinition({
    required this.category,
    required this.color,
    this.keywords = const [],
    this.showInQuickFilters = false,
  });

  String get id => videoCategoryToSlug(category);

  String get _labelKey => 'video_category_$id';

  String get _descriptionKey => 'video_category_${id}_desc';

  String label() => tr(_labelKey);

  String description() => tr(_descriptionKey);
}

const List<VideoCategoryDefinition> kVideoCategories = [
  VideoCategoryDefinition(
    category: VideoCategory.goal,
    color: Color(0xFFFF7043),
    keywords: ['goal', 'гол', 'finish', 'удар', 'shot'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.shotPower,
    color: Color(0xFFD84315),
    keywords: ['shot power', 'power', 'сила', 'постріл', 'rocket'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.pass,
    color: Color(0xFF66BB6A),
    keywords: ['pass', 'пас', 'assist', 'комбінація'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.longPass,
    color: Color(0xFF26C6DA),
    keywords: ['long pass', 'довг', 'cross', 'навіс', 'diag'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.dribbling,
    color: Color(0xFFAB47BC),
    keywords: ['dribble', 'дрибл', 'skill', 'фінт'],
  ),
  VideoCategoryDefinition(
    category: VideoCategory.tackle,
    color: Color(0xFF795548),
    keywords: ['tackle', 'підкат', 'відбір', 'interception'],
  ),
  VideoCategoryDefinition(
    category: VideoCategory.defending,
    color: Color(0xFF607D8B),
    keywords: ['defending', 'defense', 'захист', 'оборона', 'block'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.penalty,
    color: Color(0xFFFFC107),
    keywords: ['penalty', 'пеналь', '11'],
  ),
  VideoCategoryDefinition(
    category: VideoCategory.save,
    color: Color(0xFF42A5F5),
    keywords: ['save', 'сейв', 'keeper', 'goalkeep', 'воротар'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.wall,
    color: Color(0xFF455A64),
    keywords: ['wall', 'стінк', 'barrier', 'free kick wall', 'set piece'],
  ),
  VideoCategoryDefinition(
    category: VideoCategory.strategy,
    color: Color(0xFF26A69A),
    keywords: ['strategy', 'стратег', 'тактик', 'scheme'],
  ),
  VideoCategoryDefinition(
    category: VideoCategory.trick,
    color: Color(0xFFFFCA28),
    keywords: ['freestyle', 'трюк', 'show'],
  ),
  VideoCategoryDefinition(
    category: VideoCategory.other,
    color: Color(0xFF90A4AE),
    keywords: ['other', 'інше'],
  ),
];

final Map<String, VideoCategoryDefinition> _videoCategoriesById = {
  for (final category in kVideoCategories) category.id: category,
};

VideoCategoryDefinition? videoCategoryById(String id) =>
    _videoCategoriesById[id];

VideoCategoryDefinition? detectVideoCategory(String raw) {
  final normalized = raw.toLowerCase().trim();
  final legacyAliases = <String, String>{
    'dribble': 'dribbling',
    'freestyle': 'trick',
    'technique': 'dribbling',
    'physics': 'shot_power',
    'teamplay': 'pass',
  };
  final normalizedKey = legacyAliases[normalized] ?? normalized;
  if (_videoCategoriesById.containsKey(normalizedKey)) {
    return _videoCategoriesById[normalizedKey];
  }

  for (final category in kVideoCategories) {
    if (category.keywords.any((kw) => normalized.contains(kw.toLowerCase()))) {
      return category;
    }
  }
  return null;
}

String normalizeVideoCategoryValue(String raw) =>
    detectVideoCategory(raw)?.id ?? raw.toLowerCase();

Color videoCategoryColor(String raw) =>
    detectVideoCategory(raw)?.color ?? const Color(0xFF5C6BC0);

String videoCategoryLabel(String raw) =>
    detectVideoCategory(raw)?.label() ?? raw;

List<VideoCategoryDefinition> quickVideoCategories() =>
    kVideoCategories.where((c) => c.showInQuickFilters).toList();

void _assertCategoryParity() {
  assert(() {
    final challengeNames = ChallengeType.values.map((e) => e.name).toSet();
    final videoNames = VideoCategory.values.map((e) => e.name).toSet();
    if (challengeNames.length != videoNames.length ||
        !challengeNames.containsAll(videoNames)) {
      throw StateError(
        'VideoCategory and ChallengeType must share identical values.',
      );
    }
    return true;
  }());
}

final bool videoChallengeCategoryParityChecked = (() {
  _assertCategoryParity();
  return true;
})();





