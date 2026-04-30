import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../notifications/data/services/notification_service.dart';
import 'rating_tracking_service.dart';
import 'package:flap_app/core/auth/app_auth.dart';

class RatingService {
  static const double _defaultRating = 3.0;

  static const List<String> _matchCriteria = <String>[
    'technical',
    'physical',
    'tactical',
    'teamwork',
  ];

  static const List<String> _videoCriteria = <String>[
    'technical',
    'creativity',
    'difficulty',
    'quality',
  ];

  static const Map<String, double> _videoWeights = <String, double>{
    'technical': 0.4,
    'creativity': 0.3,
    'difficulty': 0.2,
    'quality': 0.1,
  };

  final SupabaseClient _sb = Supabase.instance.client;
  final NotificationService _notificationService;

  RatingService({NotificationService? notificationService})
    : _notificationService = notificationService ?? sl<NotificationService>();

  Future<void> updateVideoAggregate(String videoId) async {
    try {
      final ratings = await _sb
          .from('video_ratings')
          .select('overall_rating')
          .eq('video_id', videoId);
      final rows = ratings as List<dynamic>;
      double sum = 0.0;
      for (final raw in rows) {
        sum += ((raw as Map<String, dynamic>)['overall_rating'] as num)
            .toDouble();
      }
      final avg = rows.isEmpty
          ? 0.0
          : double.parse((sum / rows.length).toStringAsFixed(2));
      await _sb
          .from('videos')
          .update(<String, dynamic>{
            'description': 'rating:$avg;votes:${rows.length}',
          })
          .eq('id', videoId);
    } catch (_) {
      // non-fatal
    }
  }

