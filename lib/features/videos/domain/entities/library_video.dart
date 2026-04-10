import 'package:equatable/equatable.dart';

/// User-uploaded library video (feed), backed by `public.videos`.
class LibraryVideo extends Equatable {
  const LibraryVideo({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.title,
    required this.description,
    required this.category,
    this.difficulty,
    required this.videoUrl,
    this.videoStoragePath,
    this.thumbnailUrl,
    this.thumbnailStoragePath,
    required this.thumbnailGenerated,
    this.thumbnailType,
    required this.likes,
    required this.rating,
    required this.voteCount,
    required this.views,
    required this.commentsCount,
    this.city,
    this.challengeId,
    this.challengeTitle,
    required this.isChallengeVideo,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String authorName;
  final String title;
  final String description;
  final String category;
  final String? difficulty;
  final String videoUrl;
  final String? videoStoragePath;
  final String? thumbnailUrl;
  final String? thumbnailStoragePath;
  final bool thumbnailGenerated;
  final String? thumbnailType;
  final int likes;
  final double rating;
  final int voteCount;
  final int views;
  final int commentsCount;
  final String? city;
  final String? challengeId;
  final String? challengeTitle;
  final bool isChallengeVideo;
  final DateTime? createdAt;

  /// Shape compatible with legacy Firestore-driven video cards / filters.
  Map<String, dynamic> toLegacyCardMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'authorName': authorName,
      'title': title,
      'description': description,
      'category': category,
      if (difficulty != null) 'difficulty': difficulty,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'thumbnailGenerated': thumbnailGenerated,
      if (thumbnailType != null) 'thumbnailType': thumbnailType,
      'likes': likes,
      'rating': rating,
      'voteCount': voteCount,
      'views': views,
      'comments': commentsCount,
      'commentCount': commentsCount,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (challengeId != null && challengeId!.isNotEmpty) 'challengeId': challengeId,
      if (challengeTitle != null && challengeTitle!.isNotEmpty)
        'challengeTitle': challengeTitle,
      'isChallengeVideo': isChallengeVideo,
      'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [id];
}
