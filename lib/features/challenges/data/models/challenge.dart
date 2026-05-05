import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/challenge_entity.dart';

export '../../domain/entities/challenge_entity.dart';

part 'challenge.g.dart';

/// Legacy whole-day bucket (ceil of hours ÷ 24), minimum 1.
///
/// Sub-day spans (e.g. 1 hour) also become **1** here; do not show this value
/// with a “days” label. Use [challengeDurationDisplayFromSpan] for UI.
int challengeDurationDaysFromSpan(DateTime start, DateTime end) {
  if (!end.isAfter(start)) return 1;
  final d = (end.difference(start).inHours / 24).ceil();
  return d < 1 ? 1 : d;
}

/// Localized total length from [start] through [end] (hours if under 24h, else days).
String challengeDurationDisplayFromSpan(DateTime start, DateTime end) {
  if (!end.isAfter(start)) return tr('il_f8b8883f0c');
  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) return tr('il_f8b8883f0c');
  final ceilHours = (minutes + 59) ~/ 60;
  if (ceilHours < 24) {
    if (ceilHours == 1) return tr('il_f8b8883f0c');
    return tr('il_fc64c33206', namedArgs: {'hours': '$ceilHours'});
  }
  final days = (ceilHours / 24).ceil();
  if (days == 1) return tr('il_fa665d95d2');
  return '$days ${tr('il_ab51004e9d')}';
}

DateTime? _challengeDateTimeOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

(DateTime?, DateTime?) _challengeStartEndFromRow(Map<String, dynamic> row) {
  final start = _challengeDateTimeOrNull(row['starts_at']) ??
      _challengeDateTimeOrNull(row['start_date']) ??
      _challengeDateTimeOrNull(row['startDate']);
  final end = _challengeDateTimeOrNull(row['ends_at']) ??
      _challengeDateTimeOrNull(row['end_date']) ??
      _challengeDateTimeOrNull(row['endDate']);
  return (start, end);
}

/// [row] is a Supabase/JSON map; supports `starts_at` / `ends_at` and camelCase keys.
int challengeDurationDaysFromRow(Map<String, dynamic> row) {
  final (start, end) = _challengeStartEndFromRow(row);
  if (start == null || end == null) {
    final raw = row['duration'];
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return 1;
  }
  return challengeDurationDaysFromSpan(start, end);
}

/// Same date resolution as [challengeDurationDaysFromRow]; prefers span over raw `duration`.
String challengeDurationDisplayFromRow(Map<String, dynamic> row) {
  final (start, end) = _challengeStartEndFromRow(row);
  if (start == null || end == null) {
    final raw = row['duration'];
    if (raw is int && raw > 0) return '$raw ${tr('il_ab51004e9d')}';
    if (raw is num && raw > 0) return '${raw.round()} ${tr('il_ab51004e9d')}';
    return tr('il_fa665d95d2');
  }
  return challengeDurationDisplayFromSpan(start, end);
}

ChallengeType _challengeTypeFromJson(Object? json) =>
    parseChallengeType(json as String?);

String _challengeTypeToJson(ChallengeType v) => challengeTypeToSlug(v);

ChallengeAudience _challengeAudienceFromJson(Object? json) {
  final v = json?.toString() ?? 'city';
  return ChallengeAudience.values.firstWhere(
    (e) => e.name == v,
    orElse: () => ChallengeAudience.city,
  );
}

String _challengeAudienceToJson(ChallengeAudience v) => v.name;

ChallengeStatus _challengeStatusFromJson(Object? raw) {
  final s = raw?.toString() ?? 'recruiting';
  final normalized = s == 'finished' ? 'completed' : s;
  return ChallengeStatus.values.firstWhere(
    (e) => e.name == normalized,
    orElse: () => ChallengeStatus.recruiting,
  );
}

String _challengeStatusToJson(ChallengeStatus s) => s.name;

