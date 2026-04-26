import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../../core/json/json_converters.dart';
import '../../data/models/match_converters.dart';
import 'match_enums.dart';
import 'match_team_entity.dart';
import 'player_rating_entity.dart';

class MatchEntity extends Equatable {
  const MatchEntity({
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
    this.sentInvitesCount = 0,
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

  final String id;
  final String title;
  final String description;
  final String organizerId;
  final String organizerName;
  @IsoDateTimeConverter()
  final DateTime date;
  final String time;
  final String location;
  final String city;
  @LatLngConverter()
  final LatLng? coordinates;
  final int currentPlayers;
  final int maxPlayers;
  final List<String> participants;
  final List<String> pendingApplications;
  final List<String> rejectedApplications;
  final MatchLevel level;
  final double cost;
  final bool autoBalance;
  final bool isPrivate;
  final List<String> invitedFriends;
  final int sentInvitesCount;
  final MatchStatus status;
  @MatchTeamEntityConverter()
  final MatchTeamEntity? teamA;
  @MatchTeamEntityConverter()
  final MatchTeamEntity? teamB;
  @MatchTeamEntityListConverter()
  final List<MatchTeamEntity> teams;
  final int? teamCount;
  @MultiTeamStatsConverter()
  final List<Map<String, dynamic>> multiTeamStats;
  @JsonKey(name: 'teamMatch')
  final bool isTeamMatch;
  final String? teamAId;
  final String? teamBId;
  final String? teamAStatus;
  final String? teamBStatus;
  @TeamRostersConverter()
  final Map<String, List<String>> teamRosters;
  @TeamRosterStatusConverter()
  final Map<String, Map<String, String>> teamRosterStatus;
  @GoalsByPlayerConverter()
  final Map<String, int> goalsByPlayer;
  final bool teamsReadyNotified;
  @IsoDateTimeNullableConverter()
  final DateTime? teamsReadyNotifiedAt;
  final String? coverPhotoUrl;
  @IsoDateTimeNullableConverter()
  final DateTime? coverPhotoUpdatedAt;
  @MatchResultNullableConverter()
  final MatchResult? result;
  final int? teamAScore;
  final int? teamBScore;
  @PlayerRatingEntityListConverter()
  final List<PlayerRatingEntity> playerRatings;
  @IsoDateTimeConverter()
  final DateTime createdAt;
  @IsoDateTimeConverter()
  final DateTime updatedAt;
  @IsoDateTimeNullableConverter()
  final DateTime? startedAt;
  @IsoDateTimeNullableConverter()
  final DateTime? finishedAt;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        organizerId,
        organizerName,
        date,
        time,
        location,
        city,
        coordinates,
        currentPlayers,
        maxPlayers,
        participants,
        pendingApplications,
        rejectedApplications,
        level,
        cost,
        autoBalance,
        isPrivate,
        invitedFriends,
        sentInvitesCount,
        status,
        teamA,
        teamB,
        teams,
        teamCount,
        multiTeamStats,
        isTeamMatch,
        teamAId,
        teamBId,
        teamAStatus,
        teamBStatus,
        teamRosters,
        teamRosterStatus,
        goalsByPlayer,
        teamsReadyNotified,
        teamsReadyNotifiedAt,
        coverPhotoUrl,
        coverPhotoUpdatedAt,
        result,
        teamAScore,
        teamBScore,
        playerRatings,
        createdAt,
        updatedAt,
        startedAt,
        finishedAt,
      ];
}
