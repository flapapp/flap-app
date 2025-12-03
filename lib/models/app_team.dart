import 'package:cloud_firestore/cloud_firestore.dart';

class AppTeam {
  final String id;
  final String name;
  final String description;
  final String captainId;
  final List<String> viceCaptainIds;
  final List<String> memberIds;
  final bool isPublic;
  final String? logoUrl;
  final String? city;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int wins;
  final int losses;
  final int draws;
  final int goalsFor;
  final int goalsAgainst;
  final Map<String, int> playerGoals;
  final List<Map<String, dynamic>> recentMatches;

  const AppTeam({
    required this.id,
    required this.name,
    required this.description,
    required this.captainId,
    required this.viceCaptainIds,
    required this.memberIds,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.logoUrl,
    this.city,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.playerGoals = const {},
    this.recentMatches = const [],
  });

  factory AppTeam.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppTeam(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      captainId: (data['captainId'] ?? '').toString(),
      viceCaptainIds: List<String>.from(data['viceCaptainIds'] ?? const []),
      memberIds: List<String>.from(data['memberIds'] ?? const []),
      isPublic: data['isPublic'] is bool ? data['isPublic'] as bool : true,
      logoUrl: (data['logoUrl'] ?? '').toString().isEmpty
          ? null
          : (data['logoUrl'] as String),
      city: (data['city'] ?? '').toString().isEmpty
          ? null
          : (data['city'] as String),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      wins: (data['wins'] ?? 0) as int,
      losses: (data['losses'] ?? 0) as int,
      draws: (data['draws'] ?? 0) as int,
      goalsFor: (data['goalsFor'] ?? 0) as int,
      goalsAgainst: (data['goalsAgainst'] ?? 0) as int,
      playerGoals: Map<String, int>.from(
        (data['playerGoals'] ?? const <String, int>{})
            .map((key, value) => MapEntry(key, (value as num).toInt())),
      ),
      recentMatches: ((data['recentMatches'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'nameLower': name.toLowerCase(),
      'description': description,
      'captainId': captainId,
      'viceCaptainIds': viceCaptainIds,
      'memberIds': memberIds,
      'isPublic': isPublic,
      'logoUrl': logoUrl,
      'city': city,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'playerGoals': playerGoals,
      'recentMatches': recentMatches,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppTeam copyWith({
    String? id,
    String? name,
    String? description,
    String? captainId,
    List<String>? viceCaptainIds,
    List<String>? memberIds,
    bool? isPublic,
    String? logoUrl,
    String? city,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? wins,
    int? losses,
    int? draws,
    int? goalsFor,
    int? goalsAgainst,
    Map<String, int>? playerGoals,
    List<Map<String, dynamic>>? recentMatches,
  }) {
    return AppTeam(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      captainId: captainId ?? this.captainId,
      viceCaptainIds: viceCaptainIds ?? this.viceCaptainIds,
      memberIds: memberIds ?? this.memberIds,
      isPublic: isPublic ?? this.isPublic,
      logoUrl: logoUrl ?? this.logoUrl,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      playerGoals: playerGoals ?? this.playerGoals,
      recentMatches: recentMatches ?? this.recentMatches,
    );
  }

  double get winRate {
    final total = wins + losses + draws;
    if (total == 0) return 0;
    return wins / total * 100;
  }
}








