/// Finished-match form derived from [MatchParticipationStatsRepository] payload.
class ModeHeroStats {
  const ModeHeroStats({
    required this.winRate,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.recentResults,
    required this.finishedMatchesPlayed,
  });

  final double winRate;
  final int wins;
  final int draws;
  final int losses;
  final List<String> recentResults;
  final int finishedMatchesPlayed;

  static const ModeHeroStats empty = ModeHeroStats(
    winRate: 0.0,
    wins: 0,
    draws: 0,
    losses: 0,
    recentResults: ['-', '-', '-', '-', '-'],
    finishedMatchesPlayed: 0,
  );

  factory ModeHeroStats.fromParticipationMap(Map<String, dynamic> raw) {
    final recent = raw['recentResults'];
    final list = recent is List
        ? recent.map((e) => e.toString()).toList()
        : const <String>[];
    return ModeHeroStats(
      winRate: (raw['winRate'] as num?)?.toDouble() ?? 0.0,
      wins: (raw['wins'] as num?)?.toInt() ?? 0,
      draws: (raw['draws'] as num?)?.toInt() ?? 0,
      losses: (raw['losses'] as num?)?.toInt() ?? 0,
      recentResults: list.length >= 5
          ? list.take(5).toList(growable: false)
          : [
              ...list,
              for (var i = list.length; i < 5; i++) '-',
            ],
      finishedMatchesPlayed: (raw['matches'] as num?)?.toInt() ?? 0,
    );
  }
}
