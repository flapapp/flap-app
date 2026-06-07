/// Server-side account operations (data layer contract).
abstract class AccountRemoteDataSource {
  /// Invokes the `delete_account` RPC, permanently removing the caller.
  Future<void> deleteAccount();
}
