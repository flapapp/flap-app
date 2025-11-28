import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/i18n.dart';

enum ChallengeType {
  goal,
  save,
  pass,
  tackle,
  dribbling,
  trick,
  other,
}

enum ChallengeAudience {
  friends,      // Моїм друзям
  city,         // Моєму місту
  country,      // Моїй країні
  world         // Усьому світу
}

enum ChallengeStatus {
  recruiting,   // Збір учасників (7 днів)
  submission,   // Подання відео (7 днів)
  voting,       // Голосування (5 днів)
  completed     // Завершено
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final ChallengeAudience audience;
  final String creatorId;
  final String creatorName;
  final String? creatorVideoUrl; // URL відео творця челенджу
  final String city;
  final int entryFee;
  final int duration;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime submissionDeadline;
  final DateTime votingDeadline;
  final DateTime endDate;
  final ChallengeStatus status;
  final int maxParticipants;
  final int currentParticipants;
  final double prizePool;
  final List<String> participants;
  final List<String> submissions;
  final Map<String, double> votes; // userId -> rating
  final Map<String, Map<String, double>> detailedVotes; // userId -> {criteria -> rating}
  final List<String> winners; // [1st, 2nd, 3rd]
  final Map<String, double> finalScores; // userId -> final score
  final bool isActive;
  final String? imageUrl;
  final List<String> tags;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.audience,
    required this.creatorId,
    required this.creatorName,
    this.creatorVideoUrl,
    required this.city,
    required this.entryFee,
    required this.duration,
    required this.createdAt,
    required this.startDate,
    required this.submissionDeadline,
    required this.votingDeadline,
    required this.endDate,
    required this.status,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.prizePool,
    required this.participants,
    required this.submissions,
    required this.votes,
    required this.detailedVotes,
    required this.winners,
    required this.finalScores,
    required this.isActive,
    this.imageUrl,
    required this.tags,
  });

  // Конструктор з Firestore
  factory Challenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Challenge(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: parseChallengeType(data['type'] as String?),
      audience: ChallengeAudience.values.firstWhere(
        (e) => e.toString() == 'ChallengeAudience.${data['audience']}',
        orElse: () => ChallengeAudience.city,
      ),
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      creatorVideoUrl: data['creatorVideoUrl'],
      city: data['city'] ?? '',
      entryFee: data['entryFee'] ?? 10,
      duration: data['duration'] ?? 7,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      submissionDeadline: (data['submissionDeadline'] as Timestamp).toDate(),
      votingDeadline: (data['votingDeadline'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => ChallengeStatus.recruiting,
      ),
      maxParticipants: data['maxParticipants'] ?? 50,
      currentParticipants: data['currentParticipants'] ?? 0,
      prizePool: (data['prizePool'] ?? 0.0).toDouble(),
      participants: List<String>.from(data['participants'] ?? []),
      submissions: List<String>.from(data['submissions'] ?? []),
      votes: Map<String, double>.from(data['votes'] ?? {}),
      detailedVotes: Map<String, Map<String, double>>.from(data['detailedVotes'] ?? {}),
      winners: List<String>.from(data['winners'] ?? []),
      finalScores: Map<String, double>.from(data['finalScores'] ?? {}),
      isActive: data['isActive'] ?? true,
      imageUrl: data['imageUrl'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // Конвертація в Map для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'audience': audience.toString().split('.').last,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorVideoUrl': creatorVideoUrl,
      'city': city,
      'entryFee': entryFee,
      'duration': duration,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': Timestamp.fromDate(startDate),
      'submissionDeadline': Timestamp.fromDate(submissionDeadline),
      'votingDeadline': Timestamp.fromDate(votingDeadline),
      'endDate': Timestamp.fromDate(endDate),
      'status': status.toString().split('.').last,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'prizePool': prizePool,
      'participants': participants,
      'submissions': submissions,
      'votes': votes,
      'detailedVotes': detailedVotes,
      'winners': winners,
      'finalScores': finalScores,
      'isActive': isActive,
      'imageUrl': imageUrl,
      'tags': tags,
    };
  }

  // Копіювання з змінами
  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeType? type,
    String? creatorId,
    String? creatorName,
    String? creatorVideoUrl,
    String? city,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? submissionDeadline,
    DateTime? votingDeadline,
    DateTime? endDate,
    ChallengeStatus? status,
    int? maxParticipants,
    int? currentParticipants,
    double? prizePool,
    List<String>? participants,
    List<String>? submissions,
    Map<String, double>? votes,
    Map<String, Map<String, double>>? detailedVotes,
    List<String>? winners,
    Map<String, double>? finalScores,
    bool? isActive,
    String? imageUrl,
    List<String>? tags,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      audience: audience ?? this.audience,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorVideoUrl: creatorVideoUrl ?? this.creatorVideoUrl,
      city: city ?? this.city,
      entryFee: entryFee ?? this.entryFee,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      votingDeadline: votingDeadline ?? this.votingDeadline,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      prizePool: prizePool ?? this.prizePool,
      participants: participants ?? this.participants,
      submissions: submissions ?? this.submissions,
      votes: votes ?? this.votes,
      detailedVotes: detailedVotes ?? this.detailedVotes,
      winners: winners ?? this.winners,
      finalScores: finalScores ?? this.finalScores,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
    );
  }

  // Геттери для статусу
  bool get isRecruiting => status == ChallengeStatus.recruiting;
  bool get isSubmissionOpen => status == ChallengeStatus.submission;
  bool get isVotingOpen => status == ChallengeStatus.voting;
  bool get isCompleted => status == ChallengeStatus.completed;

  // Геттери для часу
  bool get canJoin => (isRecruiting || isSubmissionOpen) && currentParticipants < maxParticipants;
  bool get canSubmit => isSubmissionOpen && participants.isNotEmpty;
  bool get canVote => isVotingOpen;

  // Геттери для призів
  double get firstPlacePrize => prizePool * 0.5;
  double get secondPlacePrize => prizePool * 0.3;
  double get thirdPlacePrize => prizePool * 0.2;

  // Геттери для прогресу
  double get recruitmentProgress => 
      currentParticipants / maxParticipants;
  double get submissionProgress => 
      submissions.length / participants.length;
  double get votingProgress => 
      votes.length / submissions.length;

  // Геттери для часу
  Duration get timeUntilSubmission => 
      submissionDeadline.difference(DateTime.now());
  Duration get timeUntilVoting => 
      votingDeadline.difference(DateTime.now());
  Duration get timeUntilEnd => 
      endDate.difference(DateTime.now());

  // Геттери для статусу тексту
  String get statusText {
    switch (status) {
      case ChallengeStatus.recruiting:
        return 'Збір учасників';
      case ChallengeStatus.submission:
        return 'Подання відео';
      case ChallengeStatus.voting:
        return 'Голосування';
      case ChallengeStatus.completed:
        return 'Завершено';
    }
  }

  // Геттери для типу тексту
  String get typeText {
    switch (type) {
      case ChallengeType.goal:
        return I18n.inline('Гол', 'Goal');
      case ChallengeType.save:
        return I18n.inline('Сейв', 'Save');
      case ChallengeType.pass:
        return I18n.inline('Пас', 'Pass');
      case ChallengeType.tackle:
        return I18n.inline('Підкат', 'Tackle');
      case ChallengeType.dribbling:
        return I18n.inline('Дриблінг', 'Dribbling');
      case ChallengeType.trick:
        return I18n.inline('Трюк', 'Trick');
      case ChallengeType.other:
        return I18n.inline('Інше', 'Other');
    }
  }

  // Геттери для аудиторії
  String get audienceText {
    switch (audience) {
      case ChallengeAudience.friends:
        return 'Моїм друзям';
      case ChallengeAudience.city:
        return 'Моєму місту';
      case ChallengeAudience.country:
        return 'Моїй країні';
      case ChallengeAudience.world:
        return 'Усьому світу';
    }
  }

  String get audienceIcon {
    switch (audience) {
      case ChallengeAudience.friends:
        return '👥';
      case ChallengeAudience.city:
        return '🏙️';
      case ChallengeAudience.country:
        return '🇺🇦';
      case ChallengeAudience.world:
        return '🌍';
    }
  }

  // Геттери для іконок
  String get typeIcon {
    switch (type) {
      case ChallengeType.goal:
        return '⚽';
      case ChallengeType.save:
        return '🧤';
      case ChallengeType.pass:
        return '🎯';
      case ChallengeType.tackle:
        return '🛡️';
      case ChallengeType.dribbling:
        return '🌀';
      case ChallengeType.trick:
        return '✨';
      case ChallengeType.other:
        return '🎲';
    }
  }

  // Геттери для кольорів статусу
  int get statusColor {
    switch (status) {
      case ChallengeStatus.recruiting:
        return 0xFF4CAF50; // Зелений
      case ChallengeStatus.submission:
        return 0xFFFF9800; // Оранжевий
      case ChallengeStatus.voting:
        return 0xFF2196F3; // Синій
      case ChallengeStatus.completed:
        return 0xFF9E9E9E; // Сірий
    }
  }
}

ChallengeType parseChallengeType(String? raw) {
  switch (raw) {
    case 'goal':
      return ChallengeType.goal;
    case 'save':
      return ChallengeType.save;
    case 'pass':
      return ChallengeType.pass;
    case 'tackle':
      return ChallengeType.tackle;
    case 'dribbling':
      return ChallengeType.dribbling;
    case 'trick':
      return ChallengeType.trick;
    case 'other':
      return ChallengeType.other;
    case 'technical':
      return ChallengeType.dribbling;
    case 'positional':
      return ChallengeType.other;
    default:
      return ChallengeType.other;
  }
}
