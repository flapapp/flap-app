import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/coin_ledger.dart';
import '../../data/models/badge.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:flap_app/core/auth/app_auth.dart';

class BadgeService {
  static Future<void>? _initializationFuture;
  final SupabaseClient _sb = Supabase.instance.client;

  Stream<List<Badge>> getAvailableBadges() {
    return _sb
        .from('badges')
        .stream(primaryKey: ['id'])
        .order('price')
        .map((rows) => rows
            .where((r) => r['is_available'] == true)
            .map(_badgeFromRow)
            .map((b) => b.copyWith(price: _resolveEffectiveBadgePrice(b)))
            .toList(growable: false));
  }

  Stream<List<Badge>> getBadgesByCategory(String category) {
    return _sb
        .from('badges')
        .stream(primaryKey: ['id'])
        .order('price')
        .map((rows) => rows
            .where((r) => r['is_available'] == true)
            .where((r) => (r['category'] ?? '').toString() == category)
            .map(_badgeFromRow)
            .map((b) => b.copyWith(price: _resolveEffectiveBadgePrice(b)))
            .toList(growable: false));
  }

  Future<List<String>> getUserBadges(String userId) async {
    try {
      final rows = await _sb
          .from('user_badges')
          .select('badge_id, badges:badge_id(code)')
          .eq('user_id', userId);
      final out = <String>[];
      for (final raw in rows as List<dynamic>) {
        final m = raw as Map<String, dynamic>;
        final nested = m['badges'] as Map<String, dynamic>?;
        final code = (nested?['code'] ?? '').toString();
        if (code.isNotEmpty) {
          out.add(code);
        } else {
          out.add((m['badge_id'] ?? '').toString());
        }
      }
      return out;
    } catch (e) {
      print('Error getting user badges: $e');
      return <String>[];
    }
  }

