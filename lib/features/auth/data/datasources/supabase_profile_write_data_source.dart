import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/profile_db_codec.dart';
import '../../domain/entities/complete_profile_submission.dart';
import '../models/new_user_profile_model.dart';
import '../models/registration_profile_model.dart';

class SupabaseProfileWriteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  DateTime _deriveDateOfBirthFromAge(int age) {
    final now = DateTime.now().toUtc();
    final safeAge = age < 1 ? 1 : age;
    return DateTime.utc(now.year - safeAge, now.month, now.day);
  }

  int? _deriveAgeFromDateOfBirth(dynamic rawDateOfBirth) {
    if (rawDateOfBirth == null) return null;
    final value = rawDateOfBirth is String
        ? DateTime.tryParse(rawDateOfBirth)
        : rawDateOfBirth as DateTime?;
    if (value == null) return null;
    final dob = DateTime.utc(value.year, value.month, value.day);
    final now = DateTime.now().toUtc();
    var age = now.year - dob.year;
    final hadBirthdayThisYear =
        (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthdayThisYear) age -= 1;
    return age < 0 ? 0 : age;
  }

  /// After email sign-up: fill identity and mark profile incomplete.
  Future<void> updateAfterMinimalRegistration({
    required String userId,
    required RegistrationProfileModel profile,
  }) async {
    await _client.from('user_profiles').update(
          profile.toMinimalSupabasePayload(
            updatedAt: DateTime.now(),
          ),
        ).eq('id', userId);
  }

  /// Loads editable profile fields from `user_profiles` (read path).
  Future<Map<String, dynamic>?> fetchProfileRow(String userId) async {
    final row = await _client
        .from('user_profiles')
        .select(
          'first_name,last_name,username,email,phone,country,city,date_of_birth,position,experience,avatar_url',
        )
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final mutable = Map<String, dynamic>.from(row);
    mutable['age'] = _deriveAgeFromDateOfBirth(row['date_of_birth']);
    mutable['position'] =
        ProfileDbCodec.decodePositionFromDb(row['position'] as String?);
    mutable['experience'] =
        ProfileDbCodec.decodeExperienceFromDb(row['experience'] as String?);
    return mutable;
  }

  Future<bool> fetchProfileComplete(String userId) async {
    final row = await _client
        .from('user_profiles')
        .select('profile_complete')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return false;
    return row['profile_complete'] as bool? ?? false;
  }

  Future<void> completeProfile({
    required String userId,
    required CompleteProfileSubmission submission,
    String? avatarUrl,
  }) async {
    final now = DateTime.now();
    final map = <String, dynamic>{
      'first_name': submission.name,
      'last_name': submission.surname,
      'phone': submission.phone,
      'country': submission.country,
      'city': submission.city,
      'date_of_birth': DateTime.utc(
        submission.dateOfBirth.year,
        submission.dateOfBirth.month,
        submission.dateOfBirth.day,
      ).toIso8601String().split('T').first,
      'position': ProfileDbCodec.encodePositionForDb(submission.position),
      'experience': ProfileDbCodec.encodeExperienceForDb(submission.experience),
      'profile_complete': true,
      'updated_at': now.toUtc().toIso8601String(),
    };
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      map['avatar_url'] = avatarUrl;
    }
    await _client.from('user_profiles').update(map).eq('id', userId);
  }

  /// Persists [avatar_url] only (after storage upload). Trigger updates `updated_at`.
  Future<void> setAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async {
    await _client.from('user_profiles').update({
      'avatar_url': avatarUrl,
    }).eq('id', userId);
  }

  /// Legacy full registration payload (kept for migrations/tests).
  Future<void> updateAfterRegistration({
    required String userId,
    required NewUserProfileModel profile,
    String? avatarUrl,
    required DateTime subscriptionExpiry,
  }) async {
    await _client
        .from('user_profiles')
        .update(
          profile.toSupabaseUpdatePayload(
            avatarUrl: avatarUrl,
            subscriptionExpiry: subscriptionExpiry,
            updatedAt: DateTime.now(),
          ),
        )
        .eq('id', userId);
  }
}
