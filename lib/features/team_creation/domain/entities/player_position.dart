enum PlayerPosition {
  gk,
  df,
  mf,
  fw,
}

extension PlayerPositionX on PlayerPosition {
  String get wireName => switch (this) {
        PlayerPosition.gk => 'GK',
        PlayerPosition.df => 'DF',
        PlayerPosition.mf => 'MF',
        PlayerPosition.fw => 'FW',
      };

  String get label => switch (this) {
        PlayerPosition.gk => 'GK',
        PlayerPosition.df => 'DF',
        PlayerPosition.mf => 'MF',
        PlayerPosition.fw => 'FW',
      };

  static PlayerPosition parse(String raw) {
    switch (raw.toUpperCase()) {
      case 'GK':
        return PlayerPosition.gk;
      case 'DF':
        return PlayerPosition.df;
      case 'MF':
        return PlayerPosition.mf;
      case 'FW':
        return PlayerPosition.fw;
      default:
        return PlayerPosition.mf;
    }
  }
}
