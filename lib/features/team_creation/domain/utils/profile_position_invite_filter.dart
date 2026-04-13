import 'package:flap_app/core/profile_field_options.dart';
import 'package:flap_app/features/team_creation/domain/entities/player_position.dart';

/// Maps wizard role filter to values stored in `public.profiles.position`
/// (aligned with [ProfileFieldOptions.positionStorageValues] plus English keys).
List<String>? profileDbValuesForInviteFilter(PlayerPosition? filter) {
  if (filter == null) return null;
  final v = ProfileFieldOptions.positionStorageValues;
  final universal = v[4];
  switch (filter) {
    case PlayerPosition.gk:
      return [
        v[0],
        'goalkeeper',
        'Goalkeeper',
        'gk',
        'GK',
        universal,
      ];
    case PlayerPosition.df:
      return [
        v[1],
        'defender',
        'Defender',
        'df',
        'DF',
        universal,
      ];
    case PlayerPosition.mf:
      return [
        v[2],
        'midfielder',
        'Midfielder',
        'mf',
        'MF',
        universal,
      ];
    case PlayerPosition.fw:
      return [
        v[3],
        'forward',
        'Forward',
        'fw',
        'FW',
        universal,
      ];
  }
}
