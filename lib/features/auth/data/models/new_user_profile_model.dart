import 'package:json_annotation/json_annotation.dart';

import '../../../../core/profile_db_codec.dart';
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
    final _ = subscriptionExpiry;
    final now = DateTime.now().toUtc();
    final safeAge = age < 1 ? 1 : age;
    final dateOfBirth = DateTime.utc(now.year - safeAge, now.month, now.day);
    return {
      'first_name': name,
      'last_name': surname,
      'email': email,
      'phone': phone,
      'city': city,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'position': ProfileDbCodec.encodePositionForDb(position),
      'experience': ProfileDbCodec.encodeExperienceForDb(experience),
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'profile_complete': true,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
