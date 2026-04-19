import 'dart:collection';

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../../core/json/json_converters.dart';
import '../../domain/entities/match_enums.dart';
import '../../domain/entities/match_entity.dart';
import '../../domain/entities/match_team_entity.dart';
import '../../domain/entities/player_rating_entity.dart';
import 'match_converters.dart';
import 'player_rating_model.dart';
import 'team_model.dart';

export '../../domain/entities/match_enums.dart';
export '../../domain/entities/match_entity.dart';
export '../../domain/entities/match_team_entity.dart';
export '../../domain/entities/player_rating_entity.dart';
export 'player_rating_model.dart';
export 'team_model.dart';

part 'match.g.dart';

// Основний клас матчу
@JsonSerializable(explicitToJson: true)
class Match extends MatchEntity {
  Match({
    required super.id,
    required super.title,
    required super.description,
    required super.organizerId,
    required super.organizerName,
    required super.date,
    required super.time,
    required super.location,
    required super.city,
    super.coordinates,
    required super.currentPlayers,
    required super.maxPlayers,
    required super.participants,
    super.pendingApplications = const [],
    super.rejectedApplications = const [],
    required super.level,
    required super.cost,
    required super.autoBalance,
    required super.isPrivate,
    super.invitedFriends = const [],
    required super.status,
    super.teamA,
    super.teamB,
    super.teams = const [],
    super.teamCount,
    super.multiTeamStats = const [],
    super.isTeamMatch = false,
    super.teamAId,
    super.teamBId,
    super.teamAStatus,
    super.teamBStatus,
    super.teamRosters = const {},
    super.teamRosterStatus = const {},
    super.goalsByPlayer = const {},
    super.teamsReadyNotified = false,
    super.teamsReadyNotifiedAt,
    super.coverPhotoUrl,
    super.coverPhotoUpdatedAt,
    super.result,
    super.teamAScore,
    super.teamBScore,
    super.playerRatings = const [],
    required super.createdAt,
    required super.updatedAt,
    super.startedAt,
    super.finishedAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) => _$MatchFromJson(json);

  Map<String, dynamic> toJson() => _$MatchToJson(this);

  // Створення з Firestore
  factory Match.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAtTs = data['createdAt'] as Timestamp?;
    final updatedAtTs = data['updatedAt'] as Timestamp?;
    
    return Match(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      city: data['city'] ?? '',
      coordinates: data['coordinates'] as GeoPoint?,
      currentPlayers: data['currentPlayers'] ?? 0,
      maxPlayers: data['maxPlayers'] ?? 0,
      participants: List<String>.from(data['participants'] ?? []),
      pendingApplications: List<String>.from(data['pendingApplications'] ?? []),
      rejectedApplications: List<String>.from(data['rejectedApplications'] ?? []),
      level: MatchLevel.values.firstWhere(
        (e) => e.toString().split('.').last == data['level'],
        orElse: () => MatchLevel.intermediate,
      ),
      cost: (data['cost'] ?? 0.0).toDouble(),
      autoBalance: data['autoBalance'] ?? false,
      isPrivate: data['isPrivate'] ?? false,
      invitedFriends: List<String>.from(data['invitedFriends'] ?? []),
      status: MatchStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => MatchStatus.open,
      ),
      teamA: data['teamA'] != null ? Team(
        name: (data['teamA']['name'] ?? '') as String,
        playerIds: List<String>.from(data['teamA']['playerIds'] ?? const []),
        averageRating: ((data['teamA']['averageRating'] ?? 0.0) as num).toDouble(),
        playerRatings: Map<String, double>.from(
          (data['teamA']['playerRatings'] ?? const <String, num>{})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        ),
      ) : null,
      teamB: data['teamB'] != null ? Team(
        name: (data['teamB']['name'] ?? '') as String,
        playerIds: List<String>.from(data['teamB']['playerIds'] ?? const []),
        averageRating: ((data['teamB']['averageRating'] ?? 0.0) as num).toDouble(),
        playerRatings: Map<String, double>.from(
          (data['teamB']['playerRatings'] ?? const <String, num>{})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        ),
      ) : null,
      multiTeamStats: ((data['multiTeamStats'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      isTeamMatch: data['teamMatch'] ?? false,
      teamAId: data['teamAId'] as String?,
      teamBId: data['teamBId'] as String?,
      teamAStatus: data['teamAStatus'] as String?,
      teamBStatus: data['teamBStatus'] as String?,
      teamRosters: Map<String, List<String>>.from(
        ((data['teamRosters'] as Map?) ?? const {})
            .map((key, value) => MapEntry(key.toString(),
                value is List ? List<String>.from(value) : const <String>[])),
      ),
      teamRosterStatus: ((data['teamRosterStatus'] as Map?) ?? const {})
          .map((teamKey, value) {
        final mapValue = value is Map ? value : const <String, dynamic>{};
        return MapEntry(
          teamKey.toString(),
          mapValue.map(
            (playerId, status) => MapEntry(
              playerId.toString(),
              status.toString(),
            ),
          ),
        );
      }),
      goalsByPlayer: Map<String, int>.from(
        ((data['goalsByPlayer'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      ),
      teamsReadyNotified: data['teamsReadyNotified'] ?? false,
      teamsReadyNotifiedAt:
          (data['teamsReadyNotifiedAt'] as Timestamp?)?.toDate(),
      coverPhotoUrl: data['coverPhotoUrl'] as String?,
      coverPhotoUpdatedAt:
          (data['coverPhotoUpdatedAt'] as Timestamp?)?.toDate(),
      teams: ((data['teams'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((t) => Team(
                name: (t['name'] ?? '') as String,
                playerIds: List<String>.from(t['playerIds'] ?? const []),
                averageRating: ((t['averageRating'] ?? 0.0) as num).toDouble(),
              ))
          .toList(),
      teamCount: (data['teamCount'] as num?)?.toInt() ??
          (data['teams'] is List ? (data['teams'] as List).length : null),
      result: data['result'] != null
          ? MatchResult.values.firstWhere(
              (e) => e.toString().split('.').last == data['result'],
              orElse: () => MatchResult.draw,
            )
          : null,
      teamAScore: data['teamAScore'],
      teamBScore: data['teamBScore'],
      playerRatings: ((data['playerRatings'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => PlayerRating(
                playerId: item['playerId'] ?? '',
                ratedBy: item['ratedBy'] ?? '',
                rating: ((item['rating'] ?? 0.0) as num).toDouble(),
                ratedAt: (item['ratedAt'] is Timestamp)
                    ? (item['ratedAt'] as Timestamp).toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0),
                criteria: Map<String, double>.from(
                  (item['criteria'] ?? const <String, num>{})
                      .map((k, v) => MapEntry(k, (v as num).toDouble())),
                ),
              ))
          .toList(),
      createdAt: (createdAtTs ?? Timestamp.now()).toDate(),
      updatedAt: (updatedAtTs ?? Timestamp.now()).toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Конвертація в Map для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'date': Timestamp.fromDate(date),
      'time': time,
      'location': location,
      'city': city,
      'coordinates': coordinates,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
      'participants': participants,
      'pendingApplications': pendingApplications,
      'rejectedApplications': rejectedApplications,
      'level': level.toString().split('.').last,
      'cost': cost,
      'autoBalance': autoBalance,
      'isPrivate': isPrivate,
      'invitedFriends': invitedFriends,
      'status': status.toString().split('.').last,
      'teamA': (teamA as Team?)?.toFirestore(),
      'teamB': (teamB as Team?)?.toFirestore(),
      'teams': teams.map((t) => (t as Team).toFirestore()).toList(),
      'teamCount': teamCount,
      'multiTeamStats': multiTeamStats,
      'teamMatch': isTeamMatch,
      'teamAId': teamAId,
      'teamBId': teamBId,
      'teamAStatus': teamAStatus,
      'teamBStatus': teamBStatus,
      'teamRosters': teamRosters,
      'teamRosterStatus': teamRosterStatus,
      'goalsByPlayer': goalsByPlayer,
      'teamsReadyNotified': teamsReadyNotified,
      'teamsReadyNotifiedAt': teamsReadyNotifiedAt != null
          ? Timestamp.fromDate(teamsReadyNotifiedAt!)
          : null,
      'coverPhotoUrl': coverPhotoUrl,
      'coverPhotoUpdatedAt': coverPhotoUpdatedAt != null
          ? Timestamp.fromDate(coverPhotoUpdatedAt!)
          : null,
      'result': result?.toString().split('.').last,
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'playerRatings': playerRatings
          .map((rating) => (rating as PlayerRating).toFirestore())
          .toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
    };
  }

  // Копіювання з змінами
  Match copyWith({
    String? id,
    String? title,
    String? description,
    String? organizerId,
    String? organizerName,
    DateTime? date,
    String? time,
    String? location,
    String? city,
    GeoPoint? coordinates,
    int? currentPlayers,
    int? maxPlayers,
    List<String>? participants,
    List<String>? pendingApplications,
    List<String>? rejectedApplications,
    MatchLevel? level,
    double? cost,
    bool? autoBalance,
    bool? isPrivate,
    List<String>? invitedFriends,
    MatchStatus? status,
    MatchTeamEntity? teamA,
    MatchTeamEntity? teamB,
    List<MatchTeamEntity>? teams,
    int? teamCount,
    List<Map<String, dynamic>>? multiTeamStats,
    bool? isTeamMatch,
    String? teamAId,
    String? teamBId,
    String? teamAStatus,
    String? teamBStatus,
    Map<String, List<String>>? teamRosters,
    Map<String, Map<String, String>>? teamRosterStatus,
    Map<String, int>? goalsByPlayer,
    bool? teamsReadyNotified,
    DateTime? teamsReadyNotifiedAt,
    String? coverPhotoUrl,
    DateTime? coverPhotoUpdatedAt,
    MatchResult? result,
    int? teamAScore,
    int? teamBScore,
    List<PlayerRatingEntity>? playerRatings,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return Match(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      city: city ?? this.city,
      coordinates: coordinates ?? this.coordinates,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      participants: participants ?? this.participants,
      pendingApplications: pendingApplications ?? this.pendingApplications,
      rejectedApplications: rejectedApplications ?? this.rejectedApplications,
      level: level ?? this.level,
      cost: cost ?? this.cost,
      autoBalance: autoBalance ?? this.autoBalance,
      isPrivate: isPrivate ?? this.isPrivate,
      invitedFriends: invitedFriends ?? this.invitedFriends,
      status: status ?? this.status,
      teamA: teamA ?? this.teamA,
      teamB: teamB ?? this.teamB,
      teams: teams ?? this.teams,
      teamCount: teamCount ?? this.teamCount,
      multiTeamStats: multiTeamStats ?? this.multiTeamStats,
      isTeamMatch: isTeamMatch ?? this.isTeamMatch,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      teamAStatus: teamAStatus ?? this.teamAStatus,
      teamBStatus: teamBStatus ?? this.teamBStatus,
      teamRosters: teamRosters ?? this.teamRosters,
      teamRosterStatus: teamRosterStatus ?? this.teamRosterStatus,
      goalsByPlayer: goalsByPlayer ?? this.goalsByPlayer,
      teamsReadyNotified: teamsReadyNotified ?? this.teamsReadyNotified,
      teamsReadyNotifiedAt:
          teamsReadyNotifiedAt ?? this.teamsReadyNotifiedAt,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      coverPhotoUpdatedAt:
          coverPhotoUpdatedAt ?? this.coverPhotoUpdatedAt,
      result: result ?? this.result,
      teamAScore: teamAScore ?? this.teamAScore,
      teamBScore: teamBScore ?? this.teamBScore,
      playerRatings: playerRatings ?? this.playerRatings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  // Геттери для зручності
bool get isOpen => status == MatchStatus.open;
bool get isFull => status == MatchStatus.full;
bool get isInProgress => status == MatchStatus.inProgress;
bool get isFinished => status == MatchStatus.finished;
bool get isCancelled => status == MatchStatus.cancelled;

/// Нормалізований запланований час матчу (date + time).
DateTime get scheduledDateTime {
  final raw = time.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(raw);
  if (match == null) {
    return DateTime(date.year, date.month, date.day, 0, 0);
  }
  final h = int.tryParse(match.group(1) ?? '') ?? 0;
  final m = int.tryParse(match.group(2) ?? '') ?? 0;
  return DateTime(
    date.year,
    date.month,
    date.day,
    h.clamp(0, 23),
    m.clamp(0, 59),
  );
}

/// Незапущений матч, який "прострочився" більше ніж на 24 години.
bool get isUnplayedByTimeout {
  final isStillNotStarted = status == MatchStatus.open || status == MatchStatus.full;
  if (!isStillNotStarted) return false;
  if (startedAt != null || finishedAt != null) return false;
  final deadline = scheduledDateTime.add(const Duration(hours: 24));
  return DateTime.now().isAfter(deadline);
}

  int confirmedPlayersForTeam(String teamKey) {
    final statusMap = teamRosterStatus[teamKey];
    if (statusMap == null || statusMap.isEmpty) return 0;
    return statusMap.values.where((status) => status == 'confirmed').length;
  }

  bool teamHasConfirmedPlayers(String teamKey) =>
      confirmedPlayersForTeam(teamKey) > 0;

  bool get hasConfirmedPlayersForBothTeams =>
      teamHasConfirmedPlayers('teamA') && teamHasConfirmedPlayers('teamB');

  List<String> get confirmedParticipantIds {
    if (teamRosterStatus.isEmpty) {
      return List<String>.from(participants);
    }
    final ordered = LinkedHashSet<String>();
    teamRosterStatus.forEach((_, playerStatuses) {
      playerStatuses.forEach((playerId, status) {
        if (status == 'confirmed') {
          ordered.add(playerId);
        }
      });
    });
    if (ordered.isEmpty) {
      return List<String>.from(participants);
    }
    return ordered.toList();
  }

  int get confirmedParticipantsCount {
    final ids = confirmedParticipantIds;
    return ids.isEmpty ? participants.length : ids.length;
  }

  Map<String, String> get playerTeamAssignments {
    final assignments = <String, String>{};
    teamRosters.forEach((teamKey, ids) {
      for (final id in ids) {
        assignments[id] = teamKey;
      }
    });
    if (assignments.isEmpty) {
      for (final id in teamA?.playerIds ?? const <String>[]) {
        assignments[id] = 'teamA';
      }
      for (final id in teamB?.playerIds ?? const <String>[]) {
        assignments[id] = 'teamB';
      }
    }
    return assignments;
  }
  
  // Перевірка ролі користувача
  bool isOrganizer(String userId) => organizerId == userId;
  bool isParticipant(String userId) => participants.contains(userId);
  bool hasPendingApplication(String userId) => pendingApplications.contains(userId);
  bool wasRejected(String userId) => rejectedApplications.contains(userId);
  bool canJoin(String userId) => status == MatchStatus.open && 
                              !participants.contains(userId) && 
                              !pendingApplications.contains(userId) &&
                              !rejectedApplications.contains(userId) &&
                              currentPlayers < maxPlayers;
  
  // Перевірка чи є команди
  bool get hasTeams => teamA != null && teamB != null;

  List<MatchTeamEntity> get allTeams {
    if (teams.isNotEmpty) return teams;
    final result = <MatchTeamEntity>[];
    if (teamA != null) result.add(teamA!);
    if (teamB != null) result.add(teamB!);
    return result;
  }
  
  // Статус для конкретного користувача
  String getUserStatus(String userId) {
    if (organizerId == userId) {
      return 'organizer';
    }
    if (participants.contains(userId)) {
      return 'participant';
    }
    if (pendingApplications.contains(userId)) {
      return 'pending';
    }
    if (rejectedApplications.contains(userId)) {
      return 'rejected';
    }
    return 'none';
  }

  // Кількість вільних місць
  int get availableSpots => maxPlayers - currentPlayers;

  // Відсоток заповнення
  double get fillPercentage {
    if (maxPlayers <= 0) return 0.0;
    return (currentPlayers / maxPlayers) * 100;
  }

  // Перевірка чи може користувач оцінювати
  bool canRate(String userId) => 
      participants.contains(userId) && 
      !playerRatings.any((rating) => rating.ratedBy == userId);
  
  String get levelText {
    switch (level) {
      case MatchLevel.beginner:
        return 'Початковий';
      case MatchLevel.intermediate:
        return 'Середній';
      case MatchLevel.advanced:
        return 'Високий';
      case MatchLevel.professional:
        return 'Професійний';
    }
  }
  
  String get statusText {
    switch (status) {
      case MatchStatus.open:
        return 'Відкрито';
      case MatchStatus.full:
        return 'Заповнено';
      case MatchStatus.inProgress:
        return 'В процесі';
      case MatchStatus.finished:
        return 'Завершено';
      case MatchStatus.cancelled:
        return 'Скасовано';
    }
  }
  
  String get costText => cost > 0 ? '${cost.toInt()} грн' : 'Безкоштовно';
  
  // Перевірка чи можна керувати
  bool canManage(String userId) => isOrganizer(userId);

  @override
  String toString() {
    return 'Match(id: $id, title: $title, status: $status)';
  }
}

// Утиліти для роботи з матчами
class MatchUtils {
  // Генерація назв команд
  static final List<String> teamNames = [
    'Blaze Foxes',
    'Storm Wolves',
    'Iron Hawks',
    'Shadow Panthers',
    'Neon Falcons',
    'Thunder Bears',
    'Crimson Sharks',
    'Frost Vipers',
    'Rapid Lynx',
    'Golden Owls',
    'Steel Bulls',
    'Nova Tigers',
    'Velocity Ravens',
    'Phantom Eagles',
    'Rocket Pumas',
    'Fire Cobras',
    'Titan Rhinos',
    'Gravity Leopards',
    'Wild Spartans',
    'Electric Knights',
  ];
  
  static String generateTeamName() {
    return generateTeamNames(1).first;
  }

  static List<String> generateTeamNames(int count) {
    final shuffled = List<String>.from(teamNames)..shuffle(Random());
    if (count <= shuffled.length) {
      return shuffled.take(count).toList();
    }

    final result = <String>[];
    for (var i = 0; i < count; i++) {
      final baseName = shuffled[i % shuffled.length];
      final cycle = (i ~/ shuffled.length) + 1;
      result.add(cycle == 1 ? baseName : '$baseName ${cycle + 1}');
    }
    return result;
  }
  
  // Розрахунок середнього рейтингу команди
  static double calculateTeamAverageRating(List<String> playerIds, Map<String, double> playerRatings) {
    if (playerIds.isEmpty) return 0.0;
    
    double totalRating = 0.0;
    int ratedPlayers = 0;
    
    for (String playerId in playerIds) {
      if (playerRatings.containsKey(playerId)) {
        totalRating += playerRatings[playerId]!;
        ratedPlayers++;
      }
    }
    
    return ratedPlayers > 0 ? totalRating / ratedPlayers : 0.0;
  }
  
  // Перевірка чи матч можна почати
  static bool canStartMatch(Match match) {
    final rosterA =
        match.teamRosters['teamA'] ?? match.teamA?.playerIds ?? const <String>[];
    final rosterB =
        match.teamRosters['teamB'] ?? match.teamB?.playerIds ?? const <String>[];

    if (match.isTeamMatch) {
      final teamAReady = (match.teamAStatus ?? 'pending') == 'confirmed';
      final teamBReady = (match.teamBStatus ?? 'pending') == 'confirmed';
      return teamAReady &&
          teamBReady &&
          rosterA.isNotEmpty &&
          rosterB.isNotEmpty;
    }

    return match.isFull &&
        match.hasTeams &&
        rosterA.isNotEmpty &&
        rosterB.isNotEmpty;
  }
  
  // Перевірка чи матч можна завершити
  static bool canFinishMatch(Match match) {
    return match.isInProgress && 
           match.hasTeams && 
           match.teamA!.playerIds.isNotEmpty && 
           match.teamB!.playerIds.isNotEmpty;
  }
}