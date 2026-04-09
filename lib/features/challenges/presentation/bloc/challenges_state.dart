import 'package:equatable/equatable.dart';
import 'package:flap_app/models/challenge.dart';

abstract class ChallengesState extends Equatable {
  const ChallengesState();

  @override
  List<Object?> get props => [];
}

class ChallengesInitial extends ChallengesState {
  const ChallengesInitial();
}

class ChallengesLoading extends ChallengesState {
  const ChallengesLoading();
}

class ChallengesReady extends ChallengesState {
  const ChallengesReady(this.challenges);

  final List<Challenge> challenges;

  @override
  List<Object?> get props => [challenges];
}

class ChallengesFailure extends ChallengesState {
  const ChallengesFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
