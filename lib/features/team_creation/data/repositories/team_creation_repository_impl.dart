import 'dart:typed_data';

import 'package:flap_app/core/storage/supabase_team_logo_storage.dart';
import 'package:flap_app/features/team_creation/data/datasources/team_creation_remote_data_source.dart';
import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/team.dart';
import 'package:flap_app/features/team_creation/domain/repositories/team_creation_repository.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamCreationRepositoryImpl implements TeamCreationRepository {
  TeamCreationRepositoryImpl(this._remote);

  final TeamCreationRemoteDataSource _remote;

  SupabaseClient get _c => Supabase.instance.client;

  @override
  Future<String> submitTeamWithSquad({
    required String currentUserId,
    required Team team,
    required String description,
    required bool isPublic,
    required List<Player> squad,
    Uint8List? logoBytes,
  }) async {
    try {
      // [squad] is a local draft (names / jerseys) for the wizard only. The DB stores
      // `team_members` rows per real `user_profiles.id`; the owner row is created by
      // `trg_create_team_owner_membership`. Invited users go through `team_memberships`.
      final id = await _remote.teamCreateWithSquadRpc(
        team: team,
        description: description,
        isPublic: isPublic,
        squad: squad,
      );

      if (logoBytes != null) {
        final url = await SupabaseTeamLogoStorage.uploadTeamLogo(
          teamId: id,
          bytes: logoBytes,
        );
        await _c.from('teams').update({
          'logo_url': url,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', id);
      }

      return id;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('max_teams')) {
        throw Exception(
          I18n.inline(
            'Максимум 3 команди на гравця',
            'Maximum of 3 teams per player',
          ),
        );
      }
      if (s.contains('duplicate_jersey')) {
        throw Exception(
          I18n.inline(
            'Номери на формі мають бути унікальними',
            'Jersey numbers must be unique',
          ),
        );
      }
      rethrow;
    }
  }
}
