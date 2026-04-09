/// Domain-level friend / request errors for UI mapping.
class FriendFailure implements Exception {
  const FriendFailure({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'FriendFailure($code): $message';
}
