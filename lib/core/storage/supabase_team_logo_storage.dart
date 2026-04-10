import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads club crests to Supabase Storage (`team-logos` bucket, public URLs).
///
/// Object path: `{teamId}/logo.png` — must match RLS in
/// `supabase/migrations/20250422100000_storage_team_logos.sql`.
class SupabaseTeamLogoStorage {
  SupabaseTeamLogoStorage._();

  static const _bucket = 'team-logos';
  static const _fileName = 'logo.png';

  static Future<String> uploadTeamLogo({
    required String teamId,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    final path = '$teamId/$_fileName';
    final client = Supabase.instance.client;
    await client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from(_bucket).getPublicUrl(path);
  }
}
