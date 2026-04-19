import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/match_enums.dart';
import '../../domain/entities/match_team_entity.dart';
import '../../domain/entities/player_rating_entity.dart';
import 'player_rating_model.dart';
import 'team_model.dart';

/// Nullable nested team ↔ JSON (concrete type is [Team]).
class MatchTeamEntityConverter
    implements JsonConverter<MatchTeamEntity?, Object?> {
  const MatchTeamEntityConverter();

  @override
  MatchTeamEntity? fromJson(Object? json) {
    if (json == null) return null;
    if (json is Map<String, dynamic>) return Team.fromJson(json);
    if (json is Map) return Team.fromJson(Map<String, dynamic>.from(json));
    return null;
  }

  @override
  Object? toJson(MatchTeamEntity? object) =>
      object == null ? null : (object as Team).toJson();
}

/// List of teams for JSON APIs.
class MatchTeamEntityListConverter
    implements JsonConverter<List<MatchTeamEntity>, Object?> {
  const MatchTeamEntityListConverter();

  @override
  List<MatchTeamEntity> fromJson(Object? json) {
    if (json is! List) return <Team>[];
    return json
        .whereType<Map>()
        .map((m) => Team.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Object? toJson(List<MatchTeamEntity> object) =>
      object.map((t) => (t as Team).toJson()).toList();
}

/// Player ratings list for JSON APIs.
class PlayerRatingEntityListConverter
    implements JsonConverter<List<PlayerRatingEntity>, Object?> {
  const PlayerRatingEntityListConverter();

  @override
  List<PlayerRatingEntity> fromJson(Object? json) {
    if (json is! List) return <PlayerRating>[];
    return json
        .whereType<Map>()
        .map((m) => PlayerRating.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Object? toJson(List<PlayerRatingEntity> object) =>
      object.map((r) => (r as PlayerRating).toJson()).toList();
}

class MultiTeamStatsConverter
    implements JsonConverter<List<Map<String, dynamic>>, Object?> {
  const MultiTeamStatsConverter();

  @override
  List<Map<String, dynamic>> fromJson(Object? json) {
    if (json is! List) return <Map<String, dynamic>>[];
    return json
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Object? toJson(List<Map<String, dynamic>> object) => object;
}

class TeamRostersConverter
    implements JsonConverter<Map<String, List<String>>, Object?> {
  const TeamRostersConverter();

  @override
  Map<String, List<String>> fromJson(Object? json) {
    if (json is! Map) return <String, List<String>>{};
    return json.map(
      (k, v) {
        final list = v is List ? v : const [];
        return MapEntry(
          k.toString(),
          list.map((e) => e.toString()).toList(),
        );
      },
    );
  }

  @override
  Object? toJson(Map<String, List<String>> object) => object;
}

class TeamRosterStatusConverter
    implements JsonConverter<Map<String, Map<String, String>>, Object?> {
  const TeamRosterStatusConverter();

  @override
  Map<String, Map<String, String>> fromJson(Object? json) {
    if (json is! Map) return <String, Map<String, String>>{};
    return json.map(
      (k, v) {
        final inner = v is Map ? v : const {};
        return MapEntry(
          k.toString(),
          inner.map(
            (k2, v2) => MapEntry(k2.toString(), v2.toString()),
          ),
        );
      },
    );
  }

  @override
  Object? toJson(Map<String, Map<String, String>> object) => object;
}

class GoalsByPlayerConverter implements JsonConverter<Map<String, int>, Object?> {
  const GoalsByPlayerConverter();

  @override
  Map<String, int> fromJson(Object? json) {
    if (json is! Map) return <String, int>{};
    return json.map(
      (k, v) => MapEntry(k.toString(), (v as num).toInt()),
    );
  }

  @override
  Object? toJson(Map<String, int> object) => object;
}

class MatchResultNullableConverter
    implements JsonConverter<MatchResult?, Object?> {
  const MatchResultNullableConverter();

  @override
  MatchResult? fromJson(Object? json) {
    if (json == null) return null;
    final s = json.toString();
    return MatchResult.values.firstWhere(
      (e) => e.name == s,
      orElse: () => MatchResult.draw,
    );
  }

  @override
  Object? toJson(MatchResult? object) => object?.name;
}
