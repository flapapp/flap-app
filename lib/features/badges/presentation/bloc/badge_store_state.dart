import 'package:equatable/equatable.dart';

import 'package:flap_app/models/badge.dart';

sealed class BadgeStoreState extends Equatable {
  const BadgeStoreState();

  @override
  List<Object?> get props => [];
}

class BadgeStoreInitial extends BadgeStoreState {
  const BadgeStoreInitial();
}

class BadgeStoreLoading extends BadgeStoreState {
  const BadgeStoreLoading();
}

class BadgeStoreReady extends BadgeStoreState {
  const BadgeStoreReady({
    required this.allBadges,
    required this.userBadgeIds,
    required this.coins,
  });

  final List<Badge> allBadges;
  final List<String> userBadgeIds;
  final int coins;

  @override
  List<Object?> get props => [allBadges, userBadgeIds, coins];
}

class BadgeStoreFailure extends BadgeStoreState {
  const BadgeStoreFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
