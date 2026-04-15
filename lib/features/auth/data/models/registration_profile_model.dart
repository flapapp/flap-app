import '../../domain/entities/registration_profile.dart';

class RegistrationProfileModel {
  const RegistrationProfileModel({
    required this.email,
    required this.username,
  });

  factory RegistrationProfileModel.fromEntity(RegistrationProfile profile) {
    return RegistrationProfileModel(
      email: profile.email,
      username: profile.username,
    );
  }

  final String email;
  final String username;

  /// First profile write after sign-up: identity + `profile_complete = false`.
  Map<String, dynamic> toMinimalSupabasePayload({required DateTime updatedAt}) {
    return {
      'email': email,
      'username': username,
      'profile_complete': false,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
