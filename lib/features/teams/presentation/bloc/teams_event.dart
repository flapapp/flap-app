import 'package:equatable/equatable.dart';

sealed class TeamsEvent extends Equatable {
  const TeamsEvent();

  @override
  List<Object?> get props => [];
}

class TeamsMyTeamsListenRequested extends TeamsEvent {
  const TeamsMyTeamsListenRequested(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class TeamsMyTeamsListenCancelled extends TeamsEvent {
  const TeamsMyTeamsListenCancelled();
}
