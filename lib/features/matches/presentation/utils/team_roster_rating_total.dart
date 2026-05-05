import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../ratings/domain/repositories/ratings_repository.dart';

double _profileOverallFromRow(Map<String, dynamic> data) {
  final v = data['overall_rating'];
  if (v is num) return v.toDouble();
  return 0.0;
}

/// Stable key so [FutureBuilder]s restart when roster membership changes.
String teamRosterSignature(List<String> playerIds) {
  final ids = playerIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
    ..sort();
  return ids.join(',');
}

Future<double> _safeUserRating(
  RatingsRepository ratingsRepo,
  String userId,
) async {
  try {
    return await ratingsRepo.getUserRating(userId);
  } catch (_) {
    return ratingsRepo.getDefaultRating();
  }
}

Future<double> _sumRatingsFallbackOnly(
  RatingsRepository ratingsRepo,
  List<String> ids,
) async {
  final values = await Future.wait(
    ids.map((id) => _safeUserRating(ratingsRepo, id)),
  );
  return values.fold<double>(0, (a, b) => a + b);
}

/// Sum of formed roster players’ ratings (“team total rating”).
///
/// Uses a single [profiles] batch read (same source as match management), then
/// falls back to [RatingsRepository.getUserRating] when profile values are
/// missing or non-positive — so a formed roster does not spuriously show 0.0
/// when only snapshots exist or vice versa.
///
/// Never throws: falls back to per-player ratings or [getDefaultRating].
Future<double> teamRosterTotalRating({
  required SupabaseClient supabase,
  required RatingsRepository ratingsRepo,
  required List<String> playerIds,
}) async {
  final ids = playerIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (ids.isEmpty) return 0.0;

  try {
    final byId = <String, Map<String, dynamic>>{};
    try {
      final rows = await supabase
          .from('profiles')
          .select('id, overall_rating')
          .inFilter('id', ids);
      for (final raw in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id']?.toString();
        if (id != null && id.isNotEmpty) {
          byId[id] = m;
        }
      }
    } catch (_) {
      // Continue with snapshot/default per player.
    }

    final values = await Future.wait(
      ids.map((id) async {
        try {
          final row = byId[id];
          if (row != null) {
            final fromProfile = _profileOverallFromRow(row);
            if (fromProfile > 0) return fromProfile;
          }
        } catch (_) {}
        return _safeUserRating(ratingsRepo, id);
      }),
    );

    return values.fold<double>(0, (a, b) => a + b);
  } catch (_) {
    return _sumRatingsFallbackOnly(ratingsRepo, ids);
  }
}
