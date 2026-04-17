import 'package:cloud_firestore/cloud_firestore.dart';

class TeamStats {
  final String teamId;
  final String teamName;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final Map<String, int> playerGoals;
  final List<Map<String, dynamic>> recentMatches;
  final DateTime? updatedAt;

  const TeamStats({
    required this.teamId,
    required this.teamName,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.playerGoals = const {},
    this.recentMatches = const [],
    this.updatedAt,
  });

  factory TeamStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TeamStats.fromFirestoreMap(doc.id, doc.data(), fallbackName: '');
  }

  /// Snapshot data from `teamStats/{teamId}` (same shape as [fromDoc]).
  factory TeamStats.fromFirestoreMap(
    String teamId,
    Map<String, dynamic>? data, {
    String fallbackName = '',
  }) {
    final d = data ?? const <String, dynamic>{};
    if (d.isEmpty) {
      return TeamStats.empty(teamId, name: fallbackName);
    }
    return TeamStats(
      teamId: teamId,
      teamName: (d['teamName'] ?? fallbackName).toString(),
      wins: ((d['wins'] ?? 0) as num).toInt(),
      draws: ((d['draws'] ?? 0) as num).toInt(),
      losses: ((d['losses'] ?? 0) as num).toInt(),
      goalsFor: ((d['goalsFor'] ?? 0) as num).toInt(),
      goalsAgainst: ((d['goalsAgainst'] ?? 0) as num).toInt(),
      playerGoals: Map<String, int>.from(
        (d['playerGoals'] ?? const <String, dynamic>{}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
      ),
      recentMatches: ((d['recentMatches'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static TeamStats empty(String teamId, {String name = ''}) {
    return TeamStats(teamId: teamId, teamName: name);
  }

  int get matches => wins + draws + losses;
  int get points => wins * 3 + draws;
  int get goalDiff => goalsFor - goalsAgainst;
}


