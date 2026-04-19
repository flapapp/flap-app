import 'package:equatable/equatable.dart';

class AppTeamEntity extends Equatable {
  const AppTeamEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.captainId,
    required this.viceCaptainIds,
    required this.memberIds,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.logoUrl,
    this.city,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.playerGoals = const {},
    this.recentMatches = const [],
  });

  final String id;
  final String name;
  final String description;
  final String captainId;
  final List<String> viceCaptainIds;
  final List<String> memberIds;
  final bool isPublic;
  final String? logoUrl;
  final String? city;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int wins;
  final int losses;
  final int draws;
  final int goalsFor;
  final int goalsAgainst;
  final Map<String, int> playerGoals;
  final List<Map<String, dynamic>> recentMatches;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        captainId,
        viceCaptainIds,
        memberIds,
        isPublic,
        logoUrl,
        city,
        createdAt,
        updatedAt,
        wins,
        losses,
        draws,
        goalsFor,
        goalsAgainst,
        playerGoals,
        recentMatches,
      ];
}
