import 'package:cloud_firestore/cloud_firestore.dart';

class Submission {
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
  final Map<String, double> votes; // voterId -> rating (0.0-5.0)
  final double averageRating;
  final int totalVotes;
  final bool isActive;

  Submission({
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

  // Factory constructor from Firestore
  factory Submission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final votes = Map<String, double>.from(data['votes'] ?? {});
    final totalVotes = votes.length;
    final averageRating = totalVotes > 0 
        ? votes.values.reduce((a, b) => a + b) / totalVotes 
        : 0.0;

    return Submission(
      id: doc.id,
      challengeId: data['challengeId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      title: data['title'] ?? '',
      description: data['description'],
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      votes: votes,
      averageRating: averageRating,
      totalVotes: totalVotes,
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert to Map for Firestore
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
      'submittedAt': Timestamp.fromDate(submittedAt),
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
