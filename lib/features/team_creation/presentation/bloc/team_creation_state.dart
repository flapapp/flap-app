import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/presentation/models/pending_club_invite.dart';

enum TeamCreationStatus {
  initial,
  loading,
  stepProgress,
  squadReady,
  success,
  error,
}

class TeamCreationState extends Equatable {
  const TeamCreationState({
    required this.status,
    this.stepIndex = 0,
    this.maxStepVisited = 0,
    this.teamName = '',
    this.shortName = '',
    this.foundedYear,
    this.country = '',
    this.city = '',
    this.manifesto = '',
    this.primaryHex,
    this.secondaryHex,
    this.logoBytes,
    this.squad = const [],
    this.isPublic = true,
    this.errorMessage,
    this.createdTeamId,
    this.pendingInvites = const [],
  });

  final TeamCreationStatus status;
  final int stepIndex;
  /// Highest wizard step the user has unlocked (0–3); used for tap / "next" navigation.
  final int maxStepVisited;
  final String teamName;
  final String shortName;
  final int? foundedYear;
  final String country;
  final String city;
  final String manifesto;
  final String? primaryHex;
  final String? secondaryHex;
  final Uint8List? logoBytes;
  final List<Player> squad;
  final bool isPublic;
  final String? errorMessage;
  final String? createdTeamId;
  final List<PendingClubInvite> pendingInvites;

  factory TeamCreationState.initial() => const TeamCreationState(
        status: TeamCreationStatus.stepProgress,
        stepIndex: 0,
        maxStepVisited: 0,
      );

  TeamCreationState copyWith({
    TeamCreationStatus? status,
    int? stepIndex,
    int? maxStepVisited,
    String? teamName,
    String? shortName,
    int? foundedYear,
    String? country,
    String? city,
    String? manifesto,
    String? primaryHex,
    String? secondaryHex,
    Uint8List? logoBytes,
    List<Player>? squad,
    bool? isPublic,
    String? errorMessage,
    String? createdTeamId,
    List<PendingClubInvite>? pendingInvites,
    bool clearError = false,
    bool clearLogo = false,
  }) {
    return TeamCreationState(
      status: status ?? this.status,
      stepIndex: stepIndex ?? this.stepIndex,
      maxStepVisited: maxStepVisited ?? this.maxStepVisited,
      teamName: teamName ?? this.teamName,
      shortName: shortName ?? this.shortName,
      foundedYear: foundedYear ?? this.foundedYear,
      country: country ?? this.country,
      city: city ?? this.city,
      manifesto: manifesto ?? this.manifesto,
      primaryHex: primaryHex ?? this.primaryHex,
      secondaryHex: secondaryHex ?? this.secondaryHex,
      logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
      squad: squad ?? this.squad,
      isPublic: isPublic ?? this.isPublic,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdTeamId: createdTeamId ?? this.createdTeamId,
      pendingInvites: pendingInvites ?? this.pendingInvites,
    );
  }

  @override
  List<Object?> get props => [
        status,
        stepIndex,
        maxStepVisited,
        teamName,
        shortName,
        foundedYear,
        country,
        city,
        manifesto,
        primaryHex,
        secondaryHex,
        logoBytes,
        squad,
        isPublic,
        errorMessage,
        createdTeamId,
        pendingInvites,
      ];
}
