import '../../domain/entities/library_video.dart';
import '../../domain/entities/video_comment.dart';

abstract class VideosRemoteDataSource {
  Stream<List<LibraryVideo>> watchLibraryVideos({
    String? forUserId,
    int limit = 400,
  });

  Stream<LibraryVideo?> watchVideo(String videoId);

  Future<LibraryVideo?> fetchVideo(String videoId);

  Future<void> incrementViews(String videoId);

  Future<void> setLike({
    required String videoId,
    required String userId,
    required bool liked,
  });

  Stream<bool> watchUserLikesVideo({
    required String videoId,
    required String userId,
  });

  Stream<double> watchLiveAverageVoteRating(String videoId);

  Future<double> fetchAverageVoteRating(String videoId);

  Future<int> fetchCommentCount(String videoId);

  Future<bool> userHasVote({
    required String videoId,
    required String userId,
  });

  Future<Map<String, double>?> fetchUserVoteCriteria({
    required String videoId,
    required String userId,
  });

  Stream<List<VideoComment>> watchComments(String videoId);

  Future<List<VideoComment>> fetchComments(String videoId);

  Future<void> addComment({
    required String videoId,
    required String userId,
    required String authorName,
    required String body,
  });

  Future<String> insertVideoRow(Map<String, dynamic> row);

  Future<void> updateVideoThumbnail({
    required String videoId,
    required String thumbnailUrl,
    String? thumbnailStoragePath,
    bool thumbnailGenerated,
    String? thumbnailType,
  });

  Future<void> updateVideoFields(
    String videoId,
    Map<String, dynamic> patch,
  );

  Future<({String publicUrl, String path})> uploadVideoBytes({
    required String userId,
    required List<int> bytes,
    required String fileName,
  });

  Future<({String publicUrl, String path})> uploadThumbnailBytes({
    required String userId,
    required List<int> bytes,
    required String fileName,
  });

  Future<void> deleteVideoAndFilesIfOwner({
    required String videoId,
    required String userId,
  });

  Future<List<LibraryVideo>> fetchUserVideosByViews({
    required String userId,
    int limit = 50,
  });

  Future<String?> findLibraryVideoIdByUrl({
    required String userId,
    required String videoUrl,
  });

  Future<void> insertVideoVote({
    required String videoId,
    required String ratedBy,
    required double rating,
    required Map<String, dynamic> criteria,
  });
}
