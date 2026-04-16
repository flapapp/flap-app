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

  static List<String> _uuidList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  static Map<String, int> _intStringMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is! Map) return {};
    return raw.map(
      (k, v) => MapEntry(k.toString(), (v is num) ? v.toInt() : int.tryParse('$v') ?? 0),
    );
  }

  static List<Map<String, dynamic>> _recentList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw
        .map((e) =>
            e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();
  }

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  factory AppTeam.fromSupabaseRow(Map<String, dynamic> row) {
    final logo = row['logo_url'];
    final city = row['city'];
    final ownerId = (row['owner_id'] ?? row['captain_id'] ?? '').toString();
    final memberIds = _uuidList(row['member_ids']);
    final captainId = ownerId.isNotEmpty
        ? ownerId
        : (memberIds.isNotEmpty ? memberIds.first : '');
    return AppTeam(
      id: row['id'].toString(),
      name: (row['name'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      captainId: captainId,
      viceCaptainIds: _uuidList(row['vice_captain_ids']),
      memberIds: _uuidList(row['member_ids']),
      isPublic: row['is_public'] is bool ? row['is_public'] as bool : true,
      logoUrl: logo == null || logo.toString().isEmpty ? null : logo.toString(),
      city: city == null || city.toString().isEmpty ? null : city.toString(),
      wins: (row['wins'] as num?)?.toInt() ?? 0,
      losses: (row['losses'] as num?)?.toInt() ?? 0,
      draws: (row['draws'] as num?)?.toInt() ?? 0,
      goalsFor: (row['goals_for'] as num?)?.toInt() ?? 0,
      goalsAgainst: (row['goals_against'] as num?)?.toInt() ?? 0,
      playerGoals: _intStringMap(row['player_goals']),
      recentMatches: _recentList(row['recent_matches']),
      createdAt: _ts(row['created_at']),
      updatedAt: _ts(row['updated_at']),
    );
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
