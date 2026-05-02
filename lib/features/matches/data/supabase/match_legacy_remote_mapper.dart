import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_date.dart';
import '../../../../core/auth/app_auth.dart';

/// Builds the embedded map shape expected by [Match.fromLegacyMap] from normalized tables.
class MatchLegacyRemoteMapper {
  MatchLegacyRemoteMapper._();

  /// Single joined query: match row + organizer profile + participants + invites.
  static const String _kJoinedMatchSelect = '''
id,
title,
description,
organizer_id,
scheduled_at,
created_at,
location,
city,
latitude,
longitude,
max_players,
participation_cost,
level,
auto_balance,
is_private,
is_team_match,
status,
started_at,
finished_at,
updated_at,
organizer_profile:profiles!organizer_id(display_name,first_name,last_name),
match_participants(user_id,status),
match_invites(user_id,status,invited_by)
''';

  static const int _kBatchChunkSize = 80;

  /// Loads legacy-shaped maps for many matches in one round-trip per chunk (joined selects).
  static Future<Map<String, Map<String, dynamic>>> loadLegacyMapsBatch(
    SupabaseClient client,
    List<String> matchIds,
  ) async {
    if (matchIds.isEmpty) {
      return {};
    }
    final unique = matchIds.toSet().toList();
    final out = <String, Map<String, dynamic>>{};
    for (var i = 0; i < unique.length; i += _kBatchChunkSize) {
      final end = min(i + _kBatchChunkSize, unique.length);
      final chunk = unique.sublist(i, end);
      final response = await client
          .from('matches')
          .select(_kJoinedMatchSelect)
          .inFilter('id', chunk);

      for (final raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        out[id] = legacyMapFromJoinedRow(row);
      }
    }
    return out;
  }

  /// One legacy map per joined row (same output shape as [load] previously produced).
  static Map<String, dynamic> legacyMapFromJoinedRow(Map<String, dynamic> row) {
    final organizerProfile =
        _asStringKeyedMap(row['organizer_profile']) ??
            _asStringKeyedMap(row['profiles']);
    final participantRows = _asMapList(row['match_participants']);
    final inviteRowsRaw = _asMapList(row['match_invites']);
    final inviteRows = inviteRowsRaw.where((r) {
      final st = (r['status'] ?? '').toString();
      return st == 'pending' || st == 'accepted' || st == 'declined';
    }).toList();

    return _buildLegacyMapFromParts(
      matchRow: row,
      organizerProfile: organizerProfile,
      participantRows: participantRows,
      inviteRows: inviteRows,
    );
  }

  /// Prefer [loadLegacyMapsBatch]; kept for call sites that load a single match.
  static Future<Map<String, dynamic>?> load(
    SupabaseClient client,
    String matchId,
  ) async {
    final batch = await loadLegacyMapsBatch(client, [matchId]);
    return batch[matchId];
  }

  static Map<String, dynamic> _buildLegacyMapFromParts({
    required Map<String, dynamic> matchRow,
    required Map<String, dynamic>? organizerProfile,
    required List<Map<String, dynamic>> participantRows,
    required List<Map<String, dynamic>> inviteRows,
  }) {
    final participants = <String>[];
    final pending = <String>[];
    final rejected = <String>[];
    for (final p in participantRows) {
      final uid = (p['user_id'] ?? '').toString();
      if (uid.isEmpty) continue;
      final st = p['status']?.toString() ?? '';
      if (st == 'accepted') {
        participants.add(uid);
      } else if (st == 'pending_application') {
        pending.add(uid);
      } else if (st == 'rejected') {
        rejected.add(uid);
      }
    }

    final scheduled = asDateTimeOrNull(matchRow['scheduled_at']) ??
        asDateTimeOrNull(matchRow['created_at']) ??
        DateTime.now();
    final time =
        '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';

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

    final lat = matchRow['latitude'] as num?;
    final lng = matchRow['longitude'] as num?;
    Map<String, dynamic>? coordinates;
    if (lat != null && lng != null) {
      coordinates = {'latitude': lat.toDouble(), 'longitude': lng.toDouble()};
    }

    return <String, dynamic>{
      'title': matchRow['title'],
      'description': matchRow['description'] ?? '',
      'organizerId': matchRow['organizer_id'],
      'organizerName': _displayName(organizerProfile),
      'date': scheduled.toIso8601String(),
      'time': time,
      'location': matchRow['location'] ?? '',
      'city': matchRow['city'] ?? '',
      'coordinates': coordinates,
      'currentPlayers': participants.length,
      'maxPlayers': matchRow['max_players'],
      'participants': participants,
      'pendingApplications': pending,
      'rejectedApplications': rejected,
      'level': matchRow['level'] ?? 'intermediate',
      'cost': (matchRow['participation_cost'] as num?)?.toDouble() ?? 0,
      'autoBalance': matchRow['auto_balance'] ?? false,
      'isPrivate': matchRow['is_private'] ?? false,
      'invitedFriends': invitedFriends,
      'sentInvitesCount': sentInvitesCount,
      'status': matchRow['status'] ?? 'open',
      'teamMatch': matchRow['is_team_match'] ?? false,
      'createdAt': matchRow['created_at'],
      'updatedAt': matchRow['updated_at'],
      'startedAt': matchRow['started_at'],
      'finishedAt': matchRow['finished_at'],
    };
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v == null) return const [];
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
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
