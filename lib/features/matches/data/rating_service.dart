import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/matches/data/datasources/matches_remote_data_source.dart';
import 'package:flap_app/features/matches/data/datasources/supabase_matches_remote_data_source.dart';
import 'package:flap_app/features/videos/data/datasources/supabase_videos_remote_data_source.dart';
import 'package:flap_app/features/videos/data/repositories/videos_repository_impl.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/core/app_auth_context.dart';

class RatingService {
  RatingService({
    MatchesRemoteDataSource? matchesRemote,
    VideosRepository? videosRepository,
  })  : _matches = matchesRemote ?? SupabaseMatchesRemoteDataSource(),
        _videosRepository = videosRepository;

  static VideosRepository? _injectedVideosRepository;
  static void registerVideosRepository(VideosRepository repository) {
    _injectedVideosRepository = repository;
  }

  final MatchesRemoteDataSource _matches;
  final VideosRepository? _videosRepository;

  VideosRepository get _videos =>
      _videosRepository ??
      _injectedVideosRepository ??
      VideosRepositoryImpl(SupabaseVideosRemoteDataSource());

  SupabaseClient get _sb => Supabase.instance.client;

  static double _averageRatingsFromDocument(Map<String, dynamic>? doc) {
    final list = (doc?['playerRatings'] as List?) ?? [];
    final ratings = <double>[];
    for (final item in list) {
      if (item is Map) {
        final r = item['rating'];
        if (r is num) ratings.add(r.toDouble());
      }
    }
    if (ratings.isEmpty) return 0.0;
    ratings.sort();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;
    return double.parse(avg.toStringAsFixed(2));
  }
  static const double _matchWeight = 0.7; // 70% ваги для матчів
  static const double _videoWeight = 0.3; // 30% ваги для відео/челенджів
  static const double _defaultRating = 3.0; // Початковий рейтинг для нових користувачів

// Нове: правила з Повної документації
  static const bool _trimOutliers = false; // тримінг вимкнено

  // Критерії оцінювання для матчів
  static const List<String> _matchCriteria = [
    'technical',    // Техніка
    'physical',     // Фізика
    'tactical',     // Тактика
    'teamwork',     // Командна гра
  ];

  // Критерії оцінювання для відео
  static const List<String> _videoCriteria = [
    'technical',    // Технічне виконання (40%)
    'creativity',   // Креативність (30%)
    'difficulty',   // Складність (20%)
    'quality',      // Якість відео (10%)
  ];

  // Ваги для відео критеріїв
  static const Map<String, double> _videoWeights = {
    'technical': 0.4,
    'creativity': 0.3,
    'difficulty': 0.2,
    'quality': 0.1,
  };

  // DB trigger on `video_votes` maintains `public.videos.rating` / `vote_count`.
  Future<void> updateVideoAggregate(String videoId) async {}

  // Отримати поточний рейтинг користувача
  Future<double> getUserRating(String userId) async {
    try {
      final row = await _sb
          .from('user_profiles')
          .select('rating')
          .eq('id', userId)
          .maybeSingle();

      if (row != null) {
        final rating = row['rating'];
        if (rating == null || (rating is num && rating <= 0.0)) {
          return _defaultRating;
        }
        return (rating as num).toDouble();
      }
      return _defaultRating;
    } catch (e) {
      print('Error getting user rating: $e');
      return _defaultRating;
    }
  }

