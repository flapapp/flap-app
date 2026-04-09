import 'package:equatable/equatable.dart';

abstract class ChallengesEvent extends Equatable {
  const ChallengesEvent();

  @override
  List<Object?> get props => [];
}

class ChallengesStarted extends ChallengesEvent {
  const ChallengesStarted();
}
