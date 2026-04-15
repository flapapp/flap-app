import '../../../../core/profile_db_codec.dart';
import '../../domain/entities/profile_completion_snapshot.dart';
import '../../domain/entities/profile_completion_submission.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../profile_legacy_user_map.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required ProfileRemoteDataSource remote})
      : _remote = remote;

  final ProfileRemoteDataSource _remote;

  @override
  Stream<Map<String, dynamic>> watchLegacyUserMap(String userId) {
    return _remote.watchProfileRow(userId).map((row) {
      if (row.isEmpty) return <String, dynamic>{};
      return profileRowToLegacyUserMap(row);
    });
  }

  @override
  Future<Map<String, dynamic>?> fetchLegacyUserMap(String userId) async {
    final row = await _remote.fetchProfileRow(userId);
    if (row == null) return null;
    return profileRowToLegacyUserMap(row);
  }

  @override
  Future<Map<String, dynamic>> fetchSettings(String userId) async {
    final row = await _remote.fetchProfileRow(userId);
    if (row == null) return const {};
    final s = row['settings'];
    if (s is Map) {
      return Map<String, dynamic>.from(s);
    }
    return const {};
  }

  @override
  Future<void> mergeSettings(String userId, Map<String, dynamic> partial) {
    return _remote.mergeSettings(userId, partial);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchWalletTransactions(String userId) {
    return _remote.watchWalletTransactions(userId).map(
          (rows) => rows.map(_walletRowToLegacy).toList(),
        );
  }

  static Map<String, dynamic> _walletRowToLegacy(Map<String, dynamic> row) {
    final created = row['created_at'];
    DateTime? dt;
    if (created is DateTime) {
      dt = created;
    } else if (created is String) {
      dt = DateTime.tryParse(created);
    }
    return <String, dynamic>{
      'amount': row['amount'] ?? 0,
      'description': (row['description'] ?? '').toString(),
      'timestamp': dt,
    };
  }

  @override
  Future<ProfileCompletionSnapshot?> fetchCompletionSnapshot(String userId) async {
    final row = await _remote.fetchProfileRow(userId);
    if (row == null) return null;
    return ProfileCompletionSnapshot(
      name: row['first_name'] as String?,
      surname: row['last_name'] as String?,
      phone: row['phone'] as String?,
      country: row['country'] as String?,
      city: row['city'] as String?,
      dateOfBirth: _toUtcDate(row['date_of_birth']),
      position: ProfileDbCodec.decodePositionFromDb(row['position'] as String?),
      experience: ProfileDbCodec.decodeExperienceFromDb(
        row['experience'] as String?,
      ),
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  @override
  Future<void> completeProfile({
    required String userId,
    required ProfileCompletionSubmission submission,
    String? avatarUrl,
  }) {
    final payload = <String, dynamic>{
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
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      payload['avatar_url'] = avatarUrl;
    }
    return _remote.completeProfile(
      userId: userId,
      payload: payload,
    );
  }

  @override
  Future<void> setAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) {
    return _remote.setAvatarUrl(userId: userId, avatarUrl: avatarUrl);
  }

  static DateTime? _toUtcDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return DateTime.utc(raw.year, raw.month, raw.day);
    if (raw is String) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) return DateTime.utc(dt.year, dt.month, dt.day);
    }
    return null;
  }
}
