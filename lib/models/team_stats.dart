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
    final data = doc.data() ?? const <String, dynamic>{};
    return TeamStats(
      teamId: doc.id,
      teamName: (data['teamName'] ?? '').toString(),
      wins: (data['wins'] ?? 0) as int,
      draws: (data['draws'] ?? 0) as int,
      losses: (data['losses'] ?? 0) as int,
      goalsFor: (data['goalsFor'] ?? 0) as int,
      goalsAgainst: (data['goalsAgainst'] ?? 0) as int,
      playerGoals: Map<String, int>.from(
        (data['playerGoals'] ?? const <String, dynamic>{}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
      ),
      recentMatches: ((data['recentMatches'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static TeamStats empty(String teamId, {String name = ''}) {
    return TeamStats(teamId: teamId, teamName: name);
  }

  int get matches => wins + draws + losses;
  int get points => wins * 3 + draws;
  int get goalDiff => goalsFor - goalsAgainst;
}


