/// Authenticated user (domain).
class AuthUser {
  const AuthUser({required this.uid});

  final String uid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
