import 'package:equatable/equatable.dart';

class VideoComment extends Equatable {
  const VideoComment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String videoId;
  final String userId;
  final String authorName;
  final String body;
  final DateTime? createdAt;

  Map<String, dynamic> toLegacyMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'text': body,
      'comment': body,
      'authorName': authorName,
      'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [id];
}
