import 'package:equatable/equatable.dart';

import '../../domain/entities/wallet_snapshot.dart';
import '../../domain/entities/wallet_transaction.dart';

sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {
  const WalletInitial();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

class WalletReady extends WalletState {
  const WalletReady({
    required this.wallet,
    required this.transactions,
  });

  final WalletSnapshot? wallet;
  final List<WalletTransaction> transactions;

  @override
  List<Object?> get props => [wallet, transactions];
}

class WalletFailure extends WalletState {
  const WalletFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
