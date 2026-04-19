import 'package:equatable/equatable.dart';

class SubmissionEntity extends Equatable {
  const SubmissionEntity({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.title,
    this.description,
    required this.submittedAt,
    required this.votes,
    required this.averageRating,
    required this.totalVotes,
    this.isActive = true,
  });

  final String id;
  final String challengeId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String videoUrl;
  final String? thumbnailUrl;
  final String title;
  final String? description;
  final DateTime submittedAt;
  final Map<String, double> votes;
  final double averageRating;
  final int totalVotes;
  final bool isActive;

  @override
  List<Object?> get props => [
        id,
        challengeId,
        userId,
        userName,
        userAvatar,
        videoUrl,
        thumbnailUrl,
        title,
        description,
        submittedAt,
        votes,
        averageRating,
        totalVotes,
        isActive,
      ];
}
