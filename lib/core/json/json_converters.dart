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

/// Lightweight lat/lng (replaces Firestore [GeoPoint] in models).
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// `{ latitude, longitude }` ↔ [LatLng].
class LatLngConverter implements JsonConverter<LatLng?, Object?> {
  const LatLngConverter();

  @override
  LatLng? fromJson(Object? json) {
    if (json == null) return null;
    if (json is LatLng) return json;
    if (json is Map) {
      final m = Map<String, dynamic>.from(json);
      final lat = (m['latitude'] ?? m['lat']) as num?;
      final lng = (m['longitude'] ?? m['lng']) as num?;
      if (lat != null && lng != null) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  @override
  Object? toJson(LatLng? object) {
    if (object == null) return null;
    return {'latitude': object.latitude, 'longitude': object.longitude};
  }
}

LatLng? latLngFromJson(Object? json) => const LatLngConverter().fromJson(json);

Object? latLngToJson(LatLng? value) => const LatLngConverter().toJson(value);
