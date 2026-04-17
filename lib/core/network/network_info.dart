/// Placeholder for connectivity / HTTP client wiring.
/// Migrate environment-specific configuration here as the app grows.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}
