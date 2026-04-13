import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/presentation/models/pending_club_invite.dart';

abstract class TeamCreationEvent extends Equatable {
  const TeamCreationEvent();

  @override
  List<Object?> get props => [];
}

class TeamCreationSubmitClubIdentity extends TeamCreationEvent {
  const TeamCreationSubmitClubIdentity({
    required this.teamName,
    required this.shortName,
    this.foundedYear,
    required this.country,
    required this.city,
    required this.manifesto,
  });

  final String teamName;
  final String shortName;
  final int? foundedYear;
  final String country;
  final String city;
  final String manifesto;

  @override
  List<Object?> get props =>
      [teamName, shortName, foundedYear, country, city, manifesto];
}

class TeamCreationSubmitBranding extends TeamCreationEvent {
  const TeamCreationSubmitBranding({
    this.primaryHex,
    this.secondaryHex,
    this.logoBytes,
  });

  final String? primaryHex;
  final String? secondaryHex;
  final Uint8List? logoBytes;

  @override
  List<Object?> get props => [primaryHex, secondaryHex, logoBytes];
}

class TeamCreationGenerateSquadRequested extends TeamCreationEvent {
  const TeamCreationGenerateSquadRequested();
}

class TeamCreationAddPlayerRequested extends TeamCreationEvent {
  const TeamCreationAddPlayerRequested(this.player);

  final Player player;

  @override
  List<Object?> get props => [player];
}

class TeamCreationRemovePlayerRequested extends TeamCreationEvent {
  const TeamCreationRemovePlayerRequested(this.jerseyNumber);

  final int jerseyNumber;

  @override
  List<Object?> get props => [jerseyNumber];
}

class TeamCreationSubmitTeam extends TeamCreationEvent {
  const TeamCreationSubmitTeam({required this.isPublic});

  final bool isPublic;

  @override
  List<Object?> get props => [isPublic];
}

class TeamCreationWizardStepChanged extends TeamCreationEvent {
  const TeamCreationWizardStepChanged(this.stepIndex);

  final int stepIndex;

  @override
  List<Object?> get props => [stepIndex];
}

class TeamCreationClearError extends TeamCreationEvent {
  const TeamCreationClearError();
}

class TeamCreationPendingInviteAdded extends TeamCreationEvent {
  const TeamCreationPendingInviteAdded(this.invite);

  final PendingClubInvite invite;

  @override
  List<Object?> get props => [invite];
}

class TeamCreationPendingInviteRemoved extends TeamCreationEvent {
  const TeamCreationPendingInviteRemoved(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}
