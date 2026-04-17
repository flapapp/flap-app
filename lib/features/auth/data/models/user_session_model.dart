import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/auth_user.dart';

part 'user_session_model.g.dart';

/// Serializable snapshot of a session (DTO). Example for [json_serializable].
@JsonSerializable()
class UserSessionModel {
  const UserSessionModel({required this.uid});

  factory UserSessionModel.fromJson(Map<String, dynamic> json) =>
      _$UserSessionModelFromJson(json);

  final String uid;

  Map<String, dynamic> toJson() => _$UserSessionModelToJson(this);

  AuthUser toEntity() => AuthUser(uid: uid);

  factory UserSessionModel.fromEntity(AuthUser user) =>
      UserSessionModel(uid: user.uid);
}
