import '../../domain/entities/library_video.dart';
import '../../domain/entities/video_comment.dart';
import '../../domain/repositories/videos_repository.dart';
import '../datasources/videos_remote_data_source.dart';

class VideosRepositoryImpl implements VideosRepository {
  VideosRepositoryImpl(this._remote);

  final VideosRemoteDataSource _remote;

  @override
  Stream<List<LibraryVideo>> watchLibraryVideos({
    String? forUserId,
    int limit = 400,
  }) {
    return _remote.watchLibraryVideos(forUserId: forUserId, limit: limit);
  }

  @override
  Stream<LibraryVideo?> watchVideo(String videoId) => _remote.watchVideo(videoId);

  @override
  Future<LibraryVideo?> fetchVideo(String videoId) => _remote.fetchVideo(videoId);

  @override
  Future<void> incrementViews(String videoId) => _remote.incrementViews(videoId);

  @override
  Future<void> toggleLike({
    required String videoId,
    required String userId,
    required bool currentlyLiked,
  }) {
    return _remote.setLike(
      videoId: videoId,
      userId: userId,
      liked: !currentlyLiked,
    );
  }

  @override
  Stream<bool> watchUserLikesVideo({
    required String videoId,
    required String userId,
  }) {
    return _remote.watchUserLikesVideo(videoId: videoId, userId: userId);
  }

  @override
  Stream<double> watchLiveAverageVoteRating(String videoId) {
    return _remote.watchLiveAverageVoteRating(videoId);
  }

  @override
  Future<double> fetchAverageVoteRating(String videoId) {
    return _remote.fetchAverageVoteRating(videoId);
  }

  @override
  Future<int> fetchCommentCount(String videoId) {
    return _remote.fetchCommentCount(videoId);
  }

  @override
  Future<bool> userHasVote({
    required String videoId,
    required String userId,
  }) {
    return _remote.userHasVote(videoId: videoId, userId: userId);
  }

  @override
  Future<Map<String, double>?> fetchUserVoteCriteria({
    required String videoId,
    required String userId,
  }) {
    return _remote.fetchUserVoteCriteria(videoId: videoId, userId: userId);
  }

  @override
  Stream<List<VideoComment>> watchComments(String videoId) {
    return _remote.watchComments(videoId);
  }

  @override
  Future<List<VideoComment>> fetchComments(String videoId) {
    return _remote.fetchComments(videoId);
  }

  @override
  Future<void> addComment({
    required String videoId,
    required String userId,
    required String authorName,
    required String body,
  }) {
    return _remote.addComment(
      videoId: videoId,
      userId: userId,
      authorName: authorName,
      body: body,
    );
  }

  @override
  Future<String> createVideoRecord({
    required String userId,
    required String authorName,
    required String title,
    required String description,
    required String category,
    String? difficulty,
    required String videoUrl,
    String? videoStoragePath,
    String? city,
    String? challengeId,
    String? challengeTitle,
    required bool isChallengeVideo,
  }) async {
    final row = <String, dynamic>{
      'user_id': userId,
      'author_name': authorName,
      'title': title,
      'description': description,
      'category': category,
      'video_url': videoUrl,
      if (videoStoragePath != null) 'video_storage_path': videoStoragePath,
      if (difficulty != null) 'difficulty': difficulty,
      if (city != null && city.isNotEmpty) 'city': city,
      if (challengeId != null && challengeId.isNotEmpty) 'challenge_id': challengeId,
      if (challengeTitle != null && challengeTitle.isNotEmpty)
        'challenge_title': challengeTitle,
      'is_challenge_video': isChallengeVideo,
    };
    return _remote.insertVideoRow(row);
  }

  @override
  Future<void> updateVideoThumbnail({
    required String videoId,
    required String thumbnailUrl,
    String? thumbnailStoragePath,
    bool thumbnailGenerated = true,
    String? thumbnailType,
  }) {
    return _remote.updateVideoThumbnail(
      videoId: videoId,
      thumbnailUrl: thumbnailUrl,
      thumbnailStoragePath: thumbnailStoragePath,
      thumbnailGenerated: thumbnailGenerated,
      thumbnailType: thumbnailType,
    );
  }

  @override
  Future<void> setWebThumbnailToVideoUrl(String videoId, String videoUrl) {
    return _remote.updateVideoThumbnail(
      videoId: videoId,
      thumbnailUrl: videoUrl,
      thumbnailGenerated: true,
      thumbnailType: 'web_video_preview',
    );
  }

  @override
  Future<({String publicUrl, String path})> uploadVideoBytes({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) {
    return _remote.uploadVideoBytes(
      userId: userId,
      bytes: bytes,
      fileName: fileName,
    );
  }

  @override
  Future<({String publicUrl, String path})> uploadThumbnailBytes({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) {
    return _remote.uploadThumbnailBytes(
      userId: userId,
      bytes: bytes,
      fileName: fileName,
    );
  }

  @override
  Future<void> deleteVideoIfOwner({
    required String videoId,
    required String userId,
  }) {
    return _remote.deleteVideoAndFilesIfOwner(videoId: videoId, userId: userId);
  }

  @override
  Future<List<LibraryVideo>> fetchUserVideosByViews({
    required String userId,
    int limit = 50,
  }) {
    return _remote.fetchUserVideosByViews(userId: userId, limit: limit);
  }

  @override
  Future<String?> findLibraryVideoIdByUrl({
    required String userId,
    required String videoUrl,
  }) {
    return _remote.findLibraryVideoIdByUrl(userId: userId, videoUrl: videoUrl);
  }

  @override
  Future<void> submitVideoVote({
    required String videoId,
    required String ratedBy,
    required double rating,
    required Map<String, dynamic> criteria,
  }) {
    return _remote.insertVideoVote(
      videoId: videoId,
      ratedBy: ratedBy,
      rating: rating,
      criteria: criteria,
    );
  }
}
