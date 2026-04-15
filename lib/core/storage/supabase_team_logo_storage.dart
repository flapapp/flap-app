import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads club crests to Supabase Storage (`team_logos` bucket, public URLs).
///
/// Object path: `{teamId}/logo.png` — must satisfy storage RLS (see
/// `20250422100000_storage_team_logos.sql` and `20260416000000_storage_team_logo_rls_helper.sql`).
class SupabaseTeamLogoStorage {
  SupabaseTeamLogoStorage._();

  static const _bucket = 'team_logos';
  static const _fileName = 'logo.png';

  static Future<String> uploadTeamLogo({
    required String teamId,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    // Object path first segment must match DB uuid text (lowercase) for storage RLS.
    final path = '${teamId.toLowerCase()}/$_fileName';
    final client = Supabase.instance.client;
    await client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from(_bucket).getPublicUrl(path);
  }
}
