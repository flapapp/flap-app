import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          WalletBloc(context.read<WalletRepository>())..add(const WalletStarted()),
      child: const _WalletView(),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: const Color(0xFF0f0f23),
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading || state is WalletInitial) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4caf50)),
            );
          }
          if (state is WalletFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }
          final ready = state as WalletReady;
          final wallet = ready.wallet;
          return RefreshIndicator(
            onRefresh: () async {
              context.read<WalletBloc>().add(const WalletRefreshed());
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: wallet == null
                      ? const Text(
                          'Wallet is not available for this account.',
                          style: TextStyle(color: Colors.white70),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Locked: ${wallet.lockedBalance.toStringAsFixed(2)} ${wallet.currency}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Earned: ${wallet.totalEarned.toStringAsFixed(2)} • Spent: ${wallet.totalSpent.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Transactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (ready.transactions.isEmpty)
                  const Text(
                    'No transactions yet.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ...ready.transactions.map(_TransactionTile.new),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.tx);

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final created = DateFormat('yyyy-MM-dd HH:mm').format(tx.createdAt.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          tx.type,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$created\n${tx.description ?? ''}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        isThreeLine: (tx.description ?? '').isNotEmpty,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${tx.amount.toStringAsFixed(2)} ${tx.currency}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              tx.status,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
