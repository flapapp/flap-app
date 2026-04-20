/// Registration payload (domain).
class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}
