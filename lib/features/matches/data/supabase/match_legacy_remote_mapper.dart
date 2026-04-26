import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_date.dart';
import '../../../../core/auth/app_auth.dart';

/// Builds the embedded map shape expected by [Match.fromLegacyMap] from normalized tables.
class MatchLegacyRemoteMapper {
  MatchLegacyRemoteMapper._();

  static Future<Map<String, dynamic>?> load(
    SupabaseClient client,
    String matchId,
  ) async {
    final row = await client
        .from('matches')
        .select()
        .eq('id', matchId)
        .maybeSingle();
    if (row == null) {
      return null;
    }

    final org = await client
        .from('profiles')
        .select('display_name,first_name,last_name')
        .eq('id', row['organizer_id'])
        .maybeSingle();
    final orgName = _displayName(org);

    final partRows = await client
        .from('match_participants')
        .select('user_id,status')
        .eq('match_id', matchId);
    final participants = <String>[];
    final pending = <String>[];
    final rejected = <String>[];
    for (final p in partRows as List<dynamic>) {
      final m = p as Map<String, dynamic>;
      final uid = m['user_id'] as String;
      final st = m['status']?.toString() ?? '';
      if (st == 'accepted') {
        participants.add(uid);
      } else if (st == 'pending_application') {
        pending.add(uid);
      } else if (st == 'rejected') {
        rejected.add(uid);
      }
    }

    final scheduled = asDateTimeOrNull(row['scheduled_at']) ??
        asDateTimeOrNull(row['created_at']) ??
        DateTime.now();
    final time =
        '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';

    final invites = await client
        .from('match_invites')
        .select('user_id,status,invited_by')
        .eq('match_id', matchId)
        .inFilter('status', const ['pending', 'accepted', 'declined']);
    final inviteRows = (invites as List<dynamic>).cast<Map<String, dynamic>>();
    final invitedFriends = inviteRows
        .where((r) => (r['status'] ?? '').toString() == 'pending')
        .map((r) => (r['user_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final currentUserId = AppAuth.currentUserId;
    final sentInvitesCount = currentUserId == null
        ? 0
        : inviteRows
            .where((r) => (r['invited_by'] ?? '').toString() == currentUserId)
            .length;

    final lat = row['latitude'] as num?;
    final lng = row['longitude'] as num?;
    Map<String, dynamic>? coordinates;
    if (lat != null && lng != null) {
      coordinates = {'latitude': lat.toDouble(), 'longitude': lng.toDouble()};
    }

    return <String, dynamic>{
      'title': row['title'],
      'description': row['description'] ?? '',
      'organizerId': row['organizer_id'],
      'organizerName': orgName,
      'date': scheduled.toIso8601String(),
      'time': time,
      'location': row['location'] ?? '',
      'city': row['city'] ?? '',
      'coordinates': coordinates,
      'currentPlayers': participants.length,
      'maxPlayers': row['max_players'],
      'participants': participants,
      'pendingApplications': pending,
      'rejectedApplications': rejected,
      'level': row['level'] ?? 'intermediate',
      'cost': (row['participation_cost'] as num?)?.toDouble() ?? 0,
      'autoBalance': row['auto_balance'] ?? false,
      'isPrivate': row['is_private'] ?? false,
      'invitedFriends': invitedFriends,
      'sentInvitesCount': sentInvitesCount,
      'status': row['status'] ?? 'open',
      'teamMatch': row['is_team_match'] ?? false,
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'startedAt': row['started_at'],
      'finishedAt': row['finished_at'],
    };
  }

  static String _displayName(Map<String, dynamic>? p) {
    if (p == null) {
      return '';
    }
    final dn = p['display_name']?.toString() ?? '';
    if (dn.isNotEmpty) {
      return dn;
    }
    final fn = p['first_name']?.toString() ?? '';
    final ln = p['last_name']?.toString() ?? '';
    return '$fn $ln'.trim();
  }
}
