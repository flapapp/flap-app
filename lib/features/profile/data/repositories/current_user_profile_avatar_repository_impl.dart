import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../domain/repositories/current_user_profile_avatar_repository.dart';
import '../datasources/profile_storage_datasource.dart';

class CurrentUserProfileAvatarRepositoryImpl
    implements CurrentUserProfileAvatarRepository {
  CurrentUserProfileAvatarRepositoryImpl(this._auth, this._storage);

  final AuthSessionRepository _auth;
  final ProfileStorageDataSource _storage;

  @override
  Future<Result<String>> uploadAvatarJpeg(Uint8List bytes) async {
    final uid = _auth.peekCurrentUser?.uid;
    if (uid == null) {
      return const Result.failure(
        Failure.auth(code: 'unauthenticated', message: null),
      );
    }
    try {
      final url = await _storage.uploadUserAvatarJpeg(uid, bytes);
      return Result.success(url);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
