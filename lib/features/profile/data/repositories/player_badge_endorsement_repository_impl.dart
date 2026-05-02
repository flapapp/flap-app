import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/player_badge_endorsement_repository.dart';

class PlayerBadgeEndorsementRepositoryImpl
    implements PlayerBadgeEndorsementRepository {
  PlayerBadgeEndorsementRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<BadgeEndorsementInfo> getEndorsementInfo({
    required String ownerUserId,
    required String badgeId,
    String? currentUserId,
  }) async {
    try {
      final data = await _client.rpc(
        'badge_endorsement_stats',
        params: <String, dynamic>{
          'p_owner_user_id': ownerUserId,
          'p_badge_id': badgeId,
        },
      );
      var count = 0;
      var endorsed = false;
      if (data is List && data.isNotEmpty) {
        final row = data.first;
        if (row is Map) {
          final m = Map<String, dynamic>.from(row);
          count = (m['endorsement_count'] as num?)?.toInt() ?? 0;
          endorsed = m['endorsed_by_viewer'] == true;
        }
      } else if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        count = (m['endorsement_count'] as num?)?.toInt() ?? 0;
        endorsed = m['endorsed_by_viewer'] == true;
      }
      return BadgeEndorsementInfo(
        count: count,
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
          // Display title in notification list / push; counts use [notification_type_id] + payload only.
          'p_title': tr('il_cd519087d2'),
          'p_message': tr(
            'notif_badge_endorsed_by',
            namedArgs: {
              'name': currentName,
              'badge': badgeLocalizedName,
            },
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
