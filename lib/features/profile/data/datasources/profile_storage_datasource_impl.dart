import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import 'profile_storage_datasource.dart';

class ProfileStorageDataSourceImpl implements ProfileStorageDataSource {
  ProfileStorageDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<String> uploadUserAvatarJpeg(String userId, Uint8List bytes) async {
    final path = '$userId/avatar.jpg';
    return SupabaseAppStorage.uploadPublicBytes(
      _client,
      bucket: SupabaseAppStorage.avatars,
      path: path,
      bytes: bytes,
      contentType: 'image/jpeg',
      upsert: true,
    );
  }
}
