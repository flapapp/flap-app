import '../repositories/profile_repository.dart';

class MergeProfileSettingsUseCase {
  MergeProfileSettingsUseCase(this._repository);

  final ProfileRepository _repository;

  Future<void> call(String userId, Map<String, dynamic> partial) {
    return _repository.mergeSettings(userId, partial);
  }
}
