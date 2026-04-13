import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/player_position.dart';
import 'package:flap_app/features/team_creation/domain/entities/team.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final playersJson = squad
        .map(
          (p) => {
            'name': p.name,
            'position': p.position.wireName,
            'jersey_number': p.jerseyNumber,
            'age': p.age,
            'nationality': p.nationality,
          },
        )
        .toList();

    final res = await _c.rpc(
      'team_create_with_squad',
      params: {
        'p_name': team.name,
        'p_description': description,
        'p_city': team.city ?? '',
        'p_is_public': isPublic,
        'p_short_name': team.shortName ?? '',
        'p_founded_year': team.foundedYear,
        'p_country': team.country ?? '',
        'p_primary_color': team.primaryColor ?? '',
        'p_secondary_color': team.secondaryColor ?? '',
        'p_players': playersJson,
      },
    );
    return res as String;
  }
}
