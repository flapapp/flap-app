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
    this.result,
    this.teamAScore,
    this.teamBScore,
    this.playerRatings = const [],
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.finishedAt,
  });

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
      'teamA': teamA?.toFirestore(),
      'teamB': teamB?.toFirestore(),
      'teams': teams.map((t) => t.toFirestore()).toList(),
      'teamCount': teamCount,
      'multiTeamStats': multiTeamStats,
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
    'Веселі Бджілки', 'Швидкі Їжаки', 'Хитрі Лисички', 'Сильні Ведмеді',
    'Граційні Леопарди', 'Розумні Сови', 'Енергійні Кенгуру', 'Спритні Мавпи',
    'Гордовиті Леви', 'Мирні Панди', 'Швидкі Гепарди', 'Кумедні Пінгвіни'
  ];
  
  static String generateTeamName() {
    return teamNames[DateTime.now().millisecondsSinceEpoch % teamNames.length];
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
    return match.isFull && 
           match.hasTeams && 
           match.teamA!.playerIds.isNotEmpty && 
           match.teamB!.playerIds.isNotEmpty;
  }
  
  // Перевірка чи матч можна завершити
  static bool canFinishMatch(Match match) {
    return match.isInProgress && 
           match.hasTeams && 
           match.teamA!.playerIds.isNotEmpty && 
           match.teamB!.playerIds.isNotEmpty;
  }
}