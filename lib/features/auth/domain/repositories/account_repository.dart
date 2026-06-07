/// Account lifecycle operations beyond session resolution (domain contract).
abstract class AccountRepository {
  /// Permanently deletes the currently authenticated user and all owned data.
  ///
  /// Backed by the `delete_account` SECURITY DEFINER RPC, which removes the
  /// auth user; database cascades take care of every dependent row.
  Future<void> deleteAccount();
}
