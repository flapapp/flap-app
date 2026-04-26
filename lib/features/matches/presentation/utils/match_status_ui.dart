import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../data/models/match.dart';

class MatchStatusUi {
  final Color color;
  final String label;

  const MatchStatusUi({
    required this.color,
    required this.label,
  });
}

MatchStatusUi buildMatchStatusUi(MatchStatus status, {Match? match}) {
  if (match?.isUnplayedByTimeout == true) {
    return MatchStatusUi(
      color: const Color(0xFF607D8B),
      label: tr('il_ee288d682b'),
    );
  }

  switch (status) {
    case MatchStatus.open:
      return MatchStatusUi(
        color: const Color(0xFF4caf50),
        label: tr('il_ed077f3d81'),
      );
    case MatchStatus.full:
      return MatchStatusUi(
        color: Colors.orange,
        label: tr('il_008dacb6d1'),
      );
    case MatchStatus.inProgress:
      return MatchStatusUi(
        color: const Color(0xFF2196f3),
        label: tr('il_c1f88e9d6c'),
      );
    case MatchStatus.finished:
      return MatchStatusUi(
        color: Colors.grey,
        label: tr('il_7804f7a79a'),
      );
    case MatchStatus.cancelled:
      return MatchStatusUi(
        color: Colors.red,
        label: tr('il_d353a99eb4'),
      );
  }
}

MatchStatusUi buildMatchListStatusUi(MatchStatus status, {Match? match}) {
  if (match?.isUnplayedByTimeout == true) {
    return MatchStatusUi(
      color: const Color(0xFF607D8B),
      label: tr('il_ee288d682b'),
    );
  }

  switch (status) {
    case MatchStatus.open:
      return MatchStatusUi(
        color: const Color(0xFF4caf50),
        label: tr('status_open'),
      );
    case MatchStatus.full:
      return MatchStatusUi(
        color: Colors.blue,
        label: tr('status_full'),
      );
    case MatchStatus.inProgress:
      return MatchStatusUi(
        color: Colors.orange,
        label: tr('status_in_progress'),
      );
    case MatchStatus.finished:
      return MatchStatusUi(
        color: Colors.grey,
        label: tr('status_finished'),
      );
    case MatchStatus.cancelled:
      return MatchStatusUi(
        color: Colors.red,
        label: tr('status_cancelled'),
      );
  }
}
