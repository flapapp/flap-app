import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/models/app_team.dart';

import '../../domain/repositories/teams_repository.dart';
import 'teams_event.dart';
import 'teams_state.dart';

class TeamsBloc extends Bloc<TeamsEvent, TeamsState> {
  TeamsBloc(this._repo) : super(const TeamsState()) {
    on<TeamsMyTeamsListenRequested>(_onListenMyTeams);
    on<TeamsMyTeamsListenCancelled>(_onCancelListen);
  }

  final TeamsRepository _repo;
  StreamSubscription<List<AppTeam>>? _myTeamsSub;

  Future<void> _onListenMyTeams(
    TeamsMyTeamsListenRequested event,
    Emitter<TeamsState> emit,
  ) async {
    await _myTeamsSub?.cancel();
    emit(state.copyWith(myTeamsLoading: true));
    _myTeamsSub = _repo.watchUserTeams(event.userId).listen(
      (teams) {
        if (!isClosed) {
          emit(state.copyWith(myTeams: teams, myTeamsLoading: false));
        }
      },
      onError: (_) {
        if (!isClosed) {
          emit(state.copyWith(myTeamsLoading: false));
        }
      },
    );
  }

  Future<void> _onCancelListen(
    TeamsMyTeamsListenCancelled event,
    Emitter<TeamsState> emit,
  ) async {
    await _myTeamsSub?.cancel();
    _myTeamsSub = null;
    emit(const TeamsState());
  }

  @override
  Future<void> close() async {
    await _myTeamsSub?.cancel();
    return super.close();
  }
}
