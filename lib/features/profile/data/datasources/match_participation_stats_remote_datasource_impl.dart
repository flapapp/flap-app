import 'package:cloud_firestore/cloud_firestore.dart';

import 'match_participation_stats_remote_datasource.dart';

class MatchParticipationStatsRemoteDataSourceImpl
    implements MatchParticipationStatsRemoteDataSource {
  MatchParticipationStatsRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, dynamic>> loadFinishedMatchStats(String userId) async {
    try {
      final base = _firestore
          .collection('matches')
          .where('participants', arrayContains: userId);

      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await base
            .where('status', isEqualTo: 'finished')
            .orderBy('updatedAt', descending: true)
            .limit(20)
            .get();
      } catch (_) {
        try {
          snap = await base
              .where('status', isEqualTo: 'finished')
              .limit(20)
              .get();
        } catch (_) {
          snap = await base.limit(20).get();
        }
      }

      var wins = 0;
      var draws = 0;
      var losses = 0;
      final recent = <String>[];

      final docs = [...snap.docs]
        ..sort((a, b) {
          final dataA = a.data();
          final dataB = b.data();
          final tsA = (dataA['finishedAt'] as Timestamp?) ??
              (dataA['updatedAt'] as Timestamp?) ??
              Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
          final tsB = (dataB['finishedAt'] as Timestamp?) ??
              (dataB['updatedAt'] as Timestamp?) ??
              Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
          return tsB.compareTo(tsA);
        });

      for (final d in docs) {
        final data = d.data();

        var aOpt = data['teamAScore'] as int?;
        var bOpt = data['teamBScore'] as int?;
        var a = aOpt ?? 0;
        var b = bOpt ?? 0;

        if (aOpt == null || bOpt == null) {
          final r = (data['result'] ?? '').toString();
          if (r == 'teamAWins') {
            a = 1;
            b = 0;
          } else if (r == 'teamBWins') {
            a = 0;
            b = 1;
          } else if (r == 'draw') {
            a = 0;
            b = 0;
          } else {
            continue;
          }
        }

        final teamA =
            List<String>.from((data['teamA']?['playerIds'] ?? const []));
        final teamB =
            List<String>.from((data['teamB']?['playerIds'] ?? const []));
        var isA = teamA.contains(userId);
        if (!isA && teamA.isEmpty && teamB.isEmpty) {
          final parts = List<String>.from(data['participants'] ?? const []);
          if (parts.isNotEmpty) {
            final half = (parts.length / 2).ceil();
            isA = parts.take(half).contains(userId);
          }
        }

        late String res;
        if (a == b) {
          draws++;
          res = 'D';
        } else if ((isA && a > b) || (!isA && b > a)) {
          wins++;
          res = 'W';
        } else {
          losses++;
          res = 'L';
        }
        if (recent.length < 5) {
          recent.add(res);
        }
      }

      final total = wins + draws + losses;
      final rate = total > 0 ? (wins / total) * 100 : 0.0;
      while (recent.length < 5) {
        recent.add('-');
      }
      return {
        'winRate': rate,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'matches': total,
        'recentResults': recent,
      };
    } catch (_) {
      return {
        'winRate': 0.0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'matches': 0,
        'recentResults': const ['-', '-', '-', '-', '-'],
      };
    }
  }
}
