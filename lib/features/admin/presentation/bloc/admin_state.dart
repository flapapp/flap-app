import 'package:equatable/equatable.dart';

sealed class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminActionInProgress extends AdminState {
  const AdminActionInProgress();
}

class AdminDeleteSuccess extends AdminState {
  const AdminDeleteSuccess();
}

class AdminDeleteFailure extends AdminState {
  const AdminDeleteFailure({required this.code, this.message});

  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];
}
