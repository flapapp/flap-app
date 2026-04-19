import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// ISO-8601 string ↔ non-null [DateTime].
class IsoDateTimeConverter implements JsonConverter<DateTime, Object?> {
  const IsoDateTimeConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (json is String) {
      return DateTime.tryParse(json) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Object? toJson(DateTime object) => object.toIso8601String();
}

/// ISO-8601 string ↔ nullable [DateTime].
class IsoDateTimeNullableConverter implements JsonConverter<DateTime?, Object?> {
  const IsoDateTimeNullableConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is String) return DateTime.tryParse(json);
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    return null;
  }

  @override
  Object? toJson(DateTime? object) => object?.toIso8601String();
}

/// `{ latitude, longitude }` ↔ [GeoPoint].
class GeoPointConverter implements JsonConverter<GeoPoint?, Object?> {
  const GeoPointConverter();

  @override
  GeoPoint? fromJson(Object? json) {
    if (json == null) return null;
    if (json is GeoPoint) return json;
    if (json is Map) {
      final m = Map<String, dynamic>.from(json);
      final lat = (m['latitude'] ?? m['lat']) as num?;
      final lng = (m['longitude'] ?? m['lng']) as num?;
      if (lat != null && lng != null) {
        return GeoPoint(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  @override
  Object? toJson(GeoPoint? object) {
    if (object == null) return null;
    return {'latitude': object.latitude, 'longitude': object.longitude};
  }
}

/// For `@JsonKey(fromJson: geoPointFromJson, toJson: geoPointToJson)`.
GeoPoint? geoPointFromJson(Object? json) =>
    const GeoPointConverter().fromJson(json);

Object? geoPointToJson(GeoPoint? value) =>
    const GeoPointConverter().toJson(value);
