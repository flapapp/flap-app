import 'dart:typed_data';

/// Firebase Storage uploads for profile avatars (implementation detail).
abstract class ProfileStorageDataSource {
  /// Uploads JPEG bytes to `avatars/{uid}/avatar.jpg` and returns download URL.
  Future<String> uploadUserAvatarJpeg(String userId, Uint8List bytes);
}
