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

  static DateTime _readDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      final p = DateTime.tryParse(v);
      if (p != null) return p;
    }
    return DateTime.now();
  }

  factory Submission.fromMap(Map<String, dynamic> data, {required String id}) {
    final votes = Map<String, double>.from(data['votes'] ?? {});
    final totalVotes = votes.length;
    final averageRating = totalVotes > 0
        ? votes.values.reduce((a, b) => a + b) / totalVotes
        : 0.0;

    return Submission(
      id: id,
      challengeId: data['challengeId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String?,
      title: data['title'] ?? '',
      description: data['description'] as String?,
      submittedAt: _readDate(data['submittedAt']),
      votes: votes,
      averageRating: averageRating,
      totalVotes: totalVotes,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'challengeId': challengeId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'description': description,
      'submittedAt': submittedAt.toUtc().toIso8601String(),
      'votes': votes,
      'averageRating': averageRating,
      'totalVotes': totalVotes,
      'isActive': isActive,
    };
  }

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

  bool hasUserVoted(String userId) {
    return votes.containsKey(userId);
  }

  double? getUserVote(String userId) {
    return votes[userId];
  }

  String get ratingDisplay {
    return '⭐ ${averageRating.toStringAsFixed(1)}';
  }

  int get ratingColor {
    if (averageRating >= 4.5) return 0xFF4CAF50;
    if (averageRating >= 3.5) return 0xFF8BC34A;
    if (averageRating >= 2.5) return 0xFFFFC107;
    if (averageRating >= 1.5) return 0xFFFF9800;
    return 0xFFF44336;
  }
}
