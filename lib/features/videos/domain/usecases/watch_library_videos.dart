import '../entities/library_video.dart';
import '../repositories/videos_repository.dart';

class WatchLibraryVideos {
  WatchLibraryVideos(this._repository);

  final VideosRepository _repository;

  Stream<List<LibraryVideo>> call({
    String? forUserId,
    int limit = 400,
  }) {
    return _repository.watchLibraryVideos(forUserId: forUserId, limit: limit);
  }
}
