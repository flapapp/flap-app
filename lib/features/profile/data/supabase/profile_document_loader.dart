import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_date.dart';

/// Builds the legacy `users/{uid}`-shaped map consumed by [UserProfile.fromDocument].
class ProfileDocumentLoader {
  ProfileDocumentLoader(this._client);

  final SupabaseClient _client;

  Future<int> _coinBalance(String userId) async {
    final rows = await _client
        .from('coin_transactions')
        .select('amount')
        .eq('user_id', userId);
    var sum = 0;
    for (final r in rows as List<dynamic>) {
      final m = r as Map<String, dynamic>;
      sum += (m['amount'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  Future<List<String>> _friendIds(String userId) async {
    final rows = await _client
        .from('friendships')
        .select('friend_user_id')
        .eq('user_id', userId);
    return (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['friend_user_id'] as String)
        .toList();
  }

  Future<double?> _ratingSnapshot(String userId, String scope) async {
    final row = await _client
        .from('user_rating_snapshots')
        .select('rating_value')
        .eq('user_id', userId)
        .eq('rating_scope', scope)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return (row?['rating_value'] as num?)?.toDouble();
  }

  Future<Map<String, dynamic>?> load(String userId) async {
    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (profile == null) {
      return null;
    }

    // The remaining reads only depend on [userId] and are independent of each
    // other, so run them concurrently instead of one sequential round-trip per
    // query. This collapses ~10 serial network waits into a single batch, which
    // is the dominant cost of post-login navigation. Future.wait triggers each
    // Postgrest builder exactly once, so they all fire in parallel.
    final results = await Future.wait<dynamic>([
      _client
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle(),
      _coinBalance(userId),
      _friendIds(userId),
      _client.from('user_badges').select('badge_id').eq('user_id', userId),
      _ratingSnapshot(userId, 'overall'),
      _ratingSnapshot(userId, 'match'),
      _ratingSnapshot(userId, 'video'),
      _client
          .from('subscriptions')
          .select('*, subscription_plans(code, name)')
          .eq('user_id', userId)
          .inFilter('status', ['trial', 'active'])
          .order('starts_at', ascending: false)
          .limit(1)
          .maybeSingle(),
      _client.from('challenges').select('id').eq('creator_id', userId),
      _client.from('videos').select('id').eq('user_id', userId),
    ]);

    final settingsRow = results[0] as Map<String, dynamic>?;
    final coins = results[1] as int;
    final friends = results[2] as List<String>;

    final badgeRows = results[3] as List<dynamic>;
    final badgeIds = badgeRows
        .map((r) => (r as Map<String, dynamic>)['badge_id'] as String)
        .toList();

    final overall = results[4] as double?;
    final matchR = results[5] as double?;
    final videoR = results[6] as double?;

    final rating = overall ?? 3.0;
    final matchRating = matchR ?? rating;
    final videoRating = videoR ?? rating;

    final subRow = results[7] as Map<String, dynamic>?;

    String subscriptionCode = 'free';
    bool subscriptionActive = false;
    DateTime? subscriptionEnd;
    DateTime? trialEnd;
    if (subRow != null) {
      final plan = subRow['subscription_plans'];
      if (plan is Map<String, dynamic>) {
        subscriptionCode = (plan['code'] ?? 'free').toString();
      }
      final st = subRow['status']?.toString();
      subscriptionActive = st == 'trial' || st == 'active';
      subscriptionEnd = asDateTimeOrNull(subRow['ends_at']);
      trialEnd = asDateTimeOrNull(subRow['trial_ends_at']);
    }

    final localeRaw =
        (settingsRow?['locale'] ?? 'en').toString();
    final localeUi = localeRaw == 'ua' ? 'uk' : localeRaw;

    final challengesCreated = (results[8] as List<dynamic>).length;

    final videosCount = (results[9] as List<dynamic>).length;

    final firstName = profile['first_name'] as String? ?? '';
    final lastName = profile['last_name'] as String? ?? '';
    final displayName = (profile['display_name'] as String?)?.trim().isNotEmpty == true
        ? profile['display_name'] as String
        : '$firstName $lastName'.trim();

    final dob = asDateTimeOrNull(profile['dat_of_birth']);
    int age = 0;
    if (dob != null) {
      final n = DateTime.now();
      age = n.year -
          dob.year -
          ((n.month < dob.month ||
                  (n.month == dob.month && n.day < dob.day))
              ? 1
              : 0);
    }
    final dateOfBirthIso = dob != null
        ? '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}'
        : '';

    final settingsMap = <String, dynamic>{
      'hideDonationPrompt': false,
      'notificationsEnabled': settingsRow?['notifications_enabled'] != false,
      'autoplayVideos': settingsRow?['autoplay_videos'] != false,
      'showOnlineStatus': settingsRow?['show_online_status'] != false,
      'allowFriendRequests': settingsRow?['allow_friend_requests'] != false,
      'locale': localeUi,
    };

    return <String, dynamic>{
      'id': userId,
      'email': profile['email'],
      'firstName': firstName,
      'lastName': lastName,
      'name': firstName.isNotEmpty ? firstName : displayName,
      'surname': lastName,
      'authorName': displayName,
      'displayName': displayName,
      'phone': '',
      'city': profile['city'] ?? '',
      'country': profile['country'],
      'dateOfBirth': dateOfBirthIso,
      'age': age,
      'position': profile['position'] ?? '',
      'nickname': profile['nickname'],
      'avatarUrl': profile['avatar_url'],
      'avatar': profile['avatar_url'],
      'createdAt': profile['created_at'],
      'updatedAt': profile['updated_at'],
      'rating': rating,
      'matchRating': matchRating,
      'videoRating': videoRating,
      'totalMatches': 0,
      'totalVideos': videosCount,
      'videosUploaded': videosCount,
      'ratingHistory': <dynamic>[],
      'lastRatingUpdate': profile['updated_at'],
      'coins': coins,
      'matches': 0,
      'goals': 0,
      'assists': 0,
      'subscription': subscriptionCode,
      'subscriptionExpiry': subscriptionEnd?.toIso8601String(),
      'subscriptionActive': subscriptionActive,
      'trialEndDate': trialEnd?.toIso8601String(),
      'challengesCreated': challengesCreated,
      'maxChallengesPerMonth': subscriptionCode == 'champions' ||
              subscriptionCode == 'champions_league'
          ? 999
          : subscriptionCode == 'europa'
              ? 5
              : 1,
      'friends': friends,
      'friendsCount': friends.length,
      'badges': badgeIds,
      'settings': settingsMap,
      'isAdmin': profile['is_admin'] == true,
      'lastSeen': profile['last_seen_at'],
    };
  }
}
