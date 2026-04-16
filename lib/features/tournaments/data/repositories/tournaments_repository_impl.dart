import '../../domain/entities/tournament_detail.dart';
import '../../domain/entities/tournament_match.dart';
import '../../domain/entities/tournament_summary.dart';
import '../../domain/entities/tournament_team_entry.dart';
import '../../domain/repositories/tournaments_repository.dart';
import '../datasources/tournaments_remote_data_source.dart';

class TournamentsRepositoryImpl implements TournamentsRepository {
  TournamentsRepositoryImpl(this._remote);

  final TournamentsRemoteDataSource _remote;

  DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  TournamentSummary _mapSummary(Map<String, dynamic> row) {
    return TournamentSummary(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? '',
      type: row['type']?.toString() ?? 'FRIENDLY',
      status: row['status']?.toString() ?? 'DRAFT',
      createdBy: row['created_by']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startDate: _parseDt(row['start_date']),
      endDate: _parseDt(row['end_date']),
      maxTeams: (row['max_teams'] as num?)?.toInt(),
    );
  }

  @override
  Future<List<TournamentSummary>> listTournaments() async {
    final rows = await _remote.fetchTournaments();
    return rows.map(_mapSummary).toList(growable: false);
  }

  @override
  Future<List<TournamentSummary>> listOngoingTournaments() async {
    final rows = await _remote.fetchTournaments();
    final now = DateTime.now().toUtc();
    return rows
        .map(_mapSummary)
        .where((t) {
          if (t.status == 'COMPLETED' || t.status == 'CANCELLED') return false;
          final end = t.endDate;
          if (end != null && end.toUtc().isBefore(now)) return false;
          return true;
        })
        .toList(growable: false);
  }

  @override
  Future<TournamentDetail?> getTournament(String tournamentId) async {
    final row = await _remote.fetchTournamentById(tournamentId);
    if (row == null) return null;
    final rules = row['rules'];
    return TournamentDetail(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? '',
      type: row['type']?.toString() ?? 'FRIENDLY',
      status: row['status']?.toString() ?? 'DRAFT',
      createdBy: row['created_by']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startDate: _parseDt(row['start_date']),
      endDate: _parseDt(row['end_date']),
      maxTeams: (row['max_teams'] as num?)?.toInt(),
      rules: rules is Map<String, dynamic> ? rules : null,
    );
  }

  @override
  Future<void> requestToJoinTournament({
    required String tournamentId,
    required String teamId,
  }) {
    return _remote.insertTournamentJoinRequest(
      tournamentId: tournamentId,
      teamId: teamId,
    );
  }

  @override
  Future<String> createTournament({
    required String name,
    required String type,
    int? maxTeams,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? rules,
  }) {
    return _remote.insertTournament(
      name: name,
      type: type,
      maxTeams: maxTeams,
      startDate: startDate,
      endDate: endDate,
      rules: rules,
    );
  }

  @override
  Future<List<TournamentMatch>> listMatches(String tournamentId) async {
    final rows = await _remote.fetchMatches(tournamentId);
    final ids = <String>{};
    for (final r in rows) {
      final h = r['home_team_id']?.toString();
      final a = r['away_team_id']?.toString();
      if (h != null && h.isNotEmpty) ids.add(h);
      if (a != null && a.isNotEmpty) ids.add(a);
    }
    final teamRows = await _remote.fetchTeamsByIds(ids.toList());
    final nameById = <String, String>{};
    for (final t in teamRows) {
      nameById[t['id'].toString()] = t['name']?.toString() ?? '';
    }
    return rows
        .map(
          (row) {
            final hid = row['home_team_id']?.toString() ?? '';
            final aid = row['away_team_id']?.toString() ?? '';
            final hn = nameById[hid];
            final an = nameById[aid];
            return TournamentMatch(
              id: row['id'].toString(),
              homeTeamId: hid,
              awayTeamId: aid,
              status: row['status']?.toString() ?? 'SCHEDULED',
              homeScore: (row['home_score'] as num?)?.toInt() ?? 0,
              awayScore: (row['away_score'] as num?)?.toInt() ?? 0,
              matchDate: DateTime.tryParse(row['match_date']?.toString() ?? ''),
              homeTeamName: hn?.isEmpty == true ? null : hn,
              awayTeamName: an?.isEmpty == true ? null : an,
            );
          },
        )
        .toList(growable: false);
  }

  @override
  Future<List<TournamentTeamEntry>> listTournamentTeams(String tournamentId) async {
    final rows = await _remote.fetchTournamentTeams(tournamentId);
    return rows.map((row) {
      final tid = row['team_id']?.toString() ?? '';
      String name = '';
      final embedded = row['teams'];
      if (embedded is Map) {
        name = embedded['name']?.toString() ?? '';
      }
      if (name.isEmpty) {
        name = tid.length > 8 ? '${tid.substring(0, 8)}…' : tid;
      }
      return TournamentTeamEntry(teamId: tid, name: name);
    }).toList(growable: false);
  }

  @override
  Future<String> createTournamentMatch({
    required String tournamentId,
    required String homeTeamId,
    required String awayTeamId,
    DateTime? matchDate,
    String? venue,
  }) {
    return _remote.insertTournamentMatch(
      tournamentId: tournamentId,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      matchDate: matchDate,
      venue: venue,
    );
  }
}
