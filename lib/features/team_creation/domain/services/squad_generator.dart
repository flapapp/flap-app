import 'dart:math';

import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/player_position.dart';

/// Builds a position-balanced squad with unique shirt numbers (1–99).
class SquadGenerator {
  SquadGenerator._();

  static final _firstNames = <String>[
    'Andriy', 'Oleksandr', 'Yaroslav', 'Viktor', 'Dmytro', 'Mykhailo', 'Roman',
    'Ivan', 'Serhiy', 'Taras', 'Bohdan', 'Maksym', 'Artem', 'Denys', 'Yevhen',
    'Luca', 'Marco', 'Alessandro', 'Davide', 'Matteo', 'Luis', 'Diego', 'Bruno',
    'James', 'Harry', 'Jack', 'Oliver', 'Noah', 'Ethan', 'Leo', 'Theo',
  ];

  static final _lastNames = <String>[
    'Shevchenko', 'Zinchenko', 'Yarmolenko', 'Lunin', 'Tsyhankov', 'Stepanenko',
    'Barella', 'Chiesa', 'Tonali', 'Donnarumma', 'Silva', 'Santos', 'Costa',
    'Walker', 'Sterling', 'Rice', 'Bellingham', 'Saka', 'Foden', 'Kane',
  ];

  static final _countries = <String>[
    'Ukraine', 'Poland', 'Germany', 'Spain', 'Italy', 'France', 'England',
    'Brazil', 'Argentina', 'Portugal', 'Netherlands', 'Belgium', 'Croatia',
  ];

  static int _roll(Random r, int min, int max) => min + r.nextInt(max - min + 1);

  static List<Player> generateBalancedSquad(Random r) {
    final gk = _roll(r, 1, 3);
    final df = _roll(r, 6, 8);
    final mf = _roll(r, 6, 8);
    final fw = _roll(r, 3, 5);

    final jerseys = List<int>.generate(99, (i) => i + 1)..shuffle(r);

    final out = <Player>[];
    var ji = 0;

    void addBatch(int n, PlayerPosition pos) {
      for (var i = 0; i < n; i++) {
        final fn = _firstNames[r.nextInt(_firstNames.length)];
        final ln = _lastNames[r.nextInt(_lastNames.length)];
        out.add(
          Player(
            name: '$fn $ln',
            position: pos,
            jerseyNumber: jerseys[ji++],
            age: 18 + r.nextInt(18),
            nationality: _countries[r.nextInt(_countries.length)],
          ),
        );
      }
    }

    addBatch(gk, PlayerPosition.gk);
    addBatch(df, PlayerPosition.df);
    addBatch(mf, PlayerPosition.mf);
    addBatch(fw, PlayerPosition.fw);

    return out;
  }
}
