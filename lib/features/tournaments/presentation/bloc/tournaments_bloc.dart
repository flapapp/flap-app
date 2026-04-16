import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/tournaments_repository.dart';
import 'tournaments_event.dart';
import 'tournaments_state.dart';

class TournamentsBloc extends Bloc<TournamentsEvent, TournamentsState> {
  TournamentsBloc(this._repository) : super(const TournamentsInitial()) {
    on<TournamentsStarted>(_onLoad);
    on<TournamentCreateRequested>(_onCreate);
  }

  final TournamentsRepository _repository;

  Future<void> _onLoad(
    TournamentsStarted event,
    Emitter<TournamentsState> emit,
  ) async {
    emit(const TournamentsLoading());
    try {
      final items = await _repository.listTournaments();
      emit(TournamentsReady(items));
    } catch (e) {
      emit(TournamentsFailure(e.toString()));
    }
  }

  Future<void> _onCreate(
    TournamentCreateRequested event,
    Emitter<TournamentsState> emit,
  ) async {
    try {
      await _repository.createTournament(
        name: event.name,
        type: event.type,
        maxTeams: event.maxTeams,
        startDate: event.startDate,
        endDate: event.endDate,
        rules: event.rules,
      );
      add(const TournamentsStarted());
    } catch (e) {
      emit(TournamentsFailure(e.toString()));
    }
  }
}