@JsonSerializable(explicitToJson: true)
class Challenge extends ChallengeEntity {
  Challenge({
    required super.id,
    required super.title,
    required super.description,
    @JsonKey(fromJson: _challengeTypeFromJson, toJson: _challengeTypeToJson)
    required super.type,
    @JsonKey(fromJson: _challengeAudienceFromJson, toJson: _challengeAudienceToJson)
    required super.audience,
    required super.creatorId,
    required super.creatorName,
    super.creatorVideoUrl,
    required super.city,
    required super.entryFee,
    required super.duration,
    required super.createdAt,
    required super.startDate,
    required super.submissionDeadline,
    required super.votingDeadline,
    required super.endDate,
    @JsonKey(fromJson: _challengeStatusFromJson, toJson: _challengeStatusToJson)
    required super.status,
    required super.maxParticipants,
    required super.currentParticipants,
    required super.prizePool,
    required super.participants,
    required super.submissions,
    required super.votes,
    required super.detailedVotes,
    required super.winners,
    required super.finalScores,
    super.winnerPrizes,
    required super.isActive,
    super.imageUrl,
    required super.tags,
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

  // Constructor from Firestore / remote-like documents
  factory Challenge.fromFirestore(dynamic doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    
    final rawStatus = (data['status'] ?? 'recruiting').toString();
    final normalizedStatus = rawStatus == 'finished' ? 'completed' : rawStatus;

    return Challenge(
      id: (doc.id ?? '').toString(),
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
      duration: (() {
        final s = _challengeDateTimeOrNull(
              data['startDate'] ?? data['starts_at'],
            ) ??
            _challengeDateTimeOrNull(data['start_date']);
        final e = _challengeDateTimeOrNull(
              data['endDate'] ?? data['ends_at'],
            ) ??
            _challengeDateTimeOrNull(data['end_date']);
        if (s != null && e != null) {
          return challengeDurationDaysFromSpan(s, e);
        }
        final raw = data['duration'];
        if (raw is int) return raw;
        if (raw is num) return raw.round();
        return 1;
      })(),
      createdAt: _readDate(data['createdAt']),
      startDate: _readDate(data['startDate']),
      submissionDeadline: _readDate(data['submissionDeadline']),
      votingDeadline: _readDate(data['votingDeadline']),
      endDate: _readDate(data['endDate']),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == normalizedStatus,
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
      winnerPrizes: Map<String, int>.from(
        data['winnerPrizes'] ?? {},
      ),
      isActive: data['isActive'] ?? true,
      imageUrl: data['imageUrl'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);

  Map<String, dynamic> toJson() => _$ChallengeToJson(this);

  // Convert to Map for Firestore-like clients
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': challengeTypeToSlug(type),
      'audience': audience.toString().split('.').last,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorVideoUrl': creatorVideoUrl,
      'city': city,
      'entryFee': entryFee,
      'duration': duration,
      'createdAt': createdAt,
      'startDate': startDate,
      'submissionDeadline': submissionDeadline,
      'votingDeadline': votingDeadline,
      'endDate': endDate,
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
      'winnerPrizes': winnerPrizes,
      'isActive': isActive,
      'imageUrl': imageUrl,
      'tags': tags,
    };
  }

  // Copy with changes
  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeType? type,
    ChallengeAudience? audience,
    String? creatorId,
    String? creatorName,
    String? creatorVideoUrl,
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

  // Status getters
  bool get isRecruiting => status == ChallengeStatus.recruiting;
  bool get isSubmissionOpen => status == ChallengeStatus.submission;
  bool get isVotingOpen => status == ChallengeStatus.voting;
  bool get isCompleted => status == ChallengeStatus.completed;

  // Time getters
  bool get canJoin => (isRecruiting || isSubmissionOpen) && currentParticipants < maxParticipants;
  bool get canSubmit => isSubmissionOpen && participants.isNotEmpty;
  bool get canVote => isVotingOpen;

  // Prize getters
  double get firstPlacePrize => prizePool * 0.5;
  double get secondPlacePrize => prizePool * 0.3;
  double get thirdPlacePrize => prizePool * 0.2;

  // Progress getters
  double get recruitmentProgress => 
      currentParticipants / maxParticipants;
  double get submissionProgress => 
      submissions.length / participants.length;
  double get votingProgress => 
      votes.length / submissions.length;

  // Time getters
  Duration get timeUntilSubmission => 
      submissionDeadline.difference(DateTime.now());
  Duration get timeUntilVoting => 
      votingDeadline.difference(DateTime.now());
  Duration get timeUntilEnd => 
      endDate.difference(DateTime.now());

  // Status text getters
  String get statusText {
    switch (status) {
      case ChallengeStatus.recruiting:
        return tr('challenge_status_recruiting');
      case ChallengeStatus.submission:
        return tr('challenge_status_submission');
      case ChallengeStatus.voting:
        return tr('challenge_status_voting');
      case ChallengeStatus.completed:
        return tr('challenge_status_completed');
    }
  }

  // Type text getters
  String get typeText {
    switch (type) {
      case ChallengeType.goal:
        return tr('il_cdbf6975e8');
      case ChallengeType.shotPower:
        return tr('il_a387ab1835');
      case ChallengeType.save:
        return tr('il_1509f561f2');
      case ChallengeType.pass:
        return tr('il_ebdf8cc00b');
      case ChallengeType.longPass:
        return tr('il_a30ef79268');
      case ChallengeType.tackle:
        return tr('il_9c0dd00951');
      case ChallengeType.defending:
        return tr('challenge_type_defending');
      case ChallengeType.dribbling:
        return tr('il_0b337d1bc7');
      case ChallengeType.penalty:
        return tr('il_241c754092');
      case ChallengeType.wall:
        return tr('il_93819c7151');
      case ChallengeType.strategy:
        return tr('il_6b27710dfa');
      case ChallengeType.trick:
        return tr('il_209e3aa0b5');
      case ChallengeType.other:
        return tr('il_f97e9da0e3');
    }
  }

  // Audience getters
  String get audienceText {
    switch (audience) {
      case ChallengeAudience.friends:
        return tr('my_friends_audience');
      case ChallengeAudience.city:
        return tr('my_city_audience');
      case ChallengeAudience.country:
        return tr('my_country_audience');
      case ChallengeAudience.world:
        return tr('whole_world_audience');
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

  // Icon getters
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
      case ChallengeType.defending:
        return '🧱';
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

  // Status color getters
  int get statusColor {
    switch (status) {
      case ChallengeStatus.recruiting:
        return 0xFF4CAF50; // Green
      case ChallengeStatus.submission:
        return 0xFFFF9800; // Orange
      case ChallengeStatus.voting:
        return 0xFF2196F3; // Blue
      case ChallengeStatus.completed:
        return 0xFF9E9E9E; // Gray
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
    case 'defending':
    case 'defense':
      return ChallengeType.defending;
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
    case ChallengeType.defending:
      return 'defending';
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

extension ChallengeDurationLabel on Challenge {
  String get durationDisplayLabel =>
      challengeDurationDisplayFromSpan(startDate, endDate);
}
