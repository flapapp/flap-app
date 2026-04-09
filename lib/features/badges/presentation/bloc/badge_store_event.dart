import 'package:equatable/equatable.dart';

sealed class BadgeStoreEvent extends Equatable {
  const BadgeStoreEvent();

  @override
  List<Object?> get props => [];
}

class BadgeStoreLoadRequested extends BadgeStoreEvent {
  const BadgeStoreLoadRequested();
}
