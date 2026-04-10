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
  Completer<void>? _myTeamsListenDone;

  Future<void> _stopMyTeamsListen() async {
    await _myTeamsSub?.cancel();
    _myTeamsSub = null;
    final done = _myTeamsListenDone;
    _myTeamsListenDone = null;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
  }

  Future<void> _onListenMyTeams(
    TeamsMyTeamsListenRequested event,
    Emitter<TeamsState> emit,
  ) async {
    await _stopMyTeamsListen();
    emit(state.copyWith(myTeamsLoading: true));
    final done = Completer<void>();
    _myTeamsListenDone = done;
    _myTeamsSub = _repo.watchUserTeams(event.userId).listen(
      (teams) {
        if (!emit.isDone) {
          emit(state.copyWith(myTeams: teams, myTeamsLoading: false));
        }
      },
      onError: (_, __) {
        if (!emit.isDone) {
          emit(state.copyWith(myTeamsLoading: false));
        }
      },
    );
    await done.future;
  }

  Future<void> _onCancelListen(
    TeamsMyTeamsListenCancelled event,
    Emitter<TeamsState> emit,
  ) async {
    await _stopMyTeamsListen();
    emit(const TeamsState());
  }

  @override
  Future<void> close() async {
    await _stopMyTeamsListen();
    return super.close();
  }
}
