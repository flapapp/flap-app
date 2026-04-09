/// Domain-level match persistence / validation errors.
class MatchFailure implements Exception {
  const MatchFailure({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'MatchFailure($code): $message';
}
