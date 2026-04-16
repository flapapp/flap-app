import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/team.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists a new club row in `public.teams`.
///
/// The previous implementation called a Postgres RPC `team_create_with_squad`, which is
/// **not** present in repo migrations. The real schema uses:
/// - `public.teams` for club metadata (`owner_id` = creator).
/// - Trigger `trg_create_team_owner_membership` → inserts `public.team_members` with role `OWNER`.
/// - `public.team_members` requires a real `user_profiles` row per member; wizard “squad” entries
///   without accounts are not stored as rows (invites use `team_memberships` post-create).
abstract class TeamCreationRemoteDataSource {
  Future<String> teamCreateWithSquadRpc({
    required Team team,
    required String description,
    required bool isPublic,
    required List<Player> squad,
  });
}

class SupabaseTeamCreationRemoteDataSource
    implements TeamCreationRemoteDataSource {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  Future<String> teamCreateWithSquadRpc({
    required Team team,
    required String description,
    required bool isPublic,
    required List<Player> squad,
  }) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Authentication required');
    }

    final insert = <String, dynamic>{
      'name': team.name.trim(),
      'owner_id': uid,
      'is_public': isPublic,
    };

    final desc = description.trim();
    if (desc.isNotEmpty) {
      insert['description'] = desc;
    }

    final city = team.city?.trim();
    if (city != null && city.isNotEmpty) {
      insert['city'] = city;
    }

    final short = team.shortName?.trim();
    if (short != null && short.isNotEmpty) {
      insert['short_name'] = short;
    }

    final country = team.country?.trim();
    if (country != null && country.isNotEmpty) {
      insert['country'] = country;
    }

    final fy = team.foundedYear;
    final nowYear = DateTime.now().year;
    if (fy != null && fy >= 1800 && fy <= nowYear + 1) {
      insert['founded_at'] = '$fy-01-01';
    }

    final pc = team.primaryColor?.trim();
    if (pc != null && pc.isNotEmpty) {
      insert['primary_color'] = pc;
    }

    final sc = team.secondaryColor?.trim();
    if (sc != null && sc.isNotEmpty) {
      insert['secondary_color'] = sc;
    }

    final row = await _c.from('teams').insert(insert).select('id').single();
    return row['id'].toString();
  }
}
