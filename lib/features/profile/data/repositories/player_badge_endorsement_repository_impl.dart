import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/supabase/supabase_lookups.dart';
import '../../domain/repositories/player_badge_endorsement_repository.dart';

class PlayerBadgeEndorsementRepositoryImpl
    implements PlayerBadgeEndorsementRepository {
  PlayerBadgeEndorsementRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _titleKey = 'badge_endorsement_event';

  @override
  Future<BadgeEndorsementInfo> getEndorsementInfo({
    required String ownerUserId,
    required String badgeId,
    String? currentUserId,
  }) async {
    try {
      final tid = await SupabaseLookups.notificationTypeId(
        _client,
        'badge_endorsed',
        'Badge endorsed',
      );
      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', ownerUserId)
          .eq('notification_type_id', tid)
          .eq('title', _titleKey);
      final endorsers = <String>{};
      for (final raw in rows as List<dynamic>) {
        final m = raw as Map<String, dynamic>;
        try {
          final payload = jsonDecode(m['message'] as String) as Map<String, dynamic>;
          if (payload['badgeId']?.toString() == badgeId) {
            endorsers.add(payload['endorserUserId'] as String);
          }
        } catch (_) {}
      }
      final list = endorsers.toList();
      final endorsed =
          currentUserId != null && endorsers.contains(currentUserId);
      return BadgeEndorsementInfo(
        count: list.length,
        endorsedByCurrentUser: endorsed,
      );
    } catch (_) {
      return const BadgeEndorsementInfo(count: 0, endorsedByCurrentUser: false);
    }
  }

  @override
  Future<Result<Unit>> endorseBadge({
    required String ownerUserId,
    required String badgeId,
    required String badgeLocalizedName,
    required String endorserUserId,
  }) async {
    if (endorserUserId == ownerUserId) {
      return Result.failure(
        Failure.unexpected(
          tr('il_472d788d72'),
        ),
      );
    }

    try {
      final info = await getEndorsementInfo(
        ownerUserId: ownerUserId,
        badgeId: badgeId,
        currentUserId: endorserUserId,
      );
      if (info.endorsedByCurrentUser) {
        return Result.failure(
          Failure.unexpected(
            tr('il_f7964d75ff'),
          ),
        );
      }

      final endorser = await _client
          .from('profiles')
          .select('display_name,first_name,last_name')
          .eq('id', endorserUserId)
          .maybeSingle();
      final currentName = _nameFromProfile(endorser);

      final idempotencyKey = 'badge_endorse:$ownerUserId:$badgeId:$endorserUserId';
      await _client.rpc(
        'enqueue_notification_backend',
        params: <String, dynamic>{
          'p_target_user_id': ownerUserId,
          'p_type_code': 'badge_endorsed',
          'p_title': tr('il_cd519087d2'),
          'p_message': bilingual(
            '$currentName підтвердив ваш бейдж "$badgeLocalizedName"',
            '$currentName confirmed your badge "$badgeLocalizedName"',
          ),
          'p_data': <String, dynamic>{
            'badgeId': badgeId,
            'endorserUserId': endorserUserId,
          },
          'p_idempotency_key': idempotencyKey,
        },
      );

      return const Result.success(Unit.value);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }

  static String _nameFromProfile(Map<String, dynamic>? p) {
    if (p == null) {
      return tr('il_b512d97e7c');
    }
    final dn = p['display_name']?.toString() ?? '';
    if (dn.isNotEmpty) {
      return dn;
    }
    final fn = p['first_name']?.toString() ?? '';
    final ln = p['last_name']?.toString() ?? '';
    final s = '$fn $ln'.trim();
    return s.isNotEmpty ? s : tr('il_b512d97e7c');
  }
}
