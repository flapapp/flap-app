import 'dart:collection';

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
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

/// Supabase stores `pro`; app enum is [MatchLevel.professional] (`'professional'`).
MatchLevel _matchLevelFromLegacyData(dynamic raw) {
  final s = raw?.toString() ?? '';
  if (s == 'pro' || s == 'professional') {
    return MatchLevel.professional;
  }
  for (final e in MatchLevel.values) {
    if (e.name == s) {
      return e;
    }
  }
  return MatchLevel.intermediate;
}

/// Supabase stores snake_case (`in_progress`); embedded legacy docs may use enum names (`inProgress`).
MatchStatus _matchStatusFromLegacyData(dynamic raw) {
  final s = raw?.toString() ?? '';
  switch (s) {
    case 'open':
      return MatchStatus.open;
    case 'full':
      return MatchStatus.full;
    case 'in_progress':
    case 'inProgress':
      return MatchStatus.inProgress;
    case 'finished':
      return MatchStatus.finished;
    case 'cancelled':
      return MatchStatus.cancelled;
    default:
      for (final e in MatchStatus.values) {
        if (e.name == s) return e;
      }
      return MatchStatus.open;
  }
}

DateTime _matchReadDate(dynamic v, [DateTime? dflt]) {
  if (v == null) {
    return dflt ?? DateTime.now();
  }
  if (v is DateTime) {
    return v;
  }
  if (v is String) {
    return DateTime.tryParse(v) ?? dflt ?? DateTime.now();
  }
  return dflt ?? DateTime.now();
}

DateTime? _matchReadDateOrNull(dynamic v) {
  if (v == null) {
    return null;
  }
  if (v is DateTime) {
    return v;
  }
  if (v is String) {
    return DateTime.tryParse(v);
  }
  return null;
}

