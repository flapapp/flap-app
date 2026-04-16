import 'package:equatable/equatable.dart';

sealed class TournamentsEvent extends Equatable {
  const TournamentsEvent();

  @override
  List<Object?> get props => [];
}

class TournamentsStarted extends TournamentsEvent {
  const TournamentsStarted();
}

class TournamentCreateRequested extends TournamentsEvent {
  const TournamentCreateRequested({
    required this.name,
    required this.type,
    this.maxTeams,
    this.startDate,
    this.endDate,
    this.rules,
  });

  final String name;
  final String type;
  final int? maxTeams;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic>? rules;

  @override
  List<Object?> get props => [name, type, maxTeams, startDate, endDate, rules];
}
