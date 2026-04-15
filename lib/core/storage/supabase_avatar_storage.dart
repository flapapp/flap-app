import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads user avatars to Supabase Storage (`avatars` bucket, public URLs).
///
/// Object path: `{userId}/avatar.jpg` — must match RLS in
/// `supabase/migrations/20250412000000_storage_avatars.sql`.
///
/// Bucket `allowed_mime_types` must match the [FileOptions.contentType] you send.
class SupabaseAvatarStorage {
  SupabaseAvatarStorage._();

  static const _bucket = 'avatars';
  static const _fileName = 'avatar.jpg';

  static const _allowedMime = {'image/jpeg', 'image/png', 'image/webp'};

  /// Uses [mimeTypeFromPicker] when it is already jpeg/png/webp; otherwise infers
  /// from magic bytes so PNG/WebP are not sent as `image/jpeg` (upload failures).
  static String resolveContentType(Uint8List bytes, {String? mimeTypeFromPicker}) {
    final normalized = _normalizeDeclaredMime(mimeTypeFromPicker);
    if (normalized != null) return normalized;
    return _sniffImageMime(bytes) ?? 'image/jpeg';
  }

  static String? _normalizeDeclaredMime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final m = raw.toLowerCase().trim();
    if (m == 'image/jpg') return 'image/jpeg';
    if (_allowedMime.contains(m)) return m;
    return null;
  }

  /// Best-effort sniff for jpeg / png / webp (aligned with bucket allow-list).
  static String? _sniffImageMime(Uint8List b) {
    if (b.length < 12) return null;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return 'image/png';
    }
    if (b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  /// ISO BMFF `ftyp` box (common for HEIC/HEIF from iOS Photos).
  static bool _looksLikeHeicFamily(Uint8List b) {
    if (b.length < 12) return false;
    if (b[4] != 0x66 || b[5] != 0x74 || b[6] != 0x79 || b[7] != 0x70) return false;
    final brand = String.fromCharCodes(b.sublist(8, 12));
    const heicBrands = {'heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1', 'heim', 'heis'};
    return heicBrands.contains(brand);
  }

  static bool _shouldTranscodeToJpeg(Uint8List bytes, String? mimeTypeFromPicker) {
    final m = mimeTypeFromPicker?.toLowerCase().trim();
    if (m == 'image/heic' || m == 'image/heif') return true;
    if (_looksLikeHeicFamily(bytes)) return true;
    return false;
  }

  /// Returns the public URL for the uploaded image.
  static Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String? mimeTypeFromPicker,
  }) async {
    var uploadBytes = bytes;
    if (!kIsWeb && _shouldTranscodeToJpeg(bytes, mimeTypeFromPicker)) {
      uploadBytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 88,
        format: CompressFormat.jpeg,
        minWidth: 1024,
        minHeight: 1024,
      );
    }

    final contentType = resolveContentType(
      uploadBytes,
      mimeTypeFromPicker:
          uploadBytes != bytes ? 'image/jpeg' : mimeTypeFromPicker,
    );
    final path = '$userId/$_fileName';
    final client = Supabase.instance.client;
    await client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          uploadBytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from(_bucket).getPublicUrl(path);
  }
}
