import 'package:equatable/equatable.dart';

/// Read model for `public.user_profiles` (Supabase).
class UserProfileSnapshot extends Equatable {
  const UserProfileSnapshot({
    this.name,
    this.surname,
    this.username,
    this.displayName,
    this.email,
    this.phone,
    this.country,
    this.city,
    this.dateOfBirth,
    this.age,
    this.position,
    this.experience,
    this.avatarUrl,
    this.rating,
  });

  final String? name;
  final String? surname;
  final String? username;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? country;
  final String? city;
  final DateTime? dateOfBirth;
  final int? age;
  final String? position;
  final String? experience;
  final String? avatarUrl;
  final double? rating;

  factory UserProfileSnapshot.fromSupabaseRow(Map<String, dynamic> row) {
    DateTime? dateOfBirth;
    final rawDob = row['date_of_birth'];
    if (rawDob != null) {
      if (rawDob is String) {
        final d = DateTime.tryParse(rawDob);
        if (d != null) {
          dateOfBirth = DateTime.utc(d.year, d.month, d.day);
        }
      } else if (rawDob is DateTime) {
        dateOfBirth =
            DateTime.utc(rawDob.year, rawDob.month, rawDob.day);
      }
    }

    final ageVal = row['age'];
    int? age;
    if (ageVal is int) {
      age = ageVal;
    } else if (ageVal is num) {
      age = ageVal.toInt();
    }

    final r = row['rating'];
    double? rating;
    if (r is num) {
      rating = r.toDouble();
    }

    return UserProfileSnapshot(
      name: row['first_name'] as String?,
      surname: row['last_name'] as String?,
      username: row['username'] as String?,
      displayName: row['display_name'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      country: row['country'] as String?,
      city: row['city'] as String?,
      dateOfBirth: dateOfBirth,
      age: age,
      position: row['position'] as String?,
      experience: row['experience'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      rating: rating,
    );
  }

  @override
  List<Object?> get props => [
    name,
    surname,
    username,
    displayName,
    email,
    phone,
    country,
    city,
    dateOfBirth,
    age,
    position,
    experience,
    avatarUrl,
    rating,
  ];

  /// Display label for UI (challenges, profiles).
  String resolveDisplayName() {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    final n = name;
    final s = surname;
    if (n != null && n.trim().isNotEmpty) {
      if (s != null && s.trim().isNotEmpty) {
        return '$n $s'.trim();
      }
      return n.trim();
    }
    final un = username;
    if (un != null && un.trim().isNotEmpty) {
      return un.trim();
    }
    final em = email;
    if (em != null && em.contains('@')) {
      return em.split('@').first;
    }
    return '';
  }
}