  Future<bool> userOwnsBadge(String userId, String badgeId) async {
    final badge = await _badgeByCodeOrId(badgeId);
    if (badge == null) return false;
    final rows = await _sb
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId)
        .eq('badge_id', badge['id'])
        .limit(1);
    return (rows as List<dynamic>).isNotEmpty;
  }

  Future<bool> purchaseBadge(String badgeId) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      throw Exception('Користувач не авторизований');
    }

    final badgeRow = await _badgeByCodeOrId(badgeId);
    if (badgeRow == null) {
      throw Exception('Бейдж не знайдено');
    }
    final badge = _badgeFromRow(badgeRow).copyWith(
      price: _resolveEffectiveBadgePrice(_badgeFromRow(badgeRow)),
    );
    if (!badge.isAvailable) {
      throw Exception('Цей бейдж недоступний для покупки');
    }

    final alreadyOwned = await userOwnsBadge(currentUser.id, badgeId);
    if (alreadyOwned) {
      throw Exception('Ви вже маєте цей бейдж');
    }

    final balance = await coinBalance(_sb, currentUser.id);
    final effectivePrice = _resolveEffectiveBadgePrice(badge);
    if (balance < effectivePrice) {
      throw Exception('Недостатньо монет. Потрібно: $effectivePrice, у вас: $balance');
    }

    await _sb.from('user_badges').insert(<String, dynamic>{
      'user_id': currentUser.id,
      'badge_id': badgeRow['id'],
      'source': 'purchase',
    });

    final localizedBadgeName = badge.localizedName;
    await insertCoinTransaction(
      _sb,
      currentUser.id,
      'badge_purchase',
      -effectivePrice,
      bilingual('Покупка бейджу: $localizedBadgeName', 'Badge purchase: $localizedBadgeName'),
    );
    return true;
  }

  Future<void> initializeDefaultBadges() async {
    _initializationFuture ??= _syncDefaultBadges();
    await _initializationFuture;
  }

  Future<bool> awardBadge(String userId, String badgeId, String reason) async {
    try {
      final badgeRow = await _badgeByCodeOrId(badgeId);
      if (badgeRow == null) return false;

      final alreadyOwned = await userOwnsBadge(userId, badgeId);
      if (alreadyOwned) return false;

      await _sb.from('user_badges').insert(<String, dynamic>{
        'user_id': userId,
        'badge_id': badgeRow['id'],
        'source': 'award',
      });

      await insertCoinTransaction(
        _sb,
        userId,
        'badge_awarded',
        0,
        bilingual('Отримано бейдж: $reason', 'Badge received: $reason'),
      );
      return true;
    } catch (e) {
      print('Error awarding badge: $e');
      return false;
    }
  }

  Future<Badge?> getBadge(String badgeId) async {
    try {
      final row = await _badgeByCodeOrId(badgeId);
      if (row == null) return null;
      final badge = _badgeFromRow(row);
      return badge.copyWith(price: _resolveEffectiveBadgePrice(badge));
    } catch (e) {
      print('Error getting badge: $e');
      return null;
    }
  }

  Future<List<Badge>> getUserBadgeObjects(String userId) async {
    try {
      final rows = await _sb
          .from('user_badges')
          .select('badges:badge_id(*)')
          .eq('user_id', userId);
      final out = <Badge>[];
      for (final raw in rows as List<dynamic>) {
        final badgeRow = (raw as Map<String, dynamic>)['badges'];
        if (badgeRow is Map<String, dynamic>) {
          final badge = _badgeFromRow(badgeRow);
          out.add(badge.copyWith(price: _resolveEffectiveBadgePrice(badge)));
        }
      }
      return out;
    } catch (e) {
      print('Error getting user badge objects: $e');
      return <Badge>[];
    }
  }

  List<String> getBadgeCategories() {
    return <String>['starter', 'skill', 'achievement', 'legendary', 'special'];
  }

  String getCategoryDisplayName(String category) {
    switch (category) {
      case 'starter':
        return 'Початкові';
      case 'skill':
        return 'Навички';
      case 'achievement':
        return 'Досягнення';
      case 'legendary':
        return 'Легендарні';
      case 'special':
        return 'Спеціальні';
      default:
        return 'Інші';
    }
  }

  Future<void> checkAndAwardActivityBadges(String userId) async {
    try {
      if (!await userOwnsBadge(userId, 'rookie')) {
        await awardBadge(userId, 'rookie', 'Перший крок у FLAP');
      }

      final friendsRows = await _sb.from('friendships').select('friend_user_id').eq('user_id', userId);
      final friendsCount = (friendsRows as List<dynamic>).length;
      if (friendsCount >= 5 && !await userOwnsBadge(userId, 'social')) {
        await awardBadge(userId, 'social', '5+ друзів');
      }

      final matchesRows =
          await _sb.from('match_participants').select('id').eq('user_id', userId).eq('status', 'accepted');
      final matchesPlayed = (matchesRows as List<dynamic>).length;
      if (matchesPlayed >= 50 && !await userOwnsBadge(userId, 'veteran')) {
        await awardBadge(userId, 'veteran', '50+ матчів');
      }

      final ratings = await _sb
          .from('video_ratings')
          .select('overall_rating, videos:video_id(user_id)')
          .eq('videos.user_id', userId);
      double avgVideoRating = 0.0;
      final rr = ratings as List<dynamic>;
      if (rr.isNotEmpty) {
        var sum = 0.0;
        for (final raw in rr) {
          sum += (((raw as Map<String, dynamic>)['overall_rating'] as num?) ?? 0).toDouble();
        }
        avgVideoRating = sum / rr.length;
      }
      if (avgVideoRating >= 4.0 && !await userOwnsBadge(userId, 'skillful')) {
        await awardBadge(userId, 'skillful', 'Середня оцінка відео 4.0+');
      }
    } catch (e) {
      print('Error checking activity badges: $e');
    }
  }

  int _resolveEffectiveBadgePrice(Badge badge) {
    for (final defaultBadge in Badge.getDefaultBadges()) {
      if (defaultBadge.id == badge.id) return defaultBadge.price;
    }
    return badge.price;
  }

  Future<void> _syncDefaultBadges() async {
    try {
      final defaultBadges = Badge.getDefaultBadges();
      for (final badge in defaultBadges) {
        await _sb.from('badges').upsert(<String, dynamic>{
          'code': badge.id,
          'name': badge.name,
          'description': badge.description,
          'category': badge.category,
          'emoji': badge.emoji,
          'price': badge.price,
          'is_available': badge.isAvailable,
        }, onConflict: 'code');
      }
    } on PostgrestException catch (e) {
      // Non-admin clients can hit RLS here in production; defaults are seeded via migrations.
      if (e.code == '42501') {
        print('Skipping badge bootstrap sync due to RLS: ${e.message}');
        return;
      }
      print('Error initializing default badges: $e');
      _initializationFuture = null;
      rethrow;
    } catch (e) {
      print('Error initializing default badges: $e');
      _initializationFuture = null;
      rethrow;
    }
  }

  Badge _badgeFromRow(Map<String, dynamic> row) {
    return Badge(
      id: (row['code'] ?? row['id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      emoji: (row['emoji'] ?? '🏆').toString(),
      description: (row['description'] ?? '').toString(),
      price: ((row['price'] as num?) ?? 0).toInt(),
      category: (row['category'] ?? 'general').toString(),
      isAvailable: row['is_available'] != false,
      releaseDate: row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'].toString()),
    );
  }

  Future<Map<String, dynamic>?> _badgeByCodeOrId(String badgeId) async {
    var row = await _sb.from('badges').select().eq('code', badgeId).maybeSingle();
    row ??= await _sb.from('badges').select().eq('id', badgeId).maybeSingle();
    return row;
  }
}
