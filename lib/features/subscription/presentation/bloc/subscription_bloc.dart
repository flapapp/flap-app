import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/core/app_auth_context.dart';

import '../../domain/usecases/cancel_subscription_usecase.dart';
import '../../domain/usecases/load_user_subscription_usecase.dart';
import '../../domain/usecases/purchase_subscription_usecase.dart';
import '../../domain/usecases/start_champions_trial_usecase.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc({
    required LoadUserSubscriptionUseCase loadUserSubscription,
    required PurchaseSubscriptionUseCase purchaseSubscription,
    required StartChampionsTrialUseCase startChampionsTrial,
    required CancelSubscriptionUseCase cancelSubscription,
  })  : _loadUserSubscription = loadUserSubscription,
        _purchaseSubscription = purchaseSubscription,
        _startChampionsTrial = startChampionsTrial,
        _cancelSubscription = cancelSubscription,
        super(const SubscriptionInitial()) {
    on<SubscriptionStarted>(_onStarted);
    on<SubscriptionRefreshed>(_onRefreshed);
    on<SubscriptionPurchaseRequested>(_onPurchaseRequested);
    on<SubscriptionTrialRequested>(_onTrialRequested);
    on<SubscriptionCancelRequested>(_onCancelRequested);
  }

  final LoadUserSubscriptionUseCase _loadUserSubscription;
  final PurchaseSubscriptionUseCase _purchaseSubscription;
  final StartChampionsTrialUseCase _startChampionsTrial;
  final CancelSubscriptionUseCase _cancelSubscription;

  Future<void> _onStarted(
    SubscriptionStarted event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _onRefreshed(
    SubscriptionRefreshed event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _load(Emitter<SubscriptionState> emit) async {
    emit(const SubscriptionLoadInProgress());
    try {
      final uid = AppAuthContext.userId;
      if (uid == null) {
        emit(const SubscriptionReady(null));
        return;
      }
      final sub = await _loadUserSubscription(uid);
      emit(SubscriptionReady(sub));
    } catch (e) {
      emit(SubscriptionFailure(e.toString()));
    }
  }

  Future<void> _onPurchaseRequested(
    SubscriptionPurchaseRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoadInProgress());
    try {
      await _purchaseSubscription(event.type);
      final uid = AppAuthContext.userId;
      if (uid == null) {
        emit(const SubscriptionReady(null));
        return;
      }
      final sub = await _loadUserSubscription(uid);
      emit(SubscriptionReady(sub));
    } catch (e) {
      emit(SubscriptionFailure(e.toString()));
    }
  }

  Future<void> _onTrialRequested(
    SubscriptionTrialRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoadInProgress());
    try {
      await _startChampionsTrial();
      final uid = AppAuthContext.userId;
      if (uid == null) {
        emit(const SubscriptionReady(null));
        return;
      }
      final sub = await _loadUserSubscription(uid);
      emit(SubscriptionReady(sub));
    } catch (e) {
      emit(SubscriptionFailure(e.toString()));
    }
  }

  Future<void> _onCancelRequested(
    SubscriptionCancelRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoadInProgress());
    try {
      await _cancelSubscription();
      final uid = AppAuthContext.userId;
      if (uid == null) {
        emit(const SubscriptionReady(null));
        return;
      }
      final sub = await _loadUserSubscription(uid);
      emit(SubscriptionReady(sub));
    } catch (e) {
      emit(SubscriptionFailure(e.toString()));
    }
  }
}
