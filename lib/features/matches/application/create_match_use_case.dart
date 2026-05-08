import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/match.dart';
import '../domain/repositories/matches_repository.dart';
import 'create_match_command.dart';

class CreateMatchResult {
  const CreateMatchResult({
    required this.matchId,
    required this.organizerName,
  });

  final String matchId;
  final String organizerName;
}

class CreateMatchUseCase {
  CreateMatchUseCase(
    this._matchesRepository,
    this._supabaseClient,
  );

  final MatchesRepository _matchesRepository;
  final SupabaseClient _supabaseClient;

  Future<CreateMatchResult> execute(CreateMatchCommand command) async {
    final organizerName = await _resolveOrganizerName(
      userId: command.currentUserId,
      email: command.currentUserEmail,
    );

    // Team matches go through a single SECURITY DEFINER RPC so the matches
    // row, host slot, host roster, and team_match_requests row commit
    // together. The previous client-side multi-step flow could fail RLS on
    // the team_match_requests insert and leak orphan matches; users would
    // then re-tap "Create" and accumulate duplicates. See
    // `supabase/migrations/20260508160000_create_team_match_rpc.sql`.
    if (command.teamMode) {
      return _executeTeamMatch(command: command, organizerName: organizerName);
    }

    final prepared = _prepareMatchData(command);

    final match = Match(
      id: '',
      title: command.title,
      description: command.description,
      organizerId: command.currentUserId,
      organizerName: organizerName,
      date: command.date,
      time: command.timeLabel,
      location: command.location,
      city: command.city,
      currentPlayers: prepared.currentPlayers,
      maxPlayers: command.maxPlayers,
      participants: prepared.participants,
      level: command.level,
      cost: command.cost,
      autoBalance: prepared.autoBalance,
      isPrivate: command.isPrivate,
      invitedFriends: command.selectedInviteFriendIds,
      isTeamMatch: prepared.isTeamMatch,
      teamAId: prepared.teamAId,
      teamBId: prepared.teamBId,
      teamAStatus: prepared.teamAStatus,
      teamBStatus: prepared.teamBStatus,
      teamRosters: prepared.teamRosters,
      teamRosterStatus: prepared.teamRosterStatus,
      teamA: prepared.teamA,
      teamB: prepared.teamB,
      status: MatchStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final matchId = await _matchesRepository.createMatch(match);

    await _sendInviteNotifications(
      command: command,
      matchId: matchId,
      organizerName: organizerName,
    );

    return CreateMatchResult(
      matchId: matchId,
      organizerName: organizerName,
    );
  }

  Future<CreateMatchResult> _executeTeamMatch({
    required CreateMatchCommand command,
    required String organizerName,
  }) async {
    if (command.selectedTeam == null) {
      throw Exception(tr('il_f7f8b89b06'));
    }
    final hostIsMyTeam =
        command.selectedTeam!.memberIds.contains(command.currentUserId);
    if (hostIsMyTeam && command.selectedRoster.isEmpty) {
      throw Exception(tr('il_5e90e3ad39'));
    }

    final scheduledAt = _composeScheduledAt(command);
    final hostRoster =
        hostIsMyTeam ? List<String>.from(command.selectedRoster) : const <String>[];

    final matchId = await _matchesRepository.createTeamMatch(
      title: command.title,
      description: command.description,
      scheduledAt: scheduledAt,
      location: command.location,
      city: command.city,
      maxPlayers: command.maxPlayers,
      cost: command.cost,
      level: command.level,
      isPrivate: command.isPrivate,
      hostTeamId: command.selectedTeam!.id,
      hostRoster: hostRoster,
      opponentTeamId: command.opponentTeam?.id,
      opponentProposedRoster: hostIsMyTeam
          ? const <String>[]
          : List<String>.from(command.selectedRoster),
    );

    return CreateMatchResult(
      matchId: matchId,
      organizerName: organizerName,
    );
  }

  DateTime _composeScheduledAt(CreateMatchCommand command) {
    final parts = command.timeLabel.split(':');
    int hour = 0;
    int minute = 0;
    if (parts.length >= 2) {
      hour = int.tryParse(parts[0]) ?? 0;
      minute = int.tryParse(parts[1]) ?? 0;
    }
    final d = command.date;
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  Future<String> _resolveOrganizerName({
    required String userId,
    required String? email,
  }) async {
    final userData = await _supabaseClient
            .from('profiles')
            .select('display_name')
            .eq('id', userId)
            .maybeSingle() ??
        <String, dynamic>{};
    final emailPrefix = email?.split('@').first;
    return (userData['display_name'] ?? emailPrefix ?? tr('il_b764cdc0ea'))
        .toString();
  }

  Future<void> _sendInviteNotifications({
    required CreateMatchCommand command,
    required String matchId,
    required String organizerName,
  }) async {
    if (command.teamMode || command.selectedInviteFriendIds.isEmpty) return;
    try {
      for (final userId in command.selectedInviteFriendIds) {
        await _supabaseClient.from('match_invites').upsert(
          {
            'match_id': matchId,
            'user_id': userId,
            'invited_by': command.currentUserId,
            'status': 'pending',
          },
          onConflict: 'match_id,user_id',
        );
      }
    } catch (_) {}
  }

  /// Non-team match preparation. Team matches go through the SECURITY
  /// DEFINER RPC `create_team_match` and never hit this code path.
  _PreparedMatchData _prepareMatchData(CreateMatchCommand command) {
    return _PreparedMatchData(
      participants: <String>[command.currentUserId],
      currentPlayers: 1,
      autoBalance: command.autoBalance,
      isTeamMatch: false,
      teamRosters: const <String, List<String>>{},
      teamRosterStatus: const <String, Map<String, String>>{},
      teamA: null,
      teamB: null,
      teamAId: null,
      teamBId: null,
      teamAStatus: null,
      teamBStatus: null,
    );
  }
}

class _PreparedMatchData {
  const _PreparedMatchData({
    required this.participants,
    required this.currentPlayers,
    required this.autoBalance,
    required this.isTeamMatch,
    required this.teamRosters,
    required this.teamRosterStatus,
    required this.teamA,
    required this.teamB,
    required this.teamAId,
    required this.teamBId,
    required this.teamAStatus,
    required this.teamBStatus,
  });

  final List<String> participants;
  final int currentPlayers;
  final bool autoBalance;
  final bool isTeamMatch;
  final Map<String, List<String>> teamRosters;
  final Map<String, Map<String, String>> teamRosterStatus;
  final Team? teamA;
  final Team? teamB;
  final String? teamAId;
  final String? teamBId;
  final String? teamAStatus;
  final String? teamBStatus;
}
