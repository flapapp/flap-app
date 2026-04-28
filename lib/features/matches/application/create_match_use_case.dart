import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../teams/domain/repositories/teams_repository.dart';
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
    this._teamsRepository,
    this._supabaseClient,
  );

  final MatchesRepository _matchesRepository;
  final TeamsRepository _teamsRepository;
  final SupabaseClient _supabaseClient;

  Future<CreateMatchResult> execute(CreateMatchCommand command) async {
    final organizerName = await _resolveOrganizerName(
      userId: command.currentUserId,
      email: command.currentUserEmail,
    );

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

    await _sendTeamRequests(
      command: command,
      matchId: matchId,
      hostIsMyTeam: prepared.hostIsMyTeam,
    );

    if (prepared.hostIsMyTeam && command.selectedTeam != null) {
      await _sendRosterInvites(
        matchId: matchId,
        teamKey: 'teamA',
        teamName: command.selectedTeam!.name,
        playerIds: command.selectedRoster,
      );
    }

    return CreateMatchResult(
      matchId: matchId,
      organizerName: organizerName,
    );
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
    if (command.selectedInviteFriendIds.isEmpty) return;
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

  Future<void> _sendTeamRequests({
    required CreateMatchCommand command,
    required String matchId,
    required bool hostIsMyTeam,
  }) async {
    if (!command.teamMode) return;
    if (command.selectedTeam != null && !hostIsMyTeam) {
      await _teamsRepository.sendMatchRequest(
        teamId: command.selectedTeam!.id,
        opponentTeamId: command.opponentTeam?.id ?? '',
        opponentName: command.opponentTeam?.name ?? tr('il_c0886e50d4'),
        matchId: matchId,
        proposedRoster: hostIsMyTeam ? command.selectedRoster : const [],
      );
    }
    if (command.opponentTeam != null && command.selectedTeam != null) {
      await _teamsRepository.sendMatchRequest(
        teamId: command.opponentTeam!.id,
        opponentTeamId: command.selectedTeam!.id,
        opponentName: command.selectedTeam!.name,
        matchId: matchId,
        proposedRoster: const [],
      );
    }
  }

  Future<void> _sendRosterInvites({
    required String matchId,
    required String teamKey,
    required String teamName,
    required List<String> playerIds,
  }) async {
    if (playerIds.isEmpty) return;
    // Backend trigger handles roster invite notifications from roster records.
  }

  _PreparedMatchData _prepareMatchData(CreateMatchCommand command) {
    var participants = <String>[command.currentUserId];
    var currentPlayers = 1;
    var autoBalance = command.autoBalance;
    var isTeamMatch = false;
    final teamRosters = <String, List<String>>{};
    final teamRosterStatus = <String, Map<String, String>>{};
    Team? teamAData;
    Team? teamBData;
    String? teamAId;
    String? teamBId;
    String? teamAStatus;
    String? teamBStatus;
    var hostIsMyTeam = false;

    if (command.teamMode) {
      if (command.selectedTeam == null) {
        throw Exception(tr('il_f7f8b89b06'));
      }
      hostIsMyTeam = command.selectedTeam!.memberIds.contains(command.currentUserId);
      if (hostIsMyTeam && command.selectedRoster.isEmpty) {
        throw Exception(tr('il_5e90e3ad39'));
      }
      if (!hostIsMyTeam) {
        participants = <String>[];
        currentPlayers = 0;
      } else {
        participants = List<String>.from(command.selectedRoster);
        currentPlayers = participants.length;
      }
      autoBalance = false;
      isTeamMatch = true;
      teamAId = command.selectedTeam!.id;
      teamAStatus = 'pending';
      teamRosters['teamA'] =
          hostIsMyTeam ? List<String>.from(command.selectedRoster) : <String>[];
      if (hostIsMyTeam) {
        teamRosterStatus['teamA'] = {
          for (final playerId in command.selectedRoster) playerId: 'pending',
        };
      }
      if (command.opponentTeam != null) {
        teamBId = command.opponentTeam!.id;
        teamBStatus = 'pending';
        teamRosters['teamB'] = [];
        teamBData = Team(
          name: command.opponentTeam!.name,
          playerIds: const [],
        );
      }
      teamAData = Team(
        name: command.selectedTeam!.name,
        playerIds: hostIsMyTeam ? command.selectedRoster : const [],
      );
    }

    return _PreparedMatchData(
      participants: participants,
      currentPlayers: currentPlayers,
      autoBalance: autoBalance,
      isTeamMatch: isTeamMatch,
      teamRosters: teamRosters,
      teamRosterStatus: teamRosterStatus,
      teamA: teamAData,
      teamB: teamBData,
      teamAId: teamAId,
      teamBId: teamBId,
      teamAStatus: teamAStatus,
      teamBStatus: teamBStatus,
      hostIsMyTeam: hostIsMyTeam,
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
    required this.hostIsMyTeam,
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
  final bool hostIsMyTeam;
}
