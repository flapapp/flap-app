import 'package:equatable/equatable.dart';

import '../../domain/entities/tournament_summary.dart';

sealed class TournamentsState extends Equatable {
  const TournamentsState();

  @override
  List<Object?> get props => [];
}

class TournamentsInitial extends TournamentsState {
  const TournamentsInitial();
}

class TournamentsLoading extends TournamentsState {
  const TournamentsLoading();
}

class TournamentsReady extends TournamentsState {
  const TournamentsReady(this.items);

  final List<TournamentSummary> items;

  @override
  List<Object?> get props => [items];
}

class TournamentsFailure extends TournamentsState {
  const TournamentsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
