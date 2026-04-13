import 'dart:math' show max;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/team_creation/domain/entities/team.dart';
import 'package:flap_app/features/team_creation/domain/usecases/add_player_usecase.dart';
import 'package:flap_app/features/team_creation/domain/usecases/create_team_usecase.dart';
import 'package:flap_app/features/team_creation/domain/usecases/generate_squad_usecase.dart';
import 'package:flap_app/features/teams/domain/repositories/teams_repository.dart';

import 'team_creation_event.dart';
import 'team_creation_state.dart';

class TeamCreationBloc extends Bloc<TeamCreationEvent, TeamCreationState> {
  TeamCreationBloc({
    required CreateTeamUseCase createTeam,
    required GenerateSquadUseCase generateSquad,
    required AddPlayerUseCase addPlayerUseCase,
    required TeamsRepository teamsRepository,
    required String userId,
  })  : _createTeam = createTeam,
        _generateSquad = generateSquad,
        _addPlayer = addPlayerUseCase,
        _teamsRepository = teamsRepository,
        _userId = userId,
        super(TeamCreationState.initial()) {
    on<TeamCreationSubmitClubIdentity>(_onSubmitClubIdentity);
    on<TeamCreationSubmitBranding>(_onSubmitBranding);
    on<TeamCreationGenerateSquadRequested>(_onGenerateSquad);
    on<TeamCreationAddPlayerRequested>(_onAddPlayer);
    on<TeamCreationRemovePlayerRequested>(_onRemovePlayer);
    on<TeamCreationSubmitTeam>(_onSubmitTeam);
    on<TeamCreationWizardStepChanged>(_onStepChanged);
    on<TeamCreationClearError>(_onClearError);
    on<TeamCreationPendingInviteAdded>(_onPendingInviteAdded);
    on<TeamCreationPendingInviteRemoved>(_onPendingInviteRemoved);
  }

  final CreateTeamUseCase _createTeam;
  final GenerateSquadUseCase _generateSquad;
  final AddPlayerUseCase _addPlayer;
  final TeamsRepository _teamsRepository;
  final String _userId;

  void _onStepChanged(
    TeamCreationWizardStepChanged event,
    Emitter<TeamCreationState> emit,
  ) {
    final next = event.stepIndex.clamp(0, 3);
    emit(
      state.copyWith(
        stepIndex: next,
        maxStepVisited: max(state.maxStepVisited, next),
      ),
    );
  }

  void _onClearError(
    TeamCreationClearError event,
    Emitter<TeamCreationState> emit,
  ) {
    emit(
      state.copyWith(
        clearError: true,
        status: TeamCreationStatus.stepProgress,
      ),
    );
  }

