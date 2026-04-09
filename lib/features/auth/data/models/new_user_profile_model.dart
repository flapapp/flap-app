import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/new_user_profile.dart';

part 'new_user_profile_model.g.dart';

@JsonSerializable()
class NewUserProfileModel extends NewUserProfile {
  const NewUserProfileModel({
    required super.name,
    required super.surname,
    required super.email,
    required super.phone,
    required super.city,
    required super.age,
    required super.position,
    required super.experience,
  });

  factory NewUserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$NewUserProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$NewUserProfileModelToJson(this);

  factory NewUserProfileModel.fromEntity(NewUserProfile profile) {
    return NewUserProfileModel(
      name: profile.name,
      surname: profile.surname,
      email: profile.email,
      phone: profile.phone,
      city: profile.city,
      age: profile.age,
      position: profile.position,
      experience: profile.experience,
    );
  }

  Map<String, dynamic> toSupabaseUpdatePayload({
    String? avatarUrl,
    required DateTime subscriptionExpiry,
    required DateTime updatedAt,
  }) {
    return {
      ...toJson(),
      'display_name': displayFullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
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
