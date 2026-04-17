import 'dart:typed_data';

import '../../../../core/error/result.dart';

/// Uploads the signed-in user's avatar image (storage + URL resolution only).
abstract class CurrentUserProfileAvatarRepository {
  Future<Result<String>> uploadAvatarJpeg(Uint8List bytes);
}