  Future<void> _onSubmitClubIdentity(
    TeamCreationSubmitClubIdentity event,
    Emitter<TeamCreationState> emit,
  ) async {
    final sn = event.shortName.trim();
    if (sn.isNotEmpty && sn.length > 5) {
      emit(
        state.copyWith(
          status: TeamCreationStatus.error,
          errorMessage: 'short_name_len',
        ),
      );
      return;
    }
    if (event.teamName.trim().length < 3) {
      emit(
        state.copyWith(
          status: TeamCreationStatus.error,
          errorMessage: 'name_short',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TeamCreationStatus.stepProgress,
        stepIndex: 1,
        maxStepVisited: max(state.maxStepVisited, 1),
        teamName: event.teamName.trim(),
        shortName: sn,
        foundedYear: event.foundedYear,
        country: event.country.trim(),
        city: event.city.trim(),
        manifesto: event.manifesto.trim(),
        clearError: true,
      ),
    );
  }

  void _onSubmitBranding(
    TeamCreationSubmitBranding event,
    Emitter<TeamCreationState> emit,
  ) {
    emit(
      state.copyWith(
        status: TeamCreationStatus.stepProgress,
        stepIndex: 2,
        maxStepVisited: max(state.maxStepVisited, 2),
        primaryHex: event.primaryHex,
        secondaryHex: event.secondaryHex,
        logoBytes: event.logoBytes,
        clearError: true,
      ),
    );
  }

  Future<void> _onGenerateSquad(
    TeamCreationGenerateSquadRequested event,
    Emitter<TeamCreationState> emit,
  ) async {
    emit(state.copyWith(status: TeamCreationStatus.loading, clearError: true));
    final squad = _generateSquad();
    emit(
      state.copyWith(
        status: TeamCreationStatus.squadReady,
        maxStepVisited: max(state.maxStepVisited, 2),
        squad: squad,
      ),
    );
  }

  void _onAddPlayer(
    TeamCreationAddPlayerRequested event,
    Emitter<TeamCreationState> emit,
  ) {
    final next = _addPlayer.tryAppendPlayer(state.squad, event.player);
    if (next == null) {
      emit(
        state.copyWith(
          status: TeamCreationStatus.error,
          errorMessage: 'add_player_invalid',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        squad: next,
        status: state.status == TeamCreationStatus.squadReady
            ? TeamCreationStatus.squadReady
            : TeamCreationStatus.stepProgress,
        clearError: true,
      ),
    );
  }

  void _onPendingInviteAdded(
    TeamCreationPendingInviteAdded event,
    Emitter<TeamCreationState> emit,
  ) {
    if (event.invite.userId == _userId) return;
    if (state.pendingInvites.any((e) => e.userId == event.invite.userId)) {
      return;
    }
    emit(
      state.copyWith(
        pendingInvites: [...state.pendingInvites, event.invite],
        status: state.status == TeamCreationStatus.squadReady
            ? TeamCreationStatus.squadReady
            : TeamCreationStatus.stepProgress,
      ),
    );
  }

  void _onPendingInviteRemoved(
    TeamCreationPendingInviteRemoved event,
    Emitter<TeamCreationState> emit,
  ) {
    emit(
      state.copyWith(
        pendingInvites: state.pendingInvites
            .where((e) => e.userId != event.userId)
            .toList(),
      ),
    );
  }

  void _onRemovePlayer(
    TeamCreationRemovePlayerRequested event,
    Emitter<TeamCreationState> emit,
  ) {
    final next =
        state.squad.where((p) => p.jerseyNumber != event.jerseyNumber).toList();
    emit(
      state.copyWith(
        squad: next,
        status: state.status == TeamCreationStatus.squadReady
            ? TeamCreationStatus.squadReady
            : TeamCreationStatus.stepProgress,
      ),
    );
  }

  Future<void> _onSubmitTeam(
    TeamCreationSubmitTeam event,
    Emitter<TeamCreationState> emit,
  ) async {
    final squadErr = _addPlayer.validateSquadForSubmit(state.squad);
    if (squadErr != null) {
      emit(
        state.copyWith(
          status: TeamCreationStatus.error,
          errorMessage: squadErr,
        ),
      );
      return;
    }

    emit(state.copyWith(status: TeamCreationStatus.loading, clearError: true));

    try {
      final team = Team(
        name: state.teamName,
        shortName: state.shortName.isEmpty ? null : state.shortName,
        foundedYear: state.foundedYear,
        country: state.country.isEmpty ? null : state.country,
        city: state.city.isEmpty ? null : state.city,
        primaryColor: state.primaryHex,
        secondaryColor: state.secondaryHex,
      );

      final id = await _createTeam(
        currentUserId: _userId,
        team: team,
        description: state.manifesto.isEmpty ? '' : state.manifesto,
        isPublic: event.isPublic,
        squad: state.squad,
        logoBytes: state.logoBytes,
      );

      final inviteTargets = state.pendingInvites
          .where((e) => e.userId != _userId)
          .map((e) => e.userId)
          .toSet()
          .toList();
      if (inviteTargets.isNotEmpty) {
        try {
          await _teamsRepository.invitePlayers(
            teamId: id,
            teamName: state.teamName,
            userIds: inviteTargets,
          );
        } catch (_) {
          // Club exists; invites are best-effort.
        }
      }

      emit(
        state.copyWith(
          status: TeamCreationStatus.success,
          createdTeamId: id,
          isPublic: event.isPublic,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeamCreationStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
