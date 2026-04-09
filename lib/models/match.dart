import 'dart:collection';

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

// Статус матчу
enum MatchStatus {
  open,       // Відкрито для участі
  full,       // Заповнено
  inProgress, // В процесі
  finished,   // Завершено
  cancelled   // Скасовано
}

// Рівень складності
enum MatchLevel {
  beginner,   // Початковий
  intermediate, // Середній
  advanced,   // Високий
  professional // Професійний
}

// Результат матчу
enum MatchResult {
  teamAWins,  // Перемога команди А
  teamBWins,  // Перемога команди Б
  draw        // Нічия
}

// Клас команди
class Team {
  final String name;
  final List<String> playerIds;
  final double averageRating;
  final Map<String, double> playerRatings;

  Team({
    required this.name,
    required this.playerIds,
    this.averageRating = 0.0,
    this.playerRatings = const {},
  });

  // Створення з Firestore
  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      name: data['name'] ?? '',
      playerIds: List<String>.from(data['playerIds'] ?? []),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      playerRatings: Map<String, double>.from(data['playerRatings'] ?? {}),
    );
  }

  // Конвертація в Map для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'playerIds': playerIds,
      'averageRating': averageRating,
      'playerRatings': playerRatings,
    };
  }

  // Копіювання з змінами
  Team copyWith({
    String? name,
    List<String>? playerIds,
    double? averageRating,
    Map<String, double>? playerRatings,
  }) {
    return Team(
      name: name ?? this.name,
      playerIds: playerIds ?? this.playerIds,
      averageRating: averageRating ?? this.averageRating,
      playerRatings: playerRatings ?? this.playerRatings,
    );
  }
}

// Оцінка гравця
class PlayerRating {
  final String playerId;
  final String ratedBy;
  final double rating;
  final DateTime ratedAt;
  final Map<String, double> criteria; // техніка, фізика, тактика, командна гра

  PlayerRating({
    required this.playerId,
    required this.ratedBy,
    required this.rating,
    required this.ratedAt,
    this.criteria = const {},
  });

  // Створення з Firestore
  factory PlayerRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerRating(
      playerId: data['playerId'] ?? '',
      ratedBy: data['ratedBy'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratedAt: (data['ratedAt'] as Timestamp).toDate(),
      criteria: Map<String, double>.from(data['criteria'] ?? {}),
    );
  }

  // Конвертація в Map для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'ratedBy': ratedBy,
      'rating': rating,
      'ratedAt': Timestamp.fromDate(ratedAt),
      'criteria': criteria,
    };
  }
}

// Основний клас матчу
class Match {
  final String id;
  final String title;
  final String description;
  final String organizerId;
  final String organizerName;
  
  // Час та місце
  final DateTime date;
  final String time;
  final String location;
  final String city;
  final GeoPoint? coordinates;
  
  // Учасники
  final int currentPlayers;
  final int maxPlayers;
  final List<String> participants;
  final List<String> pendingApplications;
  final List<String> rejectedApplications;
  
  // Налаштування
  final MatchLevel level;
  final double cost;
  final bool autoBalance;
  final bool isPrivate;
  final List<String> invitedFriends;
  
  // Статус
  final MatchStatus status;
  
  // Команди
  final Team? teamA;
  final Team? teamB;
  final List<Team> teams;
  final int? teamCount;
  final List<Map<String, dynamic>> multiTeamStats;
  final bool isTeamMatch;
  final String? teamAId;
  final String? teamBId;
  final String? teamAStatus;
  final String? teamBStatus;
  final Map<String, List<String>> teamRosters;
  final Map<String, Map<String, String>> teamRosterStatus;
  final Map<String, int> goalsByPlayer;
  final bool teamsReadyNotified;
  final DateTime? teamsReadyNotifiedAt;
  final String? coverPhotoUrl;
  final DateTime? coverPhotoUpdatedAt;
 
  // Результат
  final MatchResult? result;
  final int? teamAScore;
  final int? teamBScore;
  final List<PlayerRating> playerRatings;
  
  // Метадані
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  Match({
    required this.id,
    required this.title,
    required this.description,
    required this.organizerId,
    required this.organizerName,
    required this.date,
    required this.time,
    required this.location,
    required this.city,
    this.coordinates,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.participants,
    this.pendingApplications = const [],
    this.rejectedApplications = const [],
    required this.level,
    required this.cost,
    required this.autoBalance,
    required this.isPrivate,
    this.invitedFriends = const [],
    required this.status,
    this.teamA,
    this.teamB,
    this.teams = const [],

    this.teamCount,
    this.multiTeamStats = const [],
    this.isTeamMatch = false,
    this.teamAId,
    this.teamBId,
    this.teamAStatus,
    this.teamBStatus,
    this.teamRosters = const {},
    this.teamRosterStatus = const {},
    this.goalsByPlayer = const {},
    this.teamsReadyNotified = false,
    this.teamsReadyNotifiedAt,
    this.coverPhotoUrl,
    this.coverPhotoUpdatedAt,
    this.result,
    this.teamAScore,
    this.teamBScore,
    this.playerRatings = const [],
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.finishedAt,
  });

