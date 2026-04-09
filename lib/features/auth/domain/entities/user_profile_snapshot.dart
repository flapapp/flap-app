import 'package:equatable/equatable.dart';

/// Read model for `public.profiles` (Supabase).
class UserProfileSnapshot extends Equatable {
  const UserProfileSnapshot({
    this.name,
    this.surname,
    this.phone,
    this.city,
    this.age,
    this.position,
    this.experience,
    this.avatarUrl,
  });

  final String? name;
  final String? surname;
  final String? phone;
  final String? city;
  final int? age;
  final String? position;
  final String? experience;
  final String? avatarUrl;

  factory UserProfileSnapshot.fromSupabaseRow(Map<String, dynamic> row) {
    final ageVal = row['age'];
    int? age;
    if (ageVal is int) {
      age = ageVal;
    } else if (ageVal is num) {
      age = ageVal.toInt();
    }

    return UserProfileSnapshot(
      name: row['name'] as String?,
      surname: row['surname'] as String?,
      phone: row['phone'] as String?,
      city: row['city'] as String?,
      age: age,
      position: row['position'] as String?,
      experience: row['experience'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    name,
    surname,
    phone,
    city,
    age,
    position,
    experience,
    avatarUrl,
  ];
}
