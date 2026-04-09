import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/app_auth_context.dart';

import '../../domain/repositories/badge_repository.dart';
import 'badge_store_event.dart';
import 'badge_store_state.dart';

class BadgeStoreBloc extends Bloc<BadgeStoreEvent, BadgeStoreState> {
  BadgeStoreBloc(this._repository) : super(const BadgeStoreInitial()) {
    on<BadgeStoreLoadRequested>(_onLoadRequested);
  }

  final BadgeRepository _repository;

  Future<void> _onLoadRequested(
    BadgeStoreLoadRequested event,
    Emitter<BadgeStoreState> emit,
  ) async {
    emit(const BadgeStoreLoading());
    try {
      final uid = AppAuthContext.userId;
      if (uid == null) {
        emit(const BadgeStoreFailure(message: 'Not signed in'));
        return;
      }
      await _repository.initializeDefaultBadges();
      final badges = await _repository.getAvailableBadges();
      final userIds = await _repository.getUserBadgeIds(uid);
      final coins = await _repository.getUserCoins(uid);
      emit(BadgeStoreReady(
        allBadges: badges,
        userBadgeIds: userIds,
        coins: coins,
      ));
    } catch (e) {
      emit(BadgeStoreFailure(message: e.toString()));
    }
  }
}
