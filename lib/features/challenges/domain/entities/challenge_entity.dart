import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ChallengeType {
  goal,
  shotPower,
  pass,
  longPass,
  dribbling,
  tackle,
  defending,
  penalty,
  save,
  wall,
  strategy,
  trick,
  other,
}

@JsonEnum()
enum ChallengeAudience {
  friends,
  city,
  country,
  world,
}

@JsonEnum()
enum ChallengeStatus {
  recruiting,
  submission,
  voting,
  completed,
}

class ChallengeEntity extends Equatable {
  ChallengeEntity({
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
    Map<String, int>? winnerPrizes,
    required this.isActive,
    this.imageUrl,
    required this.tags,
  }) : winnerPrizes = winnerPrizes ?? const {};

  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final ChallengeAudience audience;
  final String creatorId;
  final String creatorName;
  final String? creatorVideoUrl;
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
  final Map<String, double> votes;
  final Map<String, Map<String, double>> detailedVotes;
  final List<String> winners;
  final Map<String, double> finalScores;
  final Map<String, int> winnerPrizes;
  final bool isActive;
  final String? imageUrl;
  final List<String> tags;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        audience,
        creatorId,
        creatorName,
        creatorVideoUrl,
        city,
        entryFee,
        duration,
        createdAt,
        startDate,
        submissionDeadline,
        votingDeadline,
        endDate,
        status,
        maxParticipants,
        currentParticipants,
        prizePool,
        participants,
        submissions,
        votes,
        detailedVotes,
        winners,
        finalScores,
        winnerPrizes,
        isActive,
        imageUrl,
        tags,
      ];
}
