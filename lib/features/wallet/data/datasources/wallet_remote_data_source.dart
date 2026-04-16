abstract class WalletRemoteDataSource {
  Future<Map<String, dynamic>?> fetchMyWallet();

  Future<List<Map<String, dynamic>>> fetchMyTransactions({int limit = 50});
}
