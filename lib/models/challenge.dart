import 'package:flap_app/utils/i18n.dart';

enum ChallengeType {
  goal,
  shotPower,
  pass,
  longPass,
  dribbling,
  tackle,
  penalty,
  save,
  wall,
  strategy,
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
  /// Preview thumb for creator video (Supabase: creator_thumbnail_url).
  final String? creatorThumbnailUrl;
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
  final Map<String, int> winnerPrizes; // userId -> coins won
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
    this.creatorThumbnailUrl,
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
    Map<String, int>? winnerPrizes,
    required this.isActive,
    this.imageUrl,
    required this.tags,
  }) : winnerPrizes = winnerPrizes ?? const {};

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  static List<String> _stringIdList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static Map<String, double> _stringDoubleMap(dynamic v) {
    if (v == null || v is! Map) return {};
    return v.map((k, val) => MapEntry(k.toString(), (val as num?)?.toDouble() ?? 0.0));
  }

  static Map<String, int> _stringIntMap(dynamic v) {
    if (v == null || v is! Map) return {};
    return v.map((k, val) => MapEntry(k.toString(), (val as num?)?.toInt() ?? 0));
  }

  static Map<String, Map<String, double>> _parseDetailedVotes(dynamic v) {
    if (v == null || v is! Map) return {};
    final out = <String, Map<String, double>>{};
    v.forEach((k, inner) {
      if (inner is Map) {
        out[k.toString()] = inner.map(
          (ik, iv) => MapEntry(ik.toString(), (iv as num?)?.toDouble() ?? 0.0),
        );
      }
    });
    return out;
  }

  /// Supabase row (snake_case) or legacy camelCase map.
  factory Challenge.fromJson(Map<String, dynamic> j) {
    final rawStatus = (j['status'] ?? 'recruiting').toString();
    final normalizedStatus = rawStatus == 'finished' ? 'completed' : rawStatus;

    final audienceStr =
        (j['audience'] ?? 'city').toString().split('.').last;

    final submissions = _stringIdList(
      j['submission_user_ids'] ?? j['submissions'],
    );

    return Challenge(
      id: j['id']?.toString() ?? '',
      title: (j['title'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      type: parseChallengeType(j['type'] as String?),
      audience: ChallengeAudience.values.firstWhere(
        (e) => e.toString().split('.').last == audienceStr,
        orElse: () => ChallengeAudience.city,
      ),
      creatorId: (j['creator_id'] ?? j['creatorId'] ?? '') as String,
      creatorName: (j['creator_name'] ?? j['creatorName'] ?? '') as String,
      creatorVideoUrl: j['creator_video_url'] ?? j['creatorVideoUrl'] as String?,
      creatorThumbnailUrl:
          j['creator_thumbnail_url'] ?? j['creatorThumbnailUrl'] as String?,
      city: (j['city'] ?? '') as String,
      entryFee: (j['entry_fee'] ?? j['entryFee'] ?? 10) as int,
      duration: (j['duration'] ?? 7) as int,
      createdAt: _parseTs(j['created_at'] ?? j['createdAt']),
      startDate: _parseTs(j['start_date'] ?? j['startDate']),
      submissionDeadline:
          _parseTs(j['submission_deadline'] ?? j['submissionDeadline']),
      votingDeadline: _parseTs(j['voting_deadline'] ?? j['votingDeadline']),
      endDate: _parseTs(j['end_date'] ?? j['endDate']),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == normalizedStatus,
        orElse: () => ChallengeStatus.recruiting,
      ),
      maxParticipants: (j['max_participants'] ?? j['maxParticipants'] ?? 50) as int,
      currentParticipants:
          (j['current_participants'] ?? j['currentParticipants'] ?? 0) as int,
      prizePool: ((j['prize_pool'] ?? j['prizePool'] ?? 0.0) as num).toDouble(),
      participants: _stringIdList(j['participants']),
      submissions: submissions,
      votes: _stringDoubleMap(j['votes']),
      detailedVotes: _parseDetailedVotes(j['detailed_votes'] ?? j['detailedVotes']),
      winners: _stringIdList(j['winners']),
      finalScores: _stringDoubleMap(j['final_scores'] ?? j['finalScores']),
      winnerPrizes: _stringIntMap(j['winner_prizes'] ?? j['winnerPrizes']),
      isActive: (j['is_active'] ?? j['isActive'] ?? true) as bool,
      imageUrl: j['image_url'] ?? j['imageUrl'] as String?,
      tags: _stringIdList(j['tags']),
    );
  }

  // Копіювання з змінами
  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeType? type,
    ChallengeAudience? audience,
    String? creatorId,
    String? creatorName,
    String? creatorVideoUrl,
    String? creatorThumbnailUrl,
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
    Map<String, int>? winnerPrizes,
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
      creatorThumbnailUrl: creatorThumbnailUrl ?? this.creatorThumbnailUrl,
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
      winnerPrizes: winnerPrizes ?? this.winnerPrizes,
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
      case ChallengeType.shotPower:
        return I18n.inline('Сила удару', 'Shot power');
      case ChallengeType.save:
        return I18n.inline('Сейв', 'Save');
      case ChallengeType.pass:
        return I18n.inline('Пас', 'Pass');
      case ChallengeType.longPass:
        return I18n.inline('Довгий пас', 'Long pass');
      case ChallengeType.tackle:
        return I18n.inline('Підкат', 'Tackle');
      case ChallengeType.dribbling:
        return I18n.inline('Дриблінг', 'Dribbling');
      case ChallengeType.penalty:
        return I18n.inline('Пенальті', 'Penalty');
      case ChallengeType.wall:
        return I18n.inline('Стіна / стандарт', 'Wall / set-piece');
      case ChallengeType.strategy:
        return I18n.inline('Стратегія', 'Strategy');
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
      case ChallengeType.shotPower:
        return '💥';
      case ChallengeType.save:
        return '🧤';
      case ChallengeType.pass:
        return '🎯';
      case ChallengeType.longPass:
        return '📡';
      case ChallengeType.tackle:
        return '🛡️';
      case ChallengeType.dribbling:
        return '🌀';
      case ChallengeType.penalty:
        return '🎯';
      case ChallengeType.wall:
        return '🧱';
      case ChallengeType.strategy:
        return '🧠';
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
  final normalized = (raw ?? '').toLowerCase();
  switch (normalized) {
    case 'goal':
      return ChallengeType.goal;
    case 'shot_power':
    case 'shotpower':
    case 'power':
      return ChallengeType.shotPower;
    case 'pass':
      return ChallengeType.pass;
    case 'long_pass':
    case 'longpass':
      return ChallengeType.longPass;
    case 'tackle':
      return ChallengeType.tackle;
    case 'dribbling':
    case 'technical':
      return ChallengeType.dribbling;
    case 'penalty':
      return ChallengeType.penalty;
    case 'save':
      return ChallengeType.save;
    case 'wall':
      return ChallengeType.wall;
    case 'strategy':
    case 'tactics':
    case 'positional':
      return ChallengeType.strategy;
    case 'trick':
      return ChallengeType.trick;
    case 'other':
      return ChallengeType.other;
    default:
      return ChallengeType.other;
  }
}

String challengeTypeToSlug(ChallengeType type) {
  switch (type) {
    case ChallengeType.goal:
      return 'goal';
    case ChallengeType.shotPower:
      return 'shot_power';
    case ChallengeType.pass:
      return 'pass';
    case ChallengeType.longPass:
      return 'long_pass';
    case ChallengeType.dribbling:
      return 'dribbling';
    case ChallengeType.tackle:
      return 'tackle';
    case ChallengeType.penalty:
      return 'penalty';
    case ChallengeType.save:
      return 'save';
    case ChallengeType.wall:
      return 'wall';
    case ChallengeType.strategy:
      return 'strategy';
    case ChallengeType.trick:
      return 'trick';
    case ChallengeType.other:
      return 'other';
  }
}
