import 'package:equatable/equatable.dart';

sealed class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class AdminDeleteAllChallengesRequested extends AdminEvent {
  const AdminDeleteAllChallengesRequested();
}
