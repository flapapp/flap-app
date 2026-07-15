import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/locale/football_position.dart';
import '../../../../utils/city_catalog.dart';
import '../supabase/profile_document_loader.dart';
import 'profile_remote_datasource.dart';

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;
  late final ProfileDocumentLoader _loader = ProfileDocumentLoader(_client);

  @override
  Future<Map<String, dynamic>?> getUserDocument(String userId) =>
      _loader.load(userId);

  @override
  Future<void> mergeUserSettings(
    String userId,
    Map<String, dynamic> settingsPatch,
  ) async {
    final row = <String, dynamic>{
      'user_id': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (settingsPatch.containsKey('notificationsEnabled')) {
      row['notifications_enabled'] = settingsPatch['notificationsEnabled'] == true;
    }
    if (settingsPatch.containsKey('autoplayVideos')) {
      row['autoplay_videos'] = settingsPatch['autoplayVideos'] == true;
    }
    if (settingsPatch.containsKey('locale')) {
      final localeRaw = settingsPatch['locale']?.toString();
      row['locale'] = localeRaw == 'uk' ? 'ua' : (localeRaw ?? 'en');
    }
    if (settingsPatch.containsKey('showOnlineStatus')) {
      row['show_online_status'] = settingsPatch['showOnlineStatus'] == true;
    }
    if (settingsPatch.containsKey('allowFriendRequests')) {
      row['allow_friend_requests'] =
          settingsPatch['allowFriendRequests'] == true;
    }

    await _client.from('user_settings').upsert(
      row,
      onConflict: 'user_id',
    );
  }

  @override
  Future<void> mergeUserDocument(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    final displayName = patch['displayName'] ?? patch['authorName'];
    final firstName = patch['firstName'];
    final lastName = patch['lastName'];
    final avatarUrl = patch['avatarUrl'] ?? patch['avatar'];

    final row = <String, dynamic>{};
    if (displayName is String && displayName.isNotEmpty) {
      row['display_name'] = displayName;
    }
    if (firstName is String) {
      row['first_name'] = firstName;
    }
    if (lastName is String) {
      row['last_name'] = lastName;
    }
    if (patch['city'] is String) {
      final c = (patch['city'] as String).trim();
      if (c.isEmpty) {
        row['city'] = c;
      } else {
        final en = CityCatalog.toEnglishStorageKey(c);
        row['city'] = (en != null && en.isNotEmpty) ? en : c;
      }
    }
    if (patch['position'] is String) {
      final p = positionToEnglishDb(patch['position'] as String);
      if (p != null) {
        row['position'] = p;
      }
    }
    final dob = patch['dateOfBirth'];
    if (dob is DateTime) {
      final d = DateTime(dob.year, dob.month, dob.day);
      row['dat_of_birth'] =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    if (avatarUrl is String && avatarUrl.isNotEmpty) {
      row['avatar_url'] = avatarUrl;
    }
    if (row.isEmpty) {
      return;
    }
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('profiles').update(row).eq('id', userId);
  }

  @override
  Future<void> trySeedDemoCrossFriends(String userId) async {
    try {
      final others = await _client
          .from('profiles')
          .select('id')
          .neq('id', userId)
          .limit(4);
      final ids = (others as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      if (ids.isEmpty) {
        return;
      }
      for (final fid in ids) {
        await _insertFriendshipPair(userId, fid);
      }
    } catch (_) {}
  }

  Future<void> _insertFriendshipPair(String a, String b) async {
    try {
      await _client.from('friendships').insert(<String, dynamic>{
        'user_id': a,
        'friend_user_id': b,
      });
    } catch (_) {}
    try {
      await _client.from('friendships').insert(<String, dynamic>{
        'user_id': b,
        'friend_user_id': a,
      });
    } catch (_) {}
  }

  @override
  Future<Map<String, Map<String, dynamic>>> getUserDocumentsByIds(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return {};
    }
    final out = <String, Map<String, dynamic>>{};
    for (final id in userIds) {
      final doc = await _loader.load(id);
      if (doc != null) {
        out[id] = doc;
      }
    }
    return out;
  }
}
