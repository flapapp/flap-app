import '../entities/wallet_snapshot.dart';
import '../entities/wallet_transaction.dart';

abstract class WalletRepository {
  Future<WalletSnapshot?> getMyWallet();

  Future<List<WalletTransaction>> getMyTransactions({int limit = 50});
}
