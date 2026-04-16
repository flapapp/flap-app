import '../../domain/entities/wallet_snapshot.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._remote);

  final WalletRemoteDataSource _remote;

  @override
  Future<WalletSnapshot?> getMyWallet() async {
    final row = await _remote.fetchMyWallet();
    if (row == null) return null;
    return WalletSnapshot(
      id: row['id'].toString(),
      userId: row['user_id'].toString(),
      balance: (row['balance'] as num?)?.toDouble() ?? 0,
      lockedBalance: (row['locked_balance'] as num?)?.toDouble() ?? 0,
      currency: row['currency']?.toString() ?? 'ETB',
      totalEarned: (row['total_earned'] as num?)?.toDouble() ?? 0,
      totalSpent: (row['total_spent'] as num?)?.toDouble() ?? 0,
      status: row['status']?.toString() ?? 'ACTIVE',
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<List<WalletTransaction>> getMyTransactions({int limit = 50}) async {
    final rows = await _remote.fetchMyTransactions(limit: limit);
    return rows
        .map(
          (row) => WalletTransaction(
            id: row['id'].toString(),
            type: row['type']?.toString() ?? 'UNKNOWN',
            amount: (row['amount'] as num?)?.toDouble() ?? 0,
            currency: row['currency']?.toString() ?? 'ETB',
            status: row['status']?.toString() ?? 'PENDING',
            description: row['description']?.toString(),
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList(growable: false);
  }
}
