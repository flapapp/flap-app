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

    final settingsRow = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final coins = await _coinBalance(userId);
    final friends = await _friendIds(userId);

    final badgeRows = await _client
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId);
    final badgeIds = (badgeRows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['badge_id'] as String)
        .toList();

    final overall = await _ratingSnapshot(userId, 'overall');
    final matchR = await _ratingSnapshot(userId, 'match');
    final videoR = await _ratingSnapshot(userId, 'video');

    final rating = overall ?? 3.0;
    final matchRating = matchR ?? rating;
    final videoRating = videoR ?? rating;

    final subRow = await _client
        .from('subscriptions')
        .select('*, subscription_plans(code, name)')
        .eq('user_id', userId)
        .inFilter('status', ['trial', 'active'])
        .order('starts_at', ascending: false)
        .limit(1)
        .maybeSingle();

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

    final challengeRows = await _client
        .from('challenges')
        .select('id')
        .eq('creator_id', userId);
    final challengesCreated = (challengeRows as List<dynamic>).length;

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
      'showOnlineStatus': true,
      'allowFriendRequests': true,
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
      'totalVideos': 0,
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
