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
  freestyle,
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

ChallengeStatus challengeStatusFromSchema(String? raw) {
  final value = (raw ?? '').toUpperCase();
  switch (value) {
    case 'RECRUITING':
      return ChallengeStatus.recruiting;
    case 'SUBMISSION':
      return ChallengeStatus.submission;
    case 'COMPLETED':
    case 'FINISHED':
      return ChallengeStatus.completed;
    case 'DRAFT':
      return ChallengeStatus.recruiting;
    case 'ACTIVE':
      return ChallengeStatus.submission;
    case 'VOTING':
      return ChallengeStatus.voting;
    case 'ENDED':
      return ChallengeStatus.completed;
    default:
      return ChallengeStatus.recruiting;
  }
}

String challengeStatusToSchema(ChallengeStatus status) {
  switch (status) {
    case ChallengeStatus.recruiting:
      return 'DRAFT';
    case ChallengeStatus.submission:
      return 'ACTIVE';
    case ChallengeStatus.voting:
      return 'VOTING';
    case ChallengeStatus.completed:
      return 'ENDED';
  }
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

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
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

  static double _prizePoolFromDistribution(dynamic v) {
    if (v is! Map) return 0.0;
    final total = v['total_pool'];
    if (total is num) return total.toDouble();
    final rows = v['distribution'];
    if (rows is List) {
      var sum = 0.0;
      for (final row in rows) {
        if (row is Map) {
          sum += (row['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      return sum;
    }
    return 0.0;
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
    final rawStatus = (j['status'] ?? 'DRAFT').toString();
    final audienceStr = (j['audience'] ?? 'WORLDWIDE').toString().split('.').last.toLowerCase();
    final audienceNormalized = audienceStr == 'worldwide' ? 'world' : audienceStr;

    final submissions = _stringIdList(
      j['submission_user_ids'] ?? j['submissions'],
    );

    final submitDueDate = _parseTs(
      j['submit_due_date'] ?? j['submission_deadline'] ?? j['submissionDeadline'],
    );
    final voteStartDate = _parseTs(
      j['vote_start_date'] ?? j['voting_deadline'] ?? j['votingDeadline'],
    );
    final voteEndDate = _parseTs(j['vote_end_date'] ?? j['end_date'] ?? j['endDate']);

    return Challenge(
      id: j['id']?.toString() ?? '',
      title: (j['title'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      type: parseChallengeType(j['type'] as String?),
      audience: ChallengeAudience.values.firstWhere(
        (e) => e.toString().split('.').last == audienceNormalized,
        orElse: () => ChallengeAudience.world,
      ),
      creatorId: (j['user_id'] ?? j['creator_id'] ?? j['creatorId'] ?? '').toString(),
      creatorName: (j['creator_name'] ??
              j['creatorName'] ??
              j['user_profiles']?['display_name'] ??
              j['user_profiles']?['username'] ??
              '')
          .toString(),
      creatorVideoUrl: (j['video_url'] ?? j['creator_video_url'] ?? j['creatorVideoUrl'])?.toString(),
      creatorThumbnailUrl:
          (j['thumbnail_url'] ?? j['creator_thumbnail_url'] ?? j['creatorThumbnailUrl'])?.toString(),
      city: (j['city'] ?? j['user_profiles']?['city'] ?? '').toString(),
      entryFee: _toInt(j['entry_fee'] ?? j['entryFee'], fallback: 0),
      duration: submitDueDate.difference(_parseTs(j['created_at'])).inDays.abs().clamp(1, 3650),
      createdAt: _parseTs(j['created_at'] ?? j['createdAt']),
      startDate: _parseTs(j['created_at'] ?? j['start_date'] ?? j['startDate']),
      submissionDeadline: submitDueDate,
      votingDeadline: voteStartDate,
      endDate: voteEndDate,
      status: challengeStatusFromSchema(rawStatus),
      maxParticipants: _toInt(j['max_participants'] ?? j['maxParticipants'], fallback: 50),
      currentParticipants:
          _toInt(j['current_participants'] ?? j['currentParticipants'], fallback: submissions.length),
      prizePool: ((j['prize_pool'] ?? j['prizePool']) as num?)?.toDouble() ??
          _prizePoolFromDistribution(j['prize_distribution']),
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
    int? entryFee,
    int? duration,
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
      case ChallengeType.freestyle:
        return I18n.inline('Фрістайл', 'Freestyle');
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
      case ChallengeType.freestyle:
        return '🤹';
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
    case 'freestyle':
      return ChallengeType.freestyle;
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
    case ChallengeType.freestyle:
      return 'freestyle';
    case ChallengeType.other:
      return 'other';
  }
}
