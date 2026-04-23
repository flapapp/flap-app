import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/city_catalog.dart';

/// Server-side video feed (see [public.get_videos_feed] migration).
class VideoFeedParams {
  const VideoFeedParams({
    this.onlyUserId,
    this.categoryCodes = const <String>[],
    this.minAvgRating,
    this.cityKey,
    this.excludeChallengeRelated = true,
    this.sort = VideoFeedSort.newest,
    this.limit = 200,
  });

  final String? onlyUserId;
  final List<String> categoryCodes;
  final double? minAvgRating;
  final String? cityKey;
  final bool excludeChallengeRelated;
  final VideoFeedSort sort;
  final int limit;

  /// Sort keys match [public.get_videos_feed] (p_sort).
  Map<String, dynamic> toRpcParams() {
    return <String, dynamic>{
      'p_only_user_id': onlyUserId,
      'p_category_codes': categoryCodes.isEmpty ? null : categoryCodes,
      'p_min_avg_rating': (minAvgRating == null || minAvgRating! <= 0) ? null : minAvgRating,
      'p_city_key': (cityKey == null || cityKey!.isEmpty) ? null : cityKey,
      'p_exclude_non_feed_videos': excludeChallengeRelated,
      'p_sort': sort.pgName,
      'p_limit': limit,
    };
  }
}

enum VideoFeedSort {
  newest('newest'),
  ratingAsc('rating_asc'),
  ratingDesc('rating_desc'),
  viewsDesc('views_desc'),
  likesDesc('likes_desc'),
  myCity('my_city'),
  ;

  const VideoFeedSort(this.pgName);
  final String pgName;
}

Map<String, dynamic> mapVideoFeedRow(Map<String, dynamic> row) {
  return <String, dynamic>{
    'id': row['id']?.toString() ?? '',
    'user_id': row['user_id']?.toString() ?? '',
    'title': row['title'],
    'description': row['description'],
    'category': (row['category'] ?? row['category_code'] ?? '').toString(),
    'userId': row['user_id']?.toString() ?? '',
    'category_code': (row['category'] ?? row['category_code'] ?? '').toString(),
    'authorName': row['author_name'],
    'author_name': row['author_name'],
    'author_city': row['author_city'] ?? '',
    'city': CityCatalog.labelForDisplay((row['author_city'] ?? '').toString()),
    'rating': _toDouble(row['average_rating'] ?? row['avg_rating'] ?? 0.0),
    'averageRating': _toDouble(row['average_rating'] ?? row['avg_rating'] ?? 0.0),
    'views': (row['view_count'] is num) ? (row['view_count'] as num).toInt() : int.tryParse('${row['view_count'] ?? 0}') ?? 0,
    'likes': (row['like_count'] is num) ? (row['like_count'] as num).toInt() : int.tryParse('${row['like_count'] ?? 0}') ?? 0,
    'comments': (row['comment_count'] is num) ? (row['comment_count'] as num).toInt() : int.tryParse('${row['comment_count'] ?? 0}') ?? 0,
    'commentCount': (row['comment_count'] is num) ? (row['comment_count'] as num).toInt() : int.tryParse('${row['comment_count'] ?? 0}') ?? 0,
    'createdAt': row['created_at'],
    'created_at': row['created_at'],
    'videoUrl': row['video_url'],
    'video_url': row['video_url'],
    'thumbnailUrl': row['thumbnail_url'],
    'thumbnail_url': row['thumbnail_url'],
    'duration': row['duration'],
    'challengeId': row['challenge_id'] != null ? row['challenge_id'].toString() : '',
    'challenge_id': row['challenge_id'] != null ? row['challenge_id'].toString() : '',
    'challengeTitle': row['challenge_title'],
    'challenge_title': row['challenge_title'],
  };
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v == null) return 0.0;
  return double.tryParse(v.toString()) ?? 0.0;
}

/// Calls [get_videos_feed] and maps rows to app-friendly [Map] keys.
Future<List<Map<String, dynamic>>> getVideosFromDatabase(
  SupabaseClient client,
  VideoFeedParams params,
) async {
  final res = await client.rpc<List<dynamic>>('get_videos_feed', params: params.toRpcParams());
  return res
      .map((e) => mapVideoFeedRow(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
      .toList();
}

/// Normalized city key for the RPC, or null when "all cities" / no filter.
String? videoFeedCityKey(
  String selected, {
  required String allCitiesValue,
  String Function(String)? normalizeCity,
}) {
  if (selected.isEmpty || selected == allCitiesValue) {
    return null;
  }
  if (normalizeCity != null) {
    return normalizeCity(selected);
  }
  return CityCatalog.toEnglishStorageKey(selected);
}
