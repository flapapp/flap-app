import '../../domain/entities/registration_profile.dart';

class RegistrationProfileModel {
  const RegistrationProfileModel({
    required this.name,
    required this.surname,
    required this.email,
  });

  factory RegistrationProfileModel.fromEntity(RegistrationProfile profile) {
    return RegistrationProfileModel(
      name: profile.name,
      surname: profile.surname,
      email: profile.email,
    );
  }

  final String name;
  final String surname;
  final String email;

  String get displayFullName => '$name $surname'.trim();

  /// First profile write after sign-up: identity + `profile_complete = false`.
  Map<String, dynamic> toMinimalSupabasePayload({required DateTime updatedAt}) {
    return {
      'name': name,
      'surname': surname,
      'email': email,
      'display_name': displayFullName,
      'profile_complete': false,
      'rating': 0.0,
      'match_rating': 0.0,
      'video_rating': 0.0,
      'total_matches': 0,
      'total_videos': 0,
      'rating_history': <dynamic>[],
      'coins': 0,
      'matches': 0,
      'goals': 0,
      'assists': 0,
      'subscription': null,
      'subscription_expiry': null,
      'subscription_active': false,
      'challenges_created': 0,
      'max_challenges_per_month': 0,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
