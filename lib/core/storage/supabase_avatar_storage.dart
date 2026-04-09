import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads user avatars to Supabase Storage (`avatars` bucket, public URLs).
///
/// Object path: `{userId}/avatar.jpg` — must match RLS in
/// `supabase/migrations/20250412000000_storage_avatars.sql`.
class SupabaseAvatarStorage {
  SupabaseAvatarStorage._();

  static const _bucket = 'avatars';
  static const _fileName = 'avatar.jpg';

  /// Returns the public URL for the uploaded image.
  static Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final path = '$userId/$_fileName';
    final client = Supabase.instance.client;
    await client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from(_bucket).getPublicUrl(path);
  }
}
