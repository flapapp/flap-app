import '../repositories/profile_repository.dart';

class WatchProfileMapUseCase {
  WatchProfileMapUseCase(this._repository);

  final ProfileRepository _repository;

  Stream<Map<String, dynamic>> call(String userId) {
    return _repository.watchLegacyUserMap(userId);
  }
}
