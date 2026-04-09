import 'package:flap_app/models/match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'matches_remote_data_source.dart';

class SupabaseMatchesRemoteDataSource implements MatchesRemoteDataSource {
  SupabaseClient get _c => Supabase.instance.client;

  String _statusStr(MatchStatus s) => s.toString().split('.').last;

  Match _rowToMatch(Map<String, dynamic> row) {
    final doc = Map<String, dynamic>.from(row['document'] as Map? ?? {});
    return Match.fromJsonMap(doc, id: row['id'].toString());
  }

  Future<Map<String, dynamic>> _mergeDocument(String? existingId, Match m) async {
    var prev = <String, dynamic>{};
    if (existingId != null && existingId.isNotEmpty) {
      final row = await _c.from('matches').select().eq('id', existingId).maybeSingle();
      prev = Map<String, dynamic>.from((row?['document'] as Map?) ?? {});
    }
    prev.addAll(m.toStorageJson());
    return prev;
  }

  Map<String, dynamic> _rowForInsert(Match m, Map<String, dynamic> mergedDoc) {
    return {
      'organizer_id': m.organizerId,
      'status': _statusStr(m.status),
      'match_date': m.date.toUtc().toIso8601String(),
      'finished_at': m.finishedAt?.toUtc().toIso8601String(),
      'participants': m.participants,
      'document': mergedDoc,
      'created_at': m.createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _rowForUpdate(Match m, Map<String, dynamic> mergedDoc) {
    return {
      'organizer_id': m.organizerId,
      'status': _statusStr(m.status),
      'match_date': m.date.toUtc().toIso8601String(),
      'finished_at': m.finishedAt?.toUtc().toIso8601String(),
      'participants': m.participants,
      'document': mergedDoc,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<String> insertMatch(Match match) async {
    final merged = await _mergeDocument(null, match);
    final row = _rowForInsert(match, merged);
    final res = await _c.from('matches').insert(row).select('id').single();
    return res['id'] as String;
  }

  @override
  Future<void> saveMatch(Match match) async {
    final merged = await _mergeDocument(match.id, match);
    final row = _rowForUpdate(match, merged);
    await _c.from('matches').update(row).eq('id', match.id);
  }

  @override
  Future<Match?> fetchMatch(String id) async {
    final row = await _c.from('matches').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _rowToMatch(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> deleteMatchRow(String id) async {
    await _c.from('matches').delete().eq('id', id);
  }

  @override
  Stream<List<Match>> watchMatchesTable() {
    return _c.from('matches').stream(primaryKey: ['id']).map((raw) {
      final rows = (raw as List).cast<Map>();
      return rows
          .map((e) => _rowToMatch(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Map<String, dynamic> _fixtureToApp(Map<String, dynamic> r) {
    return {
      'id': r['id']?.toString(),
      'teamAIndex': r['team_a_index'],
      'teamBIndex': r['team_b_index'],
      'teamAName': r['team_a_name'],
      'teamBName': r['team_b_name'],
      'scoreA': r['score_a'],
      'scoreB': r['score_b'],
      'status': r['status'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFixtures(String matchId) async {
    final rows = await _c
        .from('match_fixtures')
        .select()
        .eq('match_id', matchId)
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map>()
        .map((e) => _fixtureToApp(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> deleteAllFixtures(String matchId) async {
    await _c.from('match_fixtures').delete().eq('match_id', matchId);
  }

  @override
  Future<void> insertFixturesLegacy(
    String matchId,
    List<Map<String, dynamic>> fixtures,
  ) async {
    for (final f in fixtures) {
      await _c.from('match_fixtures').insert({
        'match_id': matchId,
        'team_a_index': f['teamAIndex'],
        'team_b_index': f['teamBIndex'],
        'team_a_name': f['teamAName'],
        'team_b_name': f['teamBName'],
        'score_a': f['scoreA'],
        'score_b': f['scoreB'],
        'status': f['status'] ?? 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  @override
  Future<void> updateFixtureScores({
    required String matchId,
    required String fixtureId,
    required int scoreA,
    required int scoreB,
    required String status,
  }) async {
    await _c.from('match_fixtures').update({
      'score_a': scoreA,
      'score_b': scoreB,
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', fixtureId).eq('match_id', matchId);
  }

  @override
  Future<bool> allFixturesFinished(String matchId) async {
    final rows = await _c.from('match_fixtures').select('status').eq('match_id', matchId);
    final list = (rows as List).cast<Map>();
    if (list.isEmpty) return false;
    return list.every((d) => (d['status'] ?? '').toString() == 'finished');
  }

  @override
  Future<void> patchDocumentOnly(String matchId, Map<String, dynamic> patch) async {
    final row = await _c.from('matches').select('document').eq('id', matchId).maybeSingle();
    if (row == null) return;
    final doc = Map<String, dynamic>.from(row['document'] as Map? ?? {});
    doc.addAll(patch);
    await _c.from('matches').update({
      'document': doc,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  @override
  Future<void> cancelMatchAsUnplayed(String matchId) async {
    final m = await fetchMatch(matchId);
    if (m == null) return;
    final now = DateTime.now();
    final patched = m.copyWith(
      status: MatchStatus.cancelled,
      updatedAt: now,
    );
    final merged = await _mergeDocument(matchId, patched);
    merged['unplayed'] = true;
    merged['unplayedReason'] = 'timeout_24h_no_start';
    await _c.from('matches').update({
      'status': 'cancelled',
      'document': merged,
      'updated_at': now.toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  @override
  Future<void> markMatchFinished(String matchId) async {
    final m = await fetchMatch(matchId);
    if (m == null) return;
    final now = DateTime.now();
    final updated = m.copyWith(
      status: MatchStatus.finished,
      finishedAt: now,
      updatedAt: now,
    );
    await saveMatch(updated);
  }
}
