import '../repositories/profile_repository.dart';

class FetchProfileMapUseCase {
  FetchProfileMapUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Map<String, dynamic>?> call(String userId) {
    return _repository.fetchLegacyUserMap(userId);
  }
}
