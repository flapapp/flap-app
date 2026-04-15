import '../entities/profile_completion_snapshot.dart';
import '../repositories/profile_repository.dart';

class FetchProfileCompletionSnapshotUseCase {
  FetchProfileCompletionSnapshotUseCase(this._repository);

  final ProfileRepository _repository;

  Future<ProfileCompletionSnapshot?> call(String userId) {
    return _repository.fetchCompletionSnapshot(userId);
  }
}