  // Отримати детальну статистику рейтингу
  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    try {
      final row = await _sb
          .from('user_profiles')
          .select(
            'rating, match_rating, video_rating, total_matches, total_videos, rating_history',
          )
          .eq('id', userId)
          .maybeSingle();

      if (row != null) {
        final histRaw = row['rating_history'];
        final hist = <Map<String, dynamic>>[];
        if (histRaw is List) {
          for (final e in histRaw) {
            if (e is Map) {
              hist.add(Map<String, dynamic>.from(e as Map));
            }
          }
        }
        return {
          'currentRating': (row['rating'] ?? _defaultRating).toDouble(),
          'matchRating': (row['match_rating'] ?? _defaultRating).toDouble(),
          'videoRating': (row['video_rating'] ?? _defaultRating).toDouble(),
          'totalMatches': ((row['total_matches'] ?? 0) as num).toInt(),
          'totalVideos': ((row['total_videos'] ?? 0) as num).toInt(),
          'ratingHistory': hist,
        };
      }
      return {};
    } catch (e) {
      print('Error getting user rating stats: $e');
      return {};
    }
  }

  // Оцінити гравця після матчу
  Future<void> ratePlayerAfterMatch({
    required String matchId,
    required String playerId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) async {
    try {
      // Перевірка чи не оцінює сам себе
      if (playerId == ratedBy) {
        throw Exception('Не можна оцінювати самого себе');
      }

      // Валідація критеріїв
      for (final criterion in _matchCriteria) {
        if (!criteria.containsKey(criterion)) {
          throw Exception('Відсутній критерій: $criterion');
        }
        if (criteria[criterion]! < 0.0 || criteria[criterion]! > 5.0) {
          throw Exception('Оцінка має бути від 0.0 до 5.0');
        }
      }

      // Розрахунок середньої оцінки
      double totalRating = 0.0;
      for (final criterion in _matchCriteria) {
        totalRating += criteria[criterion]!;
      }
      final averageRating = totalRating / _matchCriteria.length;

      final m = await _matches.fetchMatch(matchId);
      if (m == null) {
        throw Exception('Матч не знайдено');
      }
      final participants = m.participants;
      if (!participants.contains(ratedBy) || !participants.contains(playerId)) {
        throw Exception('Лише учасники можуть оцінювати');
      }

      final multiTeams = m.teams
          .map((t) => t.playerIds)
          .where((ids) => ids.isNotEmpty)
          .toList();

      if (multiTeams.isNotEmpty) {
        List<String>? ratedByTeam;
        List<String>? playerTeam;

        for (final ids in multiTeams) {
          if (ids.contains(ratedBy)) ratedByTeam = ids;
          if (ids.contains(playerId)) playerTeam = ids;
        }

        if (ratedByTeam == null ||
            playerTeam == null ||
            ratedByTeam != playerTeam) {
          throw Exception(
              'Оцінювання дозволене лише гравцями своєї команди');
        }
      } else {
        final teamAIds = m.teamA?.playerIds ?? const <String>[];
        final teamBIds = m.teamB?.playerIds ?? const <String>[];
        final teamsExist = teamAIds.isNotEmpty || teamBIds.isNotEmpty;
        if (teamsExist) {
          final sameTeam = (teamAIds.contains(ratedBy) &&
                  teamAIds.contains(playerId)) ||
              (teamBIds.contains(ratedBy) && teamBIds.contains(playerId));
          if (!sameTeam) {
            throw Exception(
                'Оцінювання дозволене лише гравцями своєї команди');
          }
        }
      }

      if (m.playerRatings.any(
          (r) => r.playerId == playerId && r.ratedBy == ratedBy)) {
        throw Exception('Ви вже оцінювали цього гравця');
      }

      final pr = PlayerRating(
        playerId: playerId,
        ratedBy: ratedBy,
        rating: averageRating,
        ratedAt: DateTime.now(),
        criteria: Map<String, double>.from(criteria),
      );
      final next = m.copyWith(
        playerRatings: [...m.playerRatings, pr],
        updatedAt: DateTime.now(),
      );
      await _matches.saveMatch(next);

      String raterName = I18n.inline('Гравець', 'Player');
      try {
        final raterRow = await _sb
            .from('user_profiles')
            .select('display_name, first_name, last_name')
            .eq('id', ratedBy)
            .maybeSingle();
        if (raterRow != null) {
          raterName = (raterRow['display_name'] ??
                  raterRow['name'] ??
                  raterRow['surname'] ??
                  I18n.inline('Гравець', 'Player'))
              .toString();
        }
      } catch (_) {}

      // Оновлення рейтингу гравця
      await _updatePlayerRating(
        playerId,
        reason: 'match_rating',
        source: raterName,
        sourceType: 'match',
        sourceId: matchId,
      );

    } catch (e) {
      print('Error rating player after match: $e');
      rethrow;
    }
  }

  // Оцінити відео
  Future<bool> rateVideo({
    required String videoId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) async {
    try {
      // Валідація критеріїв
      for (final criterion in _videoCriteria) {
        if (!criteria.containsKey(criterion)) {
          throw Exception('Відсутній критерій: $criterion');
        }
        if (criteria[criterion]! < 0.0 || criteria[criterion]! > 5.0) {
          throw Exception('Оцінка має бути від 0.0 до 5.0');
        }
      }

      // Розрахунок зваженої оцінки
      double weightedRating = 0.0;
      for (final criterion in _videoCriteria) {
        weightedRating += criteria[criterion]! * _videoWeights[criterion]!;
      }

      await _videos.submitVideoVote(
        videoId: videoId,
        ratedBy: ratedBy,
        rating: weightedRating,
        criteria: Map<String, dynamic>.from(criteria),
      );

      await updateVideoAggregate(videoId);

      final videoRow = await _videos.fetchVideo(videoId);

      if (videoRow != null) {
        final authorId = videoRow.userId;
        final videoTitle = videoRow.title.isNotEmpty ? videoRow.title : 'Відео';
        
        if (authorId.isNotEmpty && authorId != ratedBy) {
          // Отримуємо ім'я того, хто оцінив відео
          String voterName = 'Користувач';
          try {
            final voterRow = await _sb
                .from('user_profiles')
                .select('display_name, first_name, last_name, email')
                .eq('id', ratedBy)
                .maybeSingle();
            if (voterRow != null) {
              final v = voterRow;
              final emailPrefix = AppAuthContext.currentUser?.email?.split('@')[0];
              final dn = v['display_name']?.toString();
              final nm = v['name']?.toString();
              final sn = v['surname']?.toString();
              final combined = [nm, sn]
                  .where((s) => s != null && s.trim().isNotEmpty)
                  .join(' ')
                  .trim();
              final emailStr = v['email']?.toString();
              final emailLocal = (emailStr != null && emailStr.contains('@'))
                  ? emailStr.split('@').first
                  : null;
              voterName = (dn != null && dn.isNotEmpty)
                      ? dn
                      : (combined.isNotEmpty
                          ? combined
                          : (emailLocal ?? emailPrefix ?? 'Користувач'));
            }
          } catch (_) {}

          final beforeRow = await _sb
              .from('user_profiles')
              .select('rating')
              .eq('id', authorId)
              .maybeSingle();
          final oldRating =
              ((beforeRow?['rating'] ?? _defaultRating) as num).toDouble();

          // Оновлюємо рейтинг автора відео і зберігаємо нотифікацію
          await _updatePlayerRating(
            authorId,
            reason: 'Оцінка відео ${weightedRating.toStringAsFixed(1)}',
            source: voterName,
            sourceType: 'video',
            sourceId: videoId,
          );

          // Відправляємо нотифікації: про голос та про зміну рейтингу
          try {
            // 1) Нотифікація про голос з конкретною оцінкою
            await NotificationService().sendVideoVoteNotification(
              toUserId: authorId,
              videoTitle: videoTitle,
              voterName: voterName,
              rating: weightedRating,
            );

            // 2) Нотифікація про зміну рейтингу (дельта і нове значення)
            final afterRow = await _sb
                .from('user_profiles')
                .select('rating')
                .eq('id', authorId)
                .maybeSingle();
            final newRating =
                ((afterRow?['rating'] ?? _defaultRating) as num).toDouble();
            final delta = newRating - oldRating;
            await NotificationService().sendRatingChangedNotification(
              toUserId: authorId,
              voterName: voterName,
              rating: weightedRating,
              delta: delta,
              newRating: newRating,
              videoTitle: videoTitle,
            );
          } catch (_) {}
        }
      }

      return true;
    } catch (e) {
      print('Error rating video: $e');
      return false;
    }
  }

  // Оновити загальний рейтинг гравця
  Future<void> _updatePlayerRating(String userId, {
    String? reason,
    String? source,
    String? sourceType,
    String? sourceId,
  }) async {
    try {
      final profileRow = await _sb
          .from('user_profiles')
          .select('rating')
          .eq('id', userId)
          .maybeSingle();

      if (profileRow == null) return;

      final oldRating =
          ((profileRow['rating'] ?? _defaultRating) as num).toDouble();
      
      // Отримуємо всі оцінки з матчів
      final matchRatings = await _getMatchRatings(userId);
      
      // Отримуємо всі оцінки з відео
      final videoRatings = await _getVideoRatings(userId);

      // Розрахунок середнього рейтингу матчів
      double matchRating = _defaultRating; // Початковий рейтинг за замовчуванням
      if (matchRatings.isNotEmpty) {
        double total = 0.0;
        for (final rating in matchRatings) {
          total += rating;
        }
        matchRating = total / matchRatings.length;
      }

      // Розрахунок середнього рейтингу відео
      double videoRating = _defaultRating; // Початковий рейтинг за замовчуванням
      if (videoRatings.isNotEmpty) {
        double total = 0.0;
        for (final rating in videoRatings) {
          total += rating;
        }
        videoRating = total / videoRatings.length;
      }

      // Розрахунок загального рейтингу з вагами
      double overallRating = (matchRating * _matchWeight) + (videoRating * _videoWeight);

      await _sb.from('user_profiles').update({
        'rating': double.parse(overallRating.toStringAsFixed(2)),
        'match_rating': double.parse(matchRating.toStringAsFixed(2)),
        'video_rating': double.parse(videoRating.toStringAsFixed(2)),
      }).eq('id', userId);

      // Додавання в історію рейтингу
      await _addRatingHistory(userId, overallRating, matchRating, videoRating);

      // Відправка сповіщення про зміну рейтингу — для challenge_vote надсилаємо окремо в місці голосу
      if (reason != null && source != null && reason != 'challenge_vote') {
        final newRatingRounded = double.parse(overallRating.toStringAsFixed(2));
        final delta = double.parse((newRatingRounded - oldRating).toStringAsFixed(2));
        await NotificationService().sendRatingChangedNotification(
          toUserId: userId,
          voterName: source,
          rating: 0.0, // не завжди відомо; для відео додаємо окремо у rateVideo
          delta: delta,
          newRating: newRatingRounded,
          videoTitle: sourceType == 'video' ? (sourceId ?? '') : null,
        );
      }

    } catch (e) {
      print('Error updating player rating: $e');
    }
  }

  // Отримати всі оцінки гравця з матчів (Supabase `matches.document.playerRatings`)
  Future<List<double>> _getMatchRatings(String userId) async {
    try {
      final perMatchAverages = <double>[];

      final rows = await _sb
          .from('matches')
          .select('document')
          .eq('status', 'finished')
          .contains('participants', [userId]);

      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final docRaw = map['document'];
        final doc = docRaw is Map
            ? Map<String, dynamic>.from(docRaw as Map)
            : <String, dynamic>{};
        final list = (doc['playerRatings'] as List?) ?? [];
        final values = <double>[];
        for (final item in list) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item as Map);
          if ((m['playerId'] ?? '').toString() != userId) continue;
          values.add(((m['rating'] ?? 0.0) as num).toDouble());
        }
        if (values.isEmpty) continue;
        final avg = values.reduce((a, b) => a + b) / values.length;
        perMatchAverages.add(double.parse(avg.toStringAsFixed(2)));
      }

      return perMatchAverages;
    } catch (e) {
      print('Error getting match ratings: $e');
      return [];
    }
  }

  // Отримати всі оцінки гравця з відео
  Future<List<double>> _getVideoRatings(String userId) async {
    try {
      final vrows = await _sb.from('videos').select('id').eq('user_id', userId);
      final ids = (vrows as List).map((e) => (e as Map)['id'].toString()).toList();
      if (ids.isEmpty) return [];
      final voteRows2 =
          await _sb.from('video_votes').select('rating').inFilter('video_id', ids);
      final ratings = <double>[];
      for (final r in (voteRows2 as List)) {
        final m = r as Map;
        ratings.add(((m['rating'] ?? 0.0) as num).toDouble());
      }
      return ratings;
    } catch (e) {
      print('Error getting video ratings: $e');
      return [];
    }
  }

  // Додати в історію рейтингу (`profiles.rating_history` jsonb)
  Future<void> _addRatingHistory(
    String userId,
    double overallRating,
    double matchRating,
    double videoRating,
  ) async {
    try {
      final historyEntry = <String, dynamic>{
        'overallRating': overallRating,
        'matchRating': matchRating,
        'videoRating': videoRating,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final row = await _sb
          .from('user_profiles')
          .select('rating_history')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return;

      final raw = row['rating_history'];
      final history = <dynamic>[];
      if (raw is List) {
        history.addAll(raw);
      }
      history.add(historyEntry);
      List<dynamic> trimmed = history;
      if (trimmed.length > 30) {
        trimmed = trimmed.sublist(trimmed.length - 30);
      }

      await _sb.from('user_profiles').update({
        'rating_history': trimmed,
      }).eq('id', userId);
    } catch (e) {
      print('Error adding rating history: $e');
    }
  }

  // Отримати топ гравців за рейтингом (Supabase `profiles`)
  Future<List<Map<String, dynamic>>> getTopPlayers({
    int limit = 50,
    String? city,
    String? position,
  }) async {
    try {
      final rows = await _sb.from('user_profiles').select(
            'id, display_name, first_name, last_name, email, rating, total_matches, total_videos, city, position, avatar_url',
          ).limit(500);

      final allPlayers = <Map<String, dynamic>>[];

      for (final row in (rows as List)) {
        final data = Map<String, dynamic>.from(row as Map);

        final rating = ((data['rating'] ?? 0.0) as num).toDouble();
        final totalMatches = ((data['total_matches'] ?? 0) as num).toInt();
        final totalVideos = ((data['total_videos'] ?? 0) as num).toInt();
        final userCity = (data['city'] ?? '').toString();
        final userPosition = (data['position'] ?? '').toString();

        if (city != null && city.isNotEmpty && city != 'Всі міста') {
          if (userCity != city) continue;
        }

        if (position != null &&
            position.isNotEmpty &&
            position != 'Всі позиції') {
          if (userPosition != position) continue;
        }

        final id = data['id']?.toString() ?? '';
        final dn = data['display_name']?.toString();
        final nm = data['first_name']?.toString() ?? data['name']?.toString();
        final sn = data['last_name']?.toString() ?? data['surname']?.toString();
        final em = data['email']?.toString();
        final combined = [nm, sn]
            .where((s) => s != null && s.toString().trim().isNotEmpty)
            .map((s) => s.toString().trim())
            .join(' ');
        final displayName = (dn != null && dn.isNotEmpty)
            ? dn
            : (combined.isNotEmpty
                ? combined
                : (em != null && em.contains('@')
                    ? em.split('@').first
                    : 'Невідомий'));

        allPlayers.add({
          'id': id,
          'name': displayName,
          'rating': rating,
          'city': userCity.isNotEmpty ? userCity : 'Невідомо',
          'position': userPosition.isNotEmpty ? userPosition : 'Невідомо',
          'totalMatches': totalMatches,
          'totalVideos': totalVideos,
          'avatarUrl': (data['avatar_url'] ?? '').toString(),
        });
      }

      allPlayers.sort(
          (a, b) => (b['rating'] as double).compareTo(a['rating'] as double));

      return allPlayers.take(limit).toList();
    } catch (e) {
      print('Error getting top players: $e');
      return [];
    }
  }

  // Отримати рівень гравця за рейтингом
  String getPlayerLevel(double rating) {
    if (rating >= 0.0 && rating < 1.5) return I18n.inline('Новачок', 'Beginner');
    if (rating >= 1.5 && rating < 2.5) return I18n.inline('Початковий', 'Novice');
    if (rating >= 2.5 && rating < 3.5) return I18n.inline('Середній', 'Intermediate');
    if (rating >= 3.5 && rating < 4.5) return I18n.inline('Високий', 'Advanced');
    if (rating >= 4.5 && rating <= 5.0) return I18n.inline('Професійний', 'Professional');
    return I18n.inline('Невідомо', 'Unknown');
  }

  // Отримати кольір рівня
  int getPlayerLevelColor(double rating) {
    if (rating >= 0.0 && rating < 1.5) return 0xFF9E9E9E; // Сірий
    if (rating >= 1.5 && rating < 2.5) return 0xFF4CAF50; // Зелений
    if (rating >= 2.5 && rating < 3.5) return 0xFF2196F3; // Синій
    if (rating >= 3.5 && rating < 4.5) return 0xFFFF9800; // Помаранчевий
    if (rating >= 4.5 && rating <= 5.0) return 0xFF9C27B0; // Фіолетовий
    return 0xFF9E9E9E; // Сірий за замовчуванням
  }

  // Оновити профіль початковими полями рейтингу (рядок уже створено після sign-up).
  Future<void> createUserWithDefaultRating(
      String userId, Map<String, dynamic> userData) async {
    try {
      await _sb.from('user_profiles').update({
        'rating': _defaultRating,
        'match_rating': _defaultRating,
        'video_rating': _defaultRating,
        'rating_history': [],
      }).eq('id', userId);
    } catch (e) {
      print('Error creating user with default rating: $e');
    }
  }

  // Отримати початковий рейтинг
  double getDefaultRating() => _defaultRating;
  /// Середнє з `matches.document.playerRatings` (Realtime по рядку матчу).
  Stream<double> getMatchRating(String matchId) {
    return _sb
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((raw) {
      final list = (raw as List).cast<Map>();
      if (list.isEmpty) return 0.0;
      final docRaw = list.first['document'];
      final doc = docRaw is Map
          ? Map<String, dynamic>.from(docRaw as Map)
          : null;
      return _averageRatingsFromDocument(doc);
    });
  }

  // Публічний метод для перерахунку загального рейтингу (використовується з челенджів)
  Future<void> recomputeOverallRating(
    String userId, {
    String? reason,
    String? source,
    String? sourceType,
    String? sourceId,
  }) async {
    await _updatePlayerRating(
      userId,
      reason: reason,
      source: source,
      sourceType: sourceType,
      sourceId: sourceId,
    );
  }

  // Ручний перерахунок для всіх учасників конкретного матчу
  Future<void> recomputeForMatchParticipants(String matchId) async {
    try {
      final m = await _matches.fetchMatch(matchId);
      if (m == null) return;
      for (final uid in m.participants.toSet()) {
        await recomputeOverallRating(
          uid,
          reason: 'manual_recompute',
          source: 'Адмін',
          sourceType: 'system',
          sourceId: matchId,
        );
      }
    } catch (_) {}
  }

  /// Масовий перерахунок для всіх профілів (обережно на продакшені).
  Future<void> recomputeAllUsers({int pageSize = 200}) async {
    try {
      var from = 0;
      while (true) {
        final rows = await _sb
            .from('user_profiles')
            .select('id')
            .order('id')
            .range(from, from + pageSize - 1);
        final list = (rows as List).cast<Map>();
        if (list.isEmpty) break;
        for (final r in list) {
          final id = r['id']?.toString();
          if (id == null || id.isEmpty) continue;
          await recomputeOverallRating(
            id,
            reason: 'manual_recompute',
            source: 'Адмін',
            sourceType: 'system',
            sourceId: 'bulk',
          );
        }
        if (list.length < pageSize) break;
        from += pageSize;
      }
    } catch (_) {}
  }
}
