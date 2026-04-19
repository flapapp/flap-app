import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Central bucket ids and helpers for Supabase Storage (replaces Firebase Storage).
abstract final class SupabaseAppStorage {
  static const String avatars = 'avatars';
  static const String videos = 'videos';
  static const String teamLogos = 'team-logos';
  static const String thumbnails = 'thumbnails';
  static const String challengeThumbnails = 'challenge-thumbnails';
  static const String submissionThumbnails = 'submission-thumbnails';
  static const String matchCovers = 'match-covers';

  /// Uploads bytes to a public bucket and returns the public URL.
  static Future<String> uploadPublicBytes(
    SupabaseClient client, {
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: upsert,
            contentType: contentType,
          ),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Removes an object given a **public** Storage URL from this project.
  /// Returns false if [url] is not a recognized Supabase public object URL.
  static Future<bool> tryRemovePublicObject(
    SupabaseClient client,
    String url,
  ) async {
    final parsed = parsePublicObjectUrl(url);
    if (parsed == null) return false;
    try {
      await client.storage.from(parsed.$1).remove([parsed.$2]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Parses `.../storage/v1/object/public/<bucket>/<path>` URLs.
  static (String bucket, String objectPath)? parsePublicObjectUrl(String url) {
    try {
      final u = Uri.parse(url);
      final parts = u.pathSegments;
      final pub = parts.indexOf('public');
      if (pub == -1 || pub + 1 >= parts.length) return null;
      final bucket = parts[pub + 1];
      if (bucket.isEmpty) return null;
      final rest = parts.sublist(pub + 2);
      if (rest.isEmpty) return null;
      final objectPath = rest.map(Uri.decodeComponent).join('/');
      return (bucket, objectPath);
    } catch (_) {
      return null;
    }
  }
}
