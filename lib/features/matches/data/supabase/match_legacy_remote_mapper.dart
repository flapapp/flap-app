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
cancellation_reason,
organizer_profile:profiles!organizer_id(display_name,first_name,last_name),
match_participants(user_id,status),
match_invites(user_id,status,invited_by),
match_participant_goals(player_id,goals),
match_teams(
  id,
  team_slot,
  source_team_id,
  display_name,
  team_total_rating,
  match_team_rosters(player_id,status)
)
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

    final base = _buildLegacyMapFromParts(
      matchRow: row,
      organizerProfile: organizerProfile,
      participantRows: participantRows,
      inviteRows: inviteRows,
    );
    final goalRows = _asMapList(row['match_participant_goals']);
    final goalsByPlayer = <String, int>{};
    for (final g in goalRows) {
      final pid = (g['player_id'] ?? '').toString();
      if (pid.isEmpty) continue;
      goalsByPlayer[pid] = (g['goals'] as num?)?.toInt() ?? 0;
    }
    if (goalsByPlayer.isNotEmpty) {
      base['goalsByPlayer'] = goalsByPlayer;
    }
    final teamRows = _asMapList(row['match_teams']);
    base.addAll(_embedMatchTeamsFromJoinedRows(teamRows));
    return base;
  }

  /// Maps normalized `match_teams` (+ nested rosters) into legacy keys for [Match.fromLegacyMap].
  static Map<String, dynamic> _embedMatchTeamsFromJoinedRows(
    List<Map<String, dynamic>> rawRows,
  ) {
    if (rawRows.isEmpty) return {};

    final sorted = [...rawRows]
      ..sort((a, b) {
        final sa = (a['team_slot'] as num?)?.toInt() ?? 0;
        final sb = (b['team_slot'] as num?)?.toInt() ?? 0;
        return sa.compareTo(sb);
      });

    Map<String, dynamic> rosterLegacy(Map<String, dynamic> mtRow) {
      final rosters = _asMapList(mtRow['match_team_rosters']);
      final playerIds = <String>[];
      final statusMap = <String, String>{};
      for (final r in rosters) {
        final pid = (r['player_id'] ?? '').toString();
        if (pid.isEmpty) continue;
        final st = (r['status'] ?? 'pending').toString();
        statusMap[pid] = st;
        if (st != 'declined') {
          playerIds.add(pid);
        }
      }
      final src = mtRow['source_team_id']?.toString();
      final totalRating =
          (mtRow['team_total_rating'] as num?)?.toDouble() ?? 0.0;
      final avgRating = playerIds.isEmpty
          ? 0.0
          : (totalRating / playerIds.length);
      return <String, dynamic>{
        'name': (mtRow['display_name'] ?? '').toString(),
        'playerIds': playerIds,
        'averageRating': avgRating,
        'playerRatings': <String, double>{},
        'teamTotalRating': totalRating,
        'sourceTeamId': (src != null && src.isNotEmpty) ? src : null,
        'rosterStatus': statusMap,
      };
    }

    final out = <String, dynamic>{};

    if (sorted.length >= 2) {
      final legA = rosterLegacy(sorted[0]);
      final legB = rosterLegacy(sorted[1]);
      String deriveTeamStatus(Map<String, String> statuses) {
        if (statuses.isEmpty) return 'pending';
        final values = statuses.values.toList(growable: false);
        if (values.every((s) => s == 'confirmed')) return 'confirmed';
        if (values.every((s) => s == 'declined')) return 'declined';
        return 'pending';
      }
      out['teamA'] = <String, dynamic>{
        'name': legA['name'],
        'playerIds': legA['playerIds'],
        'averageRating': (legA['averageRating'] as num?)?.toDouble() ?? 0.0,
        'playerRatings': <String, double>{},
      };
      out['teamB'] = <String, dynamic>{
        'name': legB['name'],
        'playerIds': legB['playerIds'],
        'averageRating': (legB['averageRating'] as num?)?.toDouble() ?? 0.0,
        'playerRatings': <String, double>{},
      };
      final idA = legA['sourceTeamId'] as String?;
      final idB = legB['sourceTeamId'] as String?;
      out['teamAId'] = (idA != null && idA.isNotEmpty) ? idA : null;
      out['teamBId'] = (idB != null && idB.isNotEmpty) ? idB : null;
      out['teamAStatus'] = deriveTeamStatus(
        Map<String, String>.from(legA['rosterStatus'] as Map),
      );
      out['teamBStatus'] = deriveTeamStatus(
        Map<String, String>.from(legB['rosterStatus'] as Map),
      );
      out['teamRosters'] = <String, dynamic>{
        'teamA': List<String>.from(legA['playerIds'] as List),
        'teamB': List<String>.from(legB['playerIds'] as List),
      };
      out['teamRosterStatus'] = <String, dynamic>{
        'teamA': Map<String, String>.from(legA['rosterStatus'] as Map),
        'teamB': Map<String, String>.from(legB['rosterStatus'] as Map),
      };
    }

    if (sorted.length >= 3) {
      out['teams'] = sorted.map((mt) {
        final t = rosterLegacy(mt);
        return <String, dynamic>{
          'name': t['name'],
          'playerIds': t['playerIds'],
          'averageRating': (t['averageRating'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
      out['teamCount'] = sorted.length;
    }

    return out;
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

    final scheduled =
        asDateTimeOrNull(matchRow['scheduled_at']) ??
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

    final base = <String, dynamic>{
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
    _applyFinishLineScoreFromCancellationReason(base, matchRow);
    return base;
  }

  /// Parses scores embedded in [matches.cancellation_reason] by [MatchService.finishMatch].
  static void _applyFinishLineScoreFromCancellationReason(
    Map<String, dynamic> base,
    Map<String, dynamic> matchRow,
  ) {
    final status = matchRow['status']?.toString() ?? '';
    if (status != 'finished') return;
    final raw = matchRow['cancellation_reason']?.toString();
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split(':');
    if (parts.length != 3) return;
    final rName = parts[0];
    if (rName != 'teamAWins' && rName != 'teamBWins' && rName != 'draw') {
      return;
    }
    final a = int.tryParse(parts[1]);
    final b = int.tryParse(parts[2]);
    if (a == null || b == null) return;
    base['teamAScore'] = a;
    base['teamBScore'] = b;
    base['result'] = rName;
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
