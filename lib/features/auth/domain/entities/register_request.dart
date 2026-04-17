/// Registration payload (domain).
class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.surname,
    required this.email,
    required this.phone,
    required this.password,
    required this.city,
    required this.age,
    required this.position,
    required this.experience,
    this.avatarBytes,
  });

  final String name;
  final String surname;
  final String email;
  final String phone;
  final String password;
  final String city;
  final int age;
  final String position;
  final String experience;
  final List<int>? avatarBytes;
}