// Main match model
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
    super.sentInvitesCount = 0,
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

  /// Backwards-compatible wrapper (e.g. Firestore snapshot or compatible stub).
  factory Match.fromFirestore(dynamic doc) {
    final id = doc.id as String;
    final raw = doc.data();
    final data = Map<String, dynamic>.from(raw as Map);
    return Match.fromLegacyMap(id, data);
  }

  /// Legacy embedded document shape (Firestore or denormalized JSON).
  factory Match.fromLegacyMap(String id, Map<String, dynamic> data) {
    return Match(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      date: _matchReadDate(data['date']),
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      city: data['city'] ?? '',
      coordinates: const LatLngConverter().fromJson(data['coordinates']),
      currentPlayers: data['currentPlayers'] ?? 0,
      maxPlayers: data['maxPlayers'] ?? 0,
      participants: List<String>.from(data['participants'] ?? []),
      pendingApplications: List<String>.from(data['pendingApplications'] ?? []),
      rejectedApplications: List<String>.from(data['rejectedApplications'] ?? []),
      level: _matchLevelFromLegacyData(data['level']),
      cost: (data['cost'] ?? 0.0).toDouble(),
      autoBalance: data['autoBalance'] ?? false,
      isPrivate: data['isPrivate'] ?? false,
      invitedFriends: List<String>.from(data['invitedFriends'] ?? []),
      sentInvitesCount: (data['sentInvitesCount'] as num?)?.toInt() ?? 0,
      status: _matchStatusFromLegacyData(data['status']),
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
      teamsReadyNotifiedAt: _matchReadDateOrNull(data['teamsReadyNotifiedAt']),
      coverPhotoUrl: data['coverPhotoUrl'] as String?,
      coverPhotoUpdatedAt: _matchReadDateOrNull(data['coverPhotoUpdatedAt']),
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
                ratedAt: _matchReadDate(
                  item['ratedAt'],
                  DateTime.fromMillisecondsSinceEpoch(0),
                ),
                criteria: Map<String, double>.from(
                  (item['criteria'] ?? const <String, num>{})
                      .map((k, v) => MapEntry(k, (v as num).toDouble())),
                ),
              ))
          .toList(),
      createdAt: _matchReadDate(data['createdAt']),
      updatedAt: _matchReadDate(data['updatedAt']),
      startedAt: _matchReadDateOrNull(data['startedAt']),
      finishedAt: _matchReadDateOrNull(data['finishedAt']),
    );
  }

  /// Serialized map for persistence (ISO-8601 dates, lat/lng objects).
  Map<String, dynamic> toLegacyMap() {
    return {
      'title': title,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'date': date.toIso8601String(),
      'time': time,
      'location': location,
      'city': city,
      'coordinates': const LatLngConverter().toJson(coordinates),
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
      'sentInvitesCount': sentInvitesCount,
      'status': status.toString().split('.').last,
      'teamA': teamA == null ? null : (teamA as Team).toFirestore(),
      'teamB': teamB == null ? null : (teamB as Team).toFirestore(),
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
      'teamsReadyNotifiedAt': teamsReadyNotifiedAt?.toIso8601String(),
      'coverPhotoUrl': coverPhotoUrl,
      'coverPhotoUpdatedAt': coverPhotoUpdatedAt?.toIso8601String(),
      'result': result?.toString().split('.').last,
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'playerRatings': playerRatings
          .map((rating) => (rating as PlayerRating).toFirestore())
          .toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  /// Alias retained while migrating call sites.
  Map<String, dynamic> toFirestore() => toLegacyMap();

  // copyWith
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
    LatLng? coordinates,
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
    int? sentInvitesCount,
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
      sentInvitesCount: sentInvitesCount ?? this.sentInvitesCount,
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

  // Convenience getters
bool get isOpen => status == MatchStatus.open;
bool get isFull => status == MatchStatus.full;
bool get isInProgress => status == MatchStatus.inProgress;
bool get isFinished => status == MatchStatus.finished;
bool get isCancelled => status == MatchStatus.cancelled;

/// Local kickoff from legacy [date] + [time] (mapped from `scheduled_at`).
DateTime get scheduledDateTime {
  final d = date.toLocal();
  final raw = time.trim();
  final parsed = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(raw);
  if (parsed == null) {
    return DateTime(d.year, d.month, d.day, 0, 0);
  }
  final h = int.tryParse(parsed.group(1) ?? '') ?? 0;
  final m = int.tryParse(parsed.group(2) ?? '') ?? 0;
  return DateTime(
    d.year,
    d.month,
    d.day,
    h.clamp(0, 23),
    m.clamp(0, 59),
  );
}

/// `HH:mm` kickoff label for list cards (same rules as Mode Hub).
String get scheduledKickoffTimeLabel {
  final dt = scheduledDateTime;
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Unstarted match overdue by more than 24 hours.
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
  
  // User role checks
  bool isOrganizer(String userId) => organizerId == userId;
  bool isParticipant(String userId) => participants.contains(userId);

  /// Listed on a team roster with non-declined status, or present in [teamRosters] lists.
  /// Team matches often omit [participants]; this drives "My matches" visibility.
  bool isUserOnActiveTeamRoster(String userId) {
    for (final key in const ['teamA', 'teamB']) {
      final statuses = teamRosterStatus[key];
      if (statuses != null && statuses.containsKey(userId)) {
        final raw = statuses[userId] ?? '';
        final st = raw.toString().trim().toLowerCase();
        if (st != 'declined') return true;
        continue;
      }
      final roster = teamRosters[key];
      if (roster != null && roster.contains(userId)) return true;
    }
    return false;
  }

  /// Accepted participant row or active (non-declined) team roster row.
  bool isUserMatchMember(String userId) =>
      participants.contains(userId) || isUserOnActiveTeamRoster(userId);

  bool hasPendingApplication(String userId) => pendingApplications.contains(userId);
  bool wasRejected(String userId) => rejectedApplications.contains(userId);
  bool canJoin(String userId) => status == MatchStatus.open && 
                              !participants.contains(userId) && 
                              !pendingApplications.contains(userId) &&
                              !rejectedApplications.contains(userId) &&
                              currentPlayers < maxPlayers;
  
  // Whether teams exist (two squads or multi-team lineups from [teams]).
  bool get hasTeams =>
      (teamA != null && teamB != null) || teams.length >= 2;

  List<MatchTeamEntity> get allTeams {
    if (teams.isNotEmpty) return teams;
    final result = <MatchTeamEntity>[];
    if (teamA != null) result.add(teamA!);
    if (teamB != null) result.add(teamB!);
    return result;
  }
  
  // Status for the current user
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

  // Open slots count
  int get availableSpots => maxPlayers - currentPlayers;

  // Fill percentage
  double get fillPercentage {
    if (maxPlayers <= 0) return 0.0;
    return (currentPlayers / maxPlayers) * 100;
  }

  // Whether the user can rate
  bool canRate(String userId) => 
      participants.contains(userId) && 
      !playerRatings.any((rating) => rating.ratedBy == userId);
  
  String get levelText {
    switch (level) {
      case MatchLevel.beginner:
        return tr('beginner');
      case MatchLevel.intermediate:
        return tr('intermediate');
      case MatchLevel.advanced:
        return tr('advanced');
      case MatchLevel.professional:
        return tr('professional');
    }
  }

  String get statusText {
    switch (status) {
      case MatchStatus.open:
        return tr('status_open');
      case MatchStatus.full:
        return tr('status_full');
      case MatchStatus.inProgress:
        return tr('status_in_progress');
      case MatchStatus.finished:
        return tr('status_finished');
      case MatchStatus.cancelled:
        return tr('status_cancelled');
    }
  }

  String get costText => cost > 0
      ? tr('match_cost_uah', namedArgs: {'amount': '${cost.toInt()}'})
      : tr('match_cost_free');
  
  // Whether the user can manage
  bool canManage(String userId) => isOrganizer(userId);

  @override
  String toString() {
    return 'Match(id: $id, title: $title, status: $status)';
  }
}

// Match utilities
class MatchUtils {
  // Default team name generation
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
  
  // Average team rating
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
  
  // Whether the match can be started
  static bool canStartMatch(Match match) {
    final rosterA =
        match.teamRosters['teamA'] ?? match.teamA?.playerIds ?? const <String>[];
    final rosterB =
        match.teamRosters['teamB'] ?? match.teamB?.playerIds ?? const <String>[];

    if (match.isTeamMatch) {
      bool isReady(String? status) =>
          status == 'confirmed' || status == 'accepted';
      final teamAReady = isReady(match.teamAStatus);
      final teamBReady = isReady(match.teamBStatus);
      return teamAReady && teamBReady;
    }

    return match.isFull &&
        match.hasTeams &&
        rosterA.isNotEmpty &&
        rosterB.isNotEmpty;
  }
  
  // Whether the match can be finished
  static bool canFinishMatch(Match match) {
    return match.isInProgress && 
           match.hasTeams && 
           match.teamA!.playerIds.isNotEmpty && 
           match.teamB!.playerIds.isNotEmpty;
  }
}