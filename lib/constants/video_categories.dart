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
  final bool showInQuickFilters;

  const VideoCategoryDefinition({
    required this.category,
    required this.color,
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
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.shotPower,
    color: Color(0xFFD84315),
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.pass,
    color: Color(0xFF66BB6A),
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.longPass,
    color: Color(0xFF26C6DA),
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.dribbling,
    color: Color(0xFFAB47BC),
  ),
  VideoCategoryDefinition(
    category: VideoCategory.tackle,
    color: Color(0xFF795548),
  ),
  VideoCategoryDefinition(
    category: VideoCategory.defending,
    color: Color(0xFF607D8B),
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.penalty,
    color: Color(0xFFFFC107),
  ),
  VideoCategoryDefinition(
    category: VideoCategory.save,
    color: Color(0xFF42A5F5),
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    category: VideoCategory.wall,
    color: Color(0xFF455A64),
  ),
  VideoCategoryDefinition(
    category: VideoCategory.strategy,
    color: Color(0xFF26A69A),
  ),
  VideoCategoryDefinition(
    category: VideoCategory.trick,
    color: Color(0xFFFFCA28),
  ),
  VideoCategoryDefinition(
    category: VideoCategory.other,
    color: Color(0xFF90A4AE),
  ),
];

final Map<String, VideoCategoryDefinition> _videoCategoriesById = {
  for (final category in kVideoCategories) category.id: category,
};

VideoCategoryDefinition? videoCategoryById(String id) =>
    _videoCategoriesById[id];

bool _csvContainsToken(String csv, String token) {
  final n = token;
  if (n.isEmpty) return false;
  for (final part in csv.split(',')) {
    final t = part.trim().toLowerCase();
    if (t.isNotEmpty && t == n) return true;
  }
  return false;
}

/// Resolves [normalized] (already lowercased) to a canonical slug via
/// [video_category_aliases_<slug>] comma-separated tokens in translations.
String? _resolveVideoCategorySlug(String normalized) {
  if (_videoCategoriesById.containsKey(normalized)) return normalized;
  final underscored = normalized.replaceAll(RegExp(r'\s+'), '_');
  if (underscored != normalized &&
      _videoCategoriesById.containsKey(underscored)) {
    return underscored;
  }
  for (final def in kVideoCategories) {
    final slug = def.id;
    final key = 'video_category_aliases_$slug';
    final csv = tr(key);
    if (csv == key) continue;
    if (_csvContainsToken(csv, normalized)) return slug;
    if (underscored != normalized && _csvContainsToken(csv, underscored)) {
      return slug;
    }
  }
  return null;
}

VideoCategoryDefinition? detectVideoCategory(String raw) {
  final normalized = raw.toLowerCase().trim();
  final slug = _resolveVideoCategorySlug(normalized);
  if (slug == null) return null;
  return _videoCategoriesById[slug];
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





