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
}
