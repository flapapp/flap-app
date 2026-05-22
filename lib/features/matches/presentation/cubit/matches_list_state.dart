import 'package:equatable/equatable.dart';

import '../../data/models/match.dart';

enum MatchesListStatus { initial, loading, ready, error }

class MatchesListState extends Equatable {
  const MatchesListState({
    this.status = MatchesListStatus.initial,
    this.availableMatches = const [],
    this.userMatches = const [],
    this.errorMessage,
  });

  final MatchesListStatus status;
  final List<Match> availableMatches;
  final List<Match> userMatches;
  final String? errorMessage;

  List<Match> get historyMatches {
    final finished = userMatches
        .where((m) => m.status == MatchStatus.finished)
        .toList(growable: false);
    finished.sort((a, b) => b.date.compareTo(a.date));
    return finished;
  }

  bool get isLoading => status == MatchesListStatus.loading;

  MatchesListState copyWith({
    MatchesListStatus? status,
    List<Match>? availableMatches,
    List<Match>? userMatches,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MatchesListState(
      status: status ?? this.status,
      availableMatches: availableMatches ?? this.availableMatches,
      userMatches: userMatches ?? this.userMatches,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, availableMatches, userMatches, errorMessage];
}