  static DateTime _readReqDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _readOptDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static GeoPoint? _readGeo(dynamic v) {
    if (v == null) return null;
    if (v is GeoPoint) return v;
    if (v is Map) {
      final lat = v['latitude'];
      final lng = v['longitude'];
      if (lat is num && lng is num) {
        return GeoPoint(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  /// JSON map shaped like legacy Firestore `matches` documents (Supabase `document` jsonb).
  factory Match.fromJsonMap(Map<String, dynamic> data, {required String id}) {
    final createdAtTs = data['createdAt'] as Timestamp?;
    final updatedAtTs = data['updatedAt'] as Timestamp?;

    return Match(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      date: _readReqDate(data['date']),
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      city: data['city'] ?? '',
      coordinates: _readGeo(data['coordinates']),
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
      teamsReadyNotifiedAt: _readOptDate(data['teamsReadyNotifiedAt']),
      coverPhotoUrl: data['coverPhotoUrl'] as String?,
      coverPhotoUpdatedAt: _readOptDate(data['coverPhotoUpdatedAt']),
teams: ((data['teams'] as List?) ?? const [])
    .whereType<Map<String, dynamic>>()
    .map((t) => Team(
          name: (t['name'] ?? '') as String,
          playerIds: List<String>.from(t['playerIds'] ?? const []),
          averageRating: ((t['averageRating'] ?? 0.0) as num).toDouble(),
        ))
    .toList(),
teamCount: (data['teamCount'] as num?)?.toInt()
  ?? (data['teams'] is List ? (data['teams'] as List).length : null),
result: data['result'] != null ? MatchResult.values.firstWhere(
  (e) => e.toString().split('.').last == data['result'],
  orElse: () => MatchResult.draw,
) : null,
teamAScore: data['teamAScore'],
      teamBScore: data['teamBScore'],
      playerRatings: ((data['playerRatings'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => PlayerRating(
                playerId: item['playerId'] ?? '',
                ratedBy: item['ratedBy'] ?? '',
                rating: ((item['rating'] ?? 0.0) as num).toDouble(),
                ratedAt: _readReqDate(item['ratedAt']),
                criteria: Map<String, double>.from(
                  (item['criteria'] ?? const <String, num>{})
                      .map((k, v) => MapEntry(k, (v as num).toDouble())),
                ),
              ))
          .toList(),
      createdAt: createdAtTs != null
          ? createdAtTs.toDate()
          : _readOptDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: updatedAtTs != null
          ? updatedAtTs.toDate()
          : _readOptDate(data['updatedAt']) ?? DateTime.now(),
      startedAt: _readOptDate(data['startedAt']),
      finishedAt: _readOptDate(data['finishedAt']),
    );
  }

  // Створення з Firestore
  factory Match.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Match.fromJsonMap({}, id: doc.id);
    }
    return Match.fromJsonMap(Map<String, dynamic>.from(raw as Map), id: doc.id);
  }

  dynamic _writeStorageDate(DateTime? d) =>
      d == null ? null : d.toUtc().toIso8601String();

  Map<String, dynamic>? _writeStorageGeo(GeoPoint? g) => g == null
      ? null
      : <String, dynamic>{'latitude': g.latitude, 'longitude': g.longitude};

  /// Serializable map for Supabase `matches.document` (ISO-8601 dates, geo as map).
  Map<String, dynamic> toStorageJson() {
    return {
      'title': title,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'date': _writeStorageDate(date),
      'time': time,
      'location': location,
      'city': city,
      'coordinates': _writeStorageGeo(coordinates),
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
      'teamA': teamA?.toFirestore(),
      'teamB': teamB?.toFirestore(),
      'teams': teams.map((t) => t.toFirestore()).toList(),
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
      'teamsReadyNotifiedAt': _writeStorageDate(teamsReadyNotifiedAt),
      'coverPhotoUrl': coverPhotoUrl,
      'coverPhotoUpdatedAt': _writeStorageDate(coverPhotoUpdatedAt),
      'result': result?.toString().split('.').last,
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'playerRatings': playerRatings
          .map((rating) => {
                'playerId': rating.playerId,
                'ratedBy': rating.ratedBy,
                'rating': rating.rating,
                'ratedAt': _writeStorageDate(rating.ratedAt),
                'criteria': rating.criteria,
              })
          .toList(),
      'createdAt': _writeStorageDate(createdAt),
      'updatedAt': _writeStorageDate(updatedAt),
      'startedAt': _writeStorageDate(startedAt),
      'finishedAt': _writeStorageDate(finishedAt),
    };
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
      'teamA': teamA?.toFirestore(),
      'teamB': teamB?.toFirestore(),
      'teams': teams.map((t) => t.toFirestore()).toList(),
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
      'playerRatings': playerRatings.map((rating) => rating.toFirestore()).toList(),
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
    Team? teamA,
    Team? teamB,
    List<Team>? teams,
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
    List<PlayerRating>? playerRatings,
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

  List<Team> get allTeams {
  if (teams.isNotEmpty) return teams;
  final result = <Team>[];
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Match && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
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