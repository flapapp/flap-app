import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/app_user.dart';

part 'app_user_model.g.dart';

@JsonSerializable()
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    super.email,
    super.displayName,
    super.photoUrl,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) =>
      _$AppUserModelFromJson(json);

  Map<String, dynamic> toJson() => _$AppUserModelToJson(this);

  factory AppUserModel.fromSupabaseUserMeta({
    required String id,
    String? email,
    Map<String, dynamic>? userMetadata,
  }) {
    final name = userMetadata == null
        ? null
        : (userMetadata['display_name'] ??
                userMetadata['full_name'] ??
                userMetadata['name']) as String?;
    final avatar =
        userMetadata == null ? null : userMetadata['avatar_url'] as String?;

    return AppUserModel(
      id: id,
      email: email,
      displayName: name,
      photoUrl: avatar,
    );
  }
}
