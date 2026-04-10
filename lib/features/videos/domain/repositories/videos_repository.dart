import '../entities/library_video.dart';
import '../entities/video_comment.dart';

abstract class VideosRepository {
  Stream<List<LibraryVideo>> watchLibraryVideos({
    String? forUserId,
    int limit = 400,
  });

  Stream<LibraryVideo?> watchVideo(String videoId);

  Future<LibraryVideo?> fetchVideo(String videoId);

  Future<void> incrementViews(String videoId);

  Future<void> toggleLike({
    required String videoId,
    required String userId,
    required bool currentlyLiked,
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
  });

  Future<void> updateVideoThumbnail({
    required String videoId,
    required String thumbnailUrl,
    String? thumbnailStoragePath,
    bool thumbnailGenerated = true,
    String? thumbnailType,
  });

  Future<void> setWebThumbnailToVideoUrl(String videoId, String videoUrl);

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

  Future<void> deleteVideoIfOwner({
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

  Future<void> submitVideoVote({
    required String videoId,
    required String ratedBy,
    required double rating,
    required Map<String, dynamic> criteria,
  });
}