  Future<double> getUserRating(String userId) async {
    try {
      final row = await _sb
          .from('user_rating_snapshots')
          .select('rating_value')
          .eq('user_id', userId)
          .eq('rating_scope', 'overall')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return _defaultRating;
      final value = row['rating_value'];
      if (value is num && value > 0) return value.toDouble();
      return _defaultRating;
    } catch (_) {
      return _defaultRating;
    }
  }

  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    try {
      final current = await getUserRating(userId);
      final matchR = await _latestSnapshot(userId, 'match') ?? current;
      final videoR = await _latestSnapshot(userId, 'video') ?? current;

      final matches = await _sb
          .from('match_participants')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'accepted');
      final videos = await _sb
          .from('videos')
          .select('id')
          .eq('user_id', userId);
      return <String, dynamic>{
        'currentRating': current,
        'matchRating': matchR,
        'videoRating': videoR,
        'totalMatches': (matches as List<dynamic>).length,
        'totalVideos': (videos as List<dynamic>).length,
        'ratingHistory': const <Map<String, dynamic>>[],
      };
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> ratePlayerAfterMatch({
    required String matchId,
    required String playerId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) async {
    if (playerId == ratedBy) {
      throw Exception('Не можна оцінювати самого себе');
    }
    for (final criterion in _matchCriteria) {
      if (!criteria.containsKey(criterion)) {
        throw Exception('Відсутній критерій: $criterion');
      }
      if (criteria[criterion]! < 0.0 || criteria[criterion]! > 5.0) {
        throw Exception('Оцінка має бути від 0.0 до 5.0');
      }
    }

    final participants = await _sb
        .from('match_participants')
        .select('user_id,status')
        .eq('match_id', matchId)
        .eq('status', 'accepted');
    final ids = (participants as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['user_id'].toString())
        .toSet();
    if (!ids.contains(playerId) || !ids.contains(ratedBy)) {
      throw Exception('Лише учасники можуть оцінювати');
    }

    double total = 0.0;
    for (final criterion in _matchCriteria) {
      total += criteria[criterion]!;
    }
    final averageRating = total / _matchCriteria.length;

    final inserted = await _sb
        .from('match_player_ratings')
        .upsert(<String, dynamic>{
          'match_id': matchId,
          'player_id': playerId,
          'rated_by': ratedBy,
          'overall_rating': averageRating,
        })
        .select('id')
        .single();
    final ratingId = inserted['id'].toString();

    for (final entry in criteria.entries) {
      final criterionId = await _criterionId(entry.key);
      if (criterionId == null) continue;
      await _sb.from('match_player_rating_scores').upsert(<String, dynamic>{
        'match_player_rating_id': ratingId,
        'criterion_id': criterionId,
        'score': entry.value,
      });
    }

    var raterName = tr('il_64aee8c6cb');
    try {
      final rater = await _sb
          .from('profiles')
          .select('display_name, nickname, first_name, last_name')
          .eq('id', ratedBy)
          .maybeSingle();
      if (rater != null) {
        raterName =
            (rater['display_name'] ??
                    rater['nickname'] ??
                    '${rater['first_name'] ?? ''} ${rater['last_name'] ?? ''}'
                        .trim() ??
                    tr('il_64aee8c6cb'))
                .toString();
      }
    } catch (_) {}

    await _updatePlayerRating(
      playerId,
      reason: 'match_rating',
      source: raterName,
      sourceType: 'match',
      sourceId: matchId,
    );
  }

  Future<bool> rateVideo({
    required String videoId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) async {
    try {
      for (final criterion in _videoCriteria) {
        if (!criteria.containsKey(criterion)) {
          throw Exception('Відсутній критерій: $criterion');
        }
        if (criteria[criterion]! < 0.0 || criteria[criterion]! > 5.0) {
          throw Exception('Оцінка має бути від 0.0 до 5.0');
        }
      }

      double weightedRating = 0.0;
      for (final criterion in _videoCriteria) {
        weightedRating += criteria[criterion]! * _videoWeights[criterion]!;
      }

      final inserted = await _sb
          .from('video_ratings')
          .upsert(<String, dynamic>{
            'video_id': videoId,
            'rated_by': ratedBy,
            'overall_rating': weightedRating,
          })
          .select('id')
          .single();
      final ratingId = inserted['id'].toString();

      for (final entry in criteria.entries) {
        final criterionId = await _criterionId(entry.key);
        if (criterionId == null) continue;
        await _sb.from('video_rating_scores').upsert(<String, dynamic>{
          'video_rating_id': ratingId,
          'criterion_id': criterionId,
          'score': entry.value,
        });
      }

      await updateVideoAggregate(videoId);

      final video = await _sb
          .from('videos')
          .select('user_id, title')
          .eq('id', videoId)
          .maybeSingle();
      if (video != null) {
        final authorId = (video['user_id'] ?? '').toString();
        final videoTitle = (video['title'] ?? 'Відео').toString();
        if (authorId.isNotEmpty && authorId != ratedBy) {
          var voterName = 'Користувач';
          try {
            final voter = await _sb
                .from('profiles')
                .select('display_name, nickname, first_name, last_name')
                .eq('id', ratedBy)
                .maybeSingle();
            if (voter != null) {
              voterName =
                  (voter['display_name'] ??
                          voter['nickname'] ??
                          '${voter['first_name'] ?? ''} ${voter['last_name'] ?? ''}'
                              .trim() ??
                          AppAuth.currentUserEmail?.split('@')[0] ??
                          'Користувач')
                      .toString();
            }
          } catch (_) {}

          final oldRating = await getUserRating(authorId);
          await _updatePlayerRating(
            authorId,
            reason: 'Оцінка відео ${weightedRating.toStringAsFixed(1)}',
            source: voterName,
            sourceType: 'video',
            sourceId: videoId,
          );
          final newRating = await getUserRating(authorId);
          final delta = newRating - oldRating;
          await _notificationService.sendVideoVoteNotification(
            toUserId: authorId,
            videoTitle: videoTitle,
            voterName: voterName,
            rating: weightedRating,
          );
          await _notificationService.sendRatingChangedNotification(
            toUserId: authorId,
            voterName: voterName,
            rating: weightedRating,
            delta: delta,
            newRating: newRating,
            videoTitle: videoTitle,
          );
        }
      }
      return true;
    } catch (e) {
      print('Error rating video: $e');
      return false;
    }
  }

  Future<void> _updatePlayerRating(
    String userId, {
    String? reason,
    String? source,
    String? sourceType,
    String? sourceId,
  }) async {
    try {
      final oldRating = await getUserRating(userId);
      await _sb.rpc(
        'recompute_player_overall_rating',
        params: <String, dynamic>{'p_user_id': userId},
      );
      final roundedOverall = await getUserRating(userId);

      try {
        if (reason != null) {
          await RatingTrackingService().recordRatingChange(
            userId: userId,
            oldRating: double.parse(oldRating.toStringAsFixed(2)),
            newRating: roundedOverall,
            reason: reason,
            voterName: source,
            challengeId: sourceType == 'challenge' ? sourceId : null,
            videoTitle: sourceType == 'video' ? sourceId : null,
          );
        }
      } catch (_) {}

      if (reason != null && source != null && reason != 'challenge_vote') {
        final delta = double.parse(
          (roundedOverall - oldRating).toStringAsFixed(2),
        );
        await _notificationService.sendRatingChangedNotification(
          toUserId: userId,
          voterName: source,
          rating: 0.0,
          delta: delta,
          newRating: roundedOverall,
          videoTitle: sourceType == 'video' ? (sourceId ?? '') : null,
        );
      }
    } catch (e) {
      print('Error updating player rating: $e');
    }
  }

  Future<void> _saveSnapshot(String userId, String scope, double value) async {
    await _sb.from('user_rating_snapshots').insert(<String, dynamic>{
      'user_id': userId,
      'rating_scope': scope,
      'rating_value': value,
    });
  }

  Future<double?> _latestSnapshot(String userId, String scope) async {
    final row = await _sb
        .from('user_rating_snapshots')
        .select('rating_value')
        .eq('user_id', userId)
        .eq('rating_scope', scope)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final v = row['rating_value'];
    return (v is num) ? v.toDouble() : null;
  }

  Future<String?> _criterionId(String code) async {
    final row = await _sb
        .from('rating_criteria')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    return row?['id']?.toString();
  }

  Future<List<Map<String, dynamic>>> getTopPlayers({
    int limit = 50,
    String? city,
    String? position,
  }) async {
    try {
      final profiles = await _sb.from('profiles').select();
      final out = <Map<String, dynamic>>[];
      for (final raw in profiles as List<dynamic>) {
        final p = raw as Map<String, dynamic>;
        final id = (p['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final rating = await getUserRating(id);
        final userCity = (p['city'] ?? '').toString();
        final userPosition = (p['position'] ?? '').toString();
        if (city != null &&
            city.isNotEmpty &&
            city != 'Всі міста' &&
            userCity != city) {
          continue;
        }
        if (position != null &&
            position.isNotEmpty &&
            position != 'Всі позиції' &&
            userPosition != position) {
          continue;
        }
        final matches = await _sb
            .from('match_participants')
            .select('id')
            .eq('user_id', id)
            .eq('status', 'accepted');
        final videos = await _sb.from('videos').select('id').eq('user_id', id);
        out.add(<String, dynamic>{
          'id': id,
          'name':
              p['display_name'] ??
              p['nickname'] ??
              '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim(),
          'rating': rating,
          'city': userCity.isNotEmpty ? userCity : 'Невідомо',
          'position': userPosition.isNotEmpty ? userPosition : 'Невідомо',
          'totalMatches': (matches as List<dynamic>).length,
          'totalVideos': (videos as List<dynamic>).length,
          'avatarUrl': p['avatar_url'] ?? '',
        });
      }
      out.sort(
        (a, b) => (b['rating'] as double).compareTo(a['rating'] as double),
      );
      return out.take(limit).toList(growable: false);
    } catch (e) {
      print('Error getting top players: $e');
      return <Map<String, dynamic>>[];
    }
  }

  String getPlayerLevel(double rating) {
    if (rating >= 0.0 && rating < 1.5) return tr('il_c865ebb305');
    if (rating >= 1.5 && rating < 2.5) return tr('il_7df0f3202d');
    if (rating >= 2.5 && rating < 3.5) return tr('il_3b1cfa63d7');
    if (rating >= 3.5 && rating < 4.5) return tr('il_9f088dbebd');
    if (rating >= 4.5 && rating <= 5.0) return tr('il_19c73a5cdf');
    return tr('il_b764cdc0ea');
  }

  int getPlayerLevelColor(double rating) {
    if (rating >= 0.0 && rating < 1.5) return 0xFF9E9E9E;
    if (rating >= 1.5 && rating < 2.5) return 0xFF4CAF50;
    if (rating >= 2.5 && rating < 3.5) return 0xFF2196F3;
    if (rating >= 3.5 && rating < 4.5) return 0xFFFF9800;
    if (rating >= 4.5 && rating <= 5.0) return 0xFF9C27B0;
    return 0xFF9E9E9E;
  }

  Future<void> createUserWithDefaultRating(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      await _saveSnapshot(userId, 'overall', _defaultRating);
      await _saveSnapshot(userId, 'match', _defaultRating);
      await _saveSnapshot(userId, 'video', _defaultRating);
    } catch (e) {
      print('Error creating user with default rating: $e');
    }
  }

  double getDefaultRating() => _defaultRating;

  Stream<double> getMatchRating(String matchId) {
    return _sb.from('match_player_ratings').stream(primaryKey: ['id']).asyncMap(
      (rows) async {
        final ratings = <double>[];
        for (final raw in rows as List<dynamic>) {
          final row = raw as Map<String, dynamic>;
          if ((row['match_id'] ?? '').toString() != matchId) continue;
          ratings.add(((row['overall_rating'] as num?) ?? 0).toDouble());
        }
        if (ratings.isEmpty) return 0.0;
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        return double.parse(avg.toStringAsFixed(2));
      },
    );
  }

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

  Future<void> recomputeForMatchParticipants(String matchId) async {
    try {
      final rows = await _sb
          .from('match_participants')
          .select('user_id')
          .eq('match_id', matchId)
          .eq('status', 'accepted');
      final ids = (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['user_id'].toString())
          .toSet();
      for (final uid in ids) {
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

  Future<void> recomputeAllUsers({int pageSize = 200}) async {
    try {
      final rows = await _sb.from('profiles').select('id');
      for (final raw in rows as List<dynamic>) {
        final id = (raw as Map<String, dynamic>)['id'].toString();
        if (id.isEmpty) continue;
        await recomputeOverallRating(
          id,
          reason: 'manual_recompute',
          source: 'Адмін',
          sourceType: 'system',
          sourceId: 'bulk',
        );
      }
    } catch (_) {}
  }
}
