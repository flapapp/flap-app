import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/submission_entity.dart';

export '../../domain/entities/submission_entity.dart';

part 'submission.g.dart';

@JsonSerializable(explicitToJson: true)
class Submission extends SubmissionEntity {
  const Submission({
    required super.id,
    required super.challengeId,
    required super.userId,
    required super.userName,
    required super.userAvatar,
    required super.videoUrl,
    super.thumbnailUrl,
    required super.title,
    super.description,
    required super.submittedAt,
    required super.votes,
    required super.averageRating,
    required super.totalVotes,
    super.isActive = true,
  });

  static DateTime _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      final dynamic v = value;
      final date = v?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return DateTime.now();
  }

  // Factory constructor from Firestore / remote-like docs
  factory Submission.fromFirestore(dynamic doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    
    final votes = Map<String, double>.from(data['votes'] ?? {});
    final totalVotes = votes.length;
    final averageRating = totalVotes > 0 
        ? votes.values.reduce((a, b) => a + b) / totalVotes 
        : 0.0;

    return Submission(
      id: (doc.id ?? '').toString(),
      challengeId: data['challengeId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      title: data['title'] ?? '',
      description: data['description'],
      submittedAt: _readDate(data['submittedAt']),
      votes: votes,
      averageRating: averageRating,
      totalVotes: totalVotes,
      isActive: data['isActive'] ?? true,
    );
  }

  factory Submission.fromJson(Map<String, dynamic> json) =>
      _$SubmissionFromJson(json);

  Map<String, dynamic> toJson() => _$SubmissionToJson(this);

  // Convert to Map for Firestore-like clients
  Map<String, dynamic> toFirestore() {
    return {
      'challengeId': challengeId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'description': description,
      'submittedAt': submittedAt,
      'votes': votes,
      'averageRating': averageRating,
      'totalVotes': totalVotes,
      'isActive': isActive,
    };
  }

  // Copy with changes
  Submission copyWith({
    String? id,
    String? challengeId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? videoUrl,
    String? thumbnailUrl,
    String? title,
    String? description,
    DateTime? submittedAt,
    Map<String, double>? votes,
    double? averageRating,
    int? totalVotes,
    bool? isActive,
  }) {
    return Submission(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      submittedAt: submittedAt ?? this.submittedAt,
      votes: votes ?? this.votes,
      averageRating: averageRating ?? this.averageRating,
      totalVotes: totalVotes ?? this.totalVotes,
      isActive: isActive ?? this.isActive,
    );
  }

  // Add a vote
  Submission addVote(String voterId, double rating) {
    final newVotes = Map<String, double>.from(votes);
    newVotes[voterId] = rating;
    
    final newTotalVotes = newVotes.length;
    final newAverageRating = newTotalVotes > 0 
        ? newVotes.values.reduce((a, b) => a + b) / newTotalVotes 
        : 0.0;

    return copyWith(
      votes: newVotes,
      totalVotes: newTotalVotes,
      averageRating: newAverageRating,
    );
  }

  // Check if user has voted
  bool hasUserVoted(String userId) {
    return votes.containsKey(userId);
  }

  // Get user's vote
  double? getUserVote(String userId) {
    return votes[userId];
  }

  // Rating display with stars
  String get ratingDisplay {
    return '⭐ ${averageRating.toStringAsFixed(1)}';
  }

  // Rating color based on score
  int get ratingColor {
    if (averageRating >= 4.5) return 0xFF4CAF50; // Green
    if (averageRating >= 3.5) return 0xFF8BC34A; // Light Green
    if (averageRating >= 2.5) return 0xFFFFC107; // Yellow
    if (averageRating >= 1.5) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Red
  }
}
