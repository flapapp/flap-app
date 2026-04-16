import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/wallet_repository.dart';
import 'wallet_event.dart';
import 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc(this._repository) : super(const WalletInitial()) {
    on<WalletStarted>(_onLoad);
    on<WalletRefreshed>(_onLoad);
  }

  final WalletRepository _repository;

  Future<void> _onLoad(
    WalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());
    try {
      final wallet = await _repository.getMyWallet();
      final transactions = await _repository.getMyTransactions(limit: 100);
      emit(WalletReady(wallet: wallet, transactions: transactions));
    } catch (e) {
      emit(WalletFailure(e.toString()));
    }
  }
}
