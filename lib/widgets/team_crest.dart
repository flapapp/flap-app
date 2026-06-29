import 'package:flutter/material.dart';

import '../core/di/injection.dart';
import '../features/teams/domain/repositories/teams_repository.dart';
import 'team_logo_button.dart';

/// A team crest that resolves the team's uploaded logo by id (cached for the
/// session) and falls back to the initials crest while loading / when none.
///
/// Use this anywhere a match only carries a team id + name (the match payload
/// doesn't embed the logo URL).
class TeamCrest extends StatelessWidget {
  const TeamCrest({
    super.key,
    required this.teamId,
    required this.teamName,
    this.size = 28,
    this.borderRadius = 8,
    this.circular = false,
    this.onTap,
  });

  final String? teamId;
  final String teamName;
  final double size;
  final double borderRadius;
  final bool circular;
  final VoidCallback? onTap;

  // Session cache: one in-flight/resolved logo future per team id.
  static final Map<String, Future<String?>> _logoCache =
      <String, Future<String?>>{};

  /// Drop every cached team-logo future. Called on sign-out so the next user
  /// never sees logos resolved under the previous session.
  static void clearCache() => _logoCache.clear();

  static Future<String?> _resolveLogo(String teamId) {
    return _logoCache.putIfAbsent(teamId, () async {
      try {
        final team = await sl<TeamsRepository>().getTeam(teamId);
        final url = team?.logoUrl ?? '';
        return url.isEmpty ? null : url;
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = teamId;
    if (id == null || id.isEmpty) {
      return TeamLogoButton(
        teamId: id,
        teamName: teamName,
        size: size,
        circular: circular,
        borderRadius: borderRadius,
        onTap: onTap,
      );
    }
    return FutureBuilder<String?>(
      future: _resolveLogo(id),
      builder: (context, snapshot) {
        return TeamLogoButton(
          teamId: id,
          teamName: teamName,
          logoUrl: snapshot.data,
          size: size,
          circular: circular,
          borderRadius: borderRadius,
          onTap: onTap,
        );
      },
    );
  }
}
