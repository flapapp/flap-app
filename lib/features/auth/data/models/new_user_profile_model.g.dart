// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewUserProfileModel _$NewUserProfileModelFromJson(Map<String, dynamic> json) =>
    NewUserProfileModel(
      name: json['name'] as String,
      surname: json['surname'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      city: json['city'] as String,
      age: (json['age'] as num).toInt(),
      position: json['position'] as String,
      experience: json['experience'] as String,
    );

Map<String, dynamic> _$NewUserProfileModelToJson(
  NewUserProfileModel instance,
) => <String, dynamic>{
  'name': instance.name,
  'surname': instance.surname,
  'email': instance.email,
  'phone': instance.phone,
  'city': instance.city,
  'age': instance.age,
  'position': instance.position,
  'experience': instance.experience,
};
