import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/editable_profile_submission.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../datasources/profile_storage_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote, this._storage);

  final ProfileRemoteDataSource _remote;
  final ProfileStorageDataSource _storage;

  @override
  Future<UserProfile?> fetchUserProfile(String userId) async {
    final data = await _remote.getUserDocument(userId);
    if (data == null) return null;
    return UserProfile.fromDocument(userId, data);
  }

  @override
  Future<void> mergeUserSettings(
    String userId,
    Map<String, dynamic> settingsPatch,
  ) {
    return _remote.mergeUserSettings(userId, settingsPatch);
  }

  @override
  Future<void> mergeUserDocument(
    String userId,
    Map<String, dynamic> patch,
  ) {
    return _remote.mergeUserDocument(userId, patch);
  }

  @override
  Future<Result<Unit>> submitEditableProfile(EditableProfileSubmission data) async {
    try {
      String? avatarUrl;
      if (data.avatarJpegBytes != null && data.avatarJpegBytes!.isNotEmpty) {
        avatarUrl = await _storage.uploadUserAvatarJpeg(
          data.userId,
          data.avatarJpegBytes!,
        );
      }
      final fullName =
          '${data.firstName.trim()} ${data.lastName.trim()}'.trim();
      final map = <String, dynamic>{
        'firstName': data.firstName.trim(),
        'lastName': data.lastName.trim(),
        'authorName': fullName,
        'displayName': fullName,
        'city': data.city.trim(),
        'dateOfBirth': data.dateOfBirth,
        'position': data.position,
      };
      if (avatarUrl != null) {
        map['avatarUrl'] = avatarUrl;
        map['avatar'] = avatarUrl;
      }
      await _remote.mergeUserDocument(data.userId, map);
      if (!data.isEditing) {
        await _remote.trySeedDemoCrossFriends(data.userId);
      }
      return const Result.success(Unit.value);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> getUserDocumentsByIds(
    List<String> userIds,
  ) {
    return _remote.getUserDocumentsByIds(userIds);
  }
}
