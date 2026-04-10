import 'package:flutter/material.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/teams/domain/repositories/teams_repository.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/matches_repository.dart';
import 'datasources/matches_remote_data_source.dart';

class MatchesRepositoryImpl implements MatchesRepository {
  MatchesRepositoryImpl(this._remote, this._profiles, this._teams);

  final MatchesRemoteDataSource _remote;
  final UserProfileRepository _profiles;
  final TeamsRepository _teams;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  Stream<List<Match>> getAvailableMatches() {
    return _remote.watchMatchesTable().map((all) {
      final matches = all.where((m) => m.status == MatchStatus.open).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final m in matches.where((m) => m.isUnplayedByTimeout)) {
        _markAsUnplayedTimedOut(m.id);
      }
      return matches.where((m) => !m.isUnplayedByTimeout).toList();
    });
  }

  Future<void> _markAsUnplayedTimedOut(String matchId) async {
    try {
      await _remote.cancelMatchAsUnplayed(matchId);
    } catch (_) {}
  }

  @override
  Stream<List<Match>> getUserMatches(String userId) {
    return _remote.watchMatchesTable().map((all) {
      final mine = all.where((m) => m.participants.contains(userId)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return mine;
    });
  }

  @override
  Future<String> createMatch(Match match) async {
    final matchId = await _remote.insertMatch(match);
    try {
      if (match.isPrivate && match.invitedFriends.isNotEmpty) {
        final org = await _profiles.loadProfile(match.organizerId);
        final organizerName = org?.resolveDisplayName().isNotEmpty == true
            ? org!.resolveDisplayName()
            : 'Організатор';
        for (final uid in match.invitedFriends) {
          await NotificationService().sendMatchInvite(
            toUserId: uid,
            matchId: matchId,
            organizerName: organizerName,
          );
        }
      }
    } catch (_) {}
    return matchId;
  }

  @override
  Future<Match?> fetchMatch(String matchId) => _remote.fetchMatch(matchId);

  @override
  Future<void> saveMatch(Match match) => _remote.saveMatch(match);

  @override
  Stream<Match?> watchMatch(String matchId) {
    return _remote.watchMatchesTable().map((rows) {
      for (final m in rows) {
        if (m.id == matchId) return m;
      }
      return null;
    });
  }

  // Приєднатися до матчу
    // СТАРИЙ МЕТОД - ЗАКОМЕНТОВАНО
  // Future<bool> joinMatch(String matchId, String userId) async {
  //   try {
  //     final docRef = _firestore.collection('matches').doc(matchId);

  //     // Отримати поточний матч
  //     final doc = await docRef.get();
  //     if (!doc.exists) return false;

  //     final match = Match.fromFirestore(doc);

  //     // Перевірити чи користувач вже учасник
  //     if (match.participants.contains(userId)) {
  //       return false; // вже учасник
  //     }

  //     // Перевірити чи є вільні місця
  //     if (match.currentPlayers >= match.maxPlayers) {
  //       return false; // матч заповнений
  //     }

  //     // Додати користувача та оновити лічильник
  //     await docRef.update({
  //       'participants': FieldValue.arrayUnion([userId]),
  //       'currentPlayers': FieldValue.increment(1),
  //     });

  //     // Якщо після додавання матч заповнився — позначити 'full'
  //     if (match.currentPlayers + 1 >= match.maxPlayers) {
  //       await docRef.update({'status': 'full'});
  //     }

  //     return true;
  //   } catch (e) {
  //     print('Error joining match: $e');
  //     return false;
  //   }
  // }

  // НОВИЙ МЕТОД - ПОДАЧА ЗАЯВКИ
  @override
  Future<bool> joinMatch(String matchId, String userId) async {
    return applyForMatch(matchId, userId);
  }

  @override
  Future<bool> leaveMatch(String matchId, String userId) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) return false;
      if (!match.participants.contains(userId)) return true;

      final updatedParticipants = List<String>.from(match.participants)..remove(userId);
      final newCurrentPlayers =
          (match.currentPlayers - 1).clamp(0, match.maxPlayers).toInt();

      Team? teamA = match.teamA;
      Team? teamB = match.teamB;
      if (match.hasTeams) {
        final teamAPlayers =
            List<String>.from(match.teamA?.playerIds ?? const <String>[])..remove(userId);
        final teamBPlayers =
            List<String>.from(match.teamB?.playerIds ?? const <String>[])..remove(userId);
        final ratings = await _getPlayerRatings([...teamAPlayers, ...teamBPlayers]);
        teamA = Team(
          name: match.teamA?.name ?? 'Команда A',
          playerIds: teamAPlayers,
          averageRating: _calculateTeamAverageRating(teamAPlayers, ratings),
          playerRatings: match.teamA?.playerRatings ?? <String, double>{},
        );
        teamB = Team(
          name: match.teamB?.name ?? 'Команда B',
          playerIds: teamBPlayers,
          averageRating: _calculateTeamAverageRating(teamBPlayers, ratings),
          playerRatings: match.teamB?.playerRatings ?? <String, double>{},
        );
      }

      var status = match.status;
      if (match.status == MatchStatus.full && newCurrentPlayers < match.maxPlayers) {
        status = MatchStatus.open;
      }

      final next = match.copyWith(
        participants: updatedParticipants,
        currentPlayers: newCurrentPlayers,
        status: status,
        teamA: teamA,
        teamB: teamB,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);
      return true;
    } catch (e) {
      print('Error leaving match: $e');
      return false;
    }
  }

  @override
  Future<bool> applyForMatch(String matchId, String userId) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) return false;

      if (match.isUnplayedByTimeout) {
        await _markAsUnplayedTimedOut(matchId);
        return false;
      }

      if (match.isTeamMatch) {
        return false;
      }
      if (match.isPrivate && !match.invitedFriends.contains(userId)) {
        return false;
      }
      if (match.participants.contains(userId)) {
        return false;
      }
      if (match.pendingApplications.contains(userId)) {
        return false;
      }
      if (match.rejectedApplications.contains(userId)) {
        return false;
      }

      final pending = List<String>.from(match.pendingApplications)..add(userId);
      final next = match.copyWith(
        pendingApplications: pending,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);

      try {
        final m = await _remote.fetchMatch(matchId);
        if (m != null) {
          final applicant = await _profiles.loadProfile(userId);
          final applicantName = applicant?.resolveDisplayName().isNotEmpty == true
              ? applicant!.resolveDisplayName()
              : 'Гравець';
          await NotificationService().sendMatchApplicationSubmitted(
            toOrganizerId: m.organizerId,
            matchId: matchId,
            applicantName: applicantName,
          );
        }
      } catch (_) {}

      return true;
    } catch (e) {
      print('Error applying for match: $e');
      return false;
    }
  }

  @override
  Future<bool> acceptApplication(String matchId, String userId) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');

      if (match.isUnplayedByTimeout) {
        await _markAsUnplayedTimedOut(matchId);
        throw Exception('Match expired and marked as unplayed');
      }

      final currentUserId = AppAuthContext.userId;
      if (currentUserId == null || currentUserId != match.organizerId) {
        throw Exception('Only organizer can perform this action');
      }

      if (!match.pendingApplications.contains(userId)) {
        throw Exception('No pending application from this user');
      }

      if (match.currentPlayers >= match.maxPlayers) {
        throw Exception('Match is full');
      }

      final updatedPending = List<String>.from(match.pendingApplications)..remove(userId);
      final updatedParticipants = List<String>.from(match.participants)..add(userId);
      var status = match.status;
      if (match.currentPlayers + 1 >= match.maxPlayers) {
        status = MatchStatus.full;
      }

      var next = match.copyWith(
        pendingApplications: updatedPending,
        participants: updatedParticipants,
        currentPlayers: match.currentPlayers + 1,
        status: status,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);

      try {
        final org = await _profiles.loadProfile(next.organizerId);
        final organizerName = org?.resolveDisplayName().isNotEmpty == true
            ? org!.resolveDisplayName()
            : 'Організатор';
        await NotificationService().sendMatchApplicationAccepted(
          toUserId: userId,
          matchId: matchId,
          organizerName: organizerName,
        );
      } catch (_) {}

      try {
        final updated = await _remote.fetchMatch(matchId);
        if (updated != null && updated.hasTeams) {
          var teamAPlayers = List<String>.from(updated.teamA?.playerIds ?? const <String>[]);
          var teamBPlayers = List<String>.from(updated.teamB?.playerIds ?? const <String>[]);
          if (teamAPlayers.contains(userId) || teamBPlayers.contains(userId)) {
            return true;
          }
          final ratings = await _getPlayerRatings([
            ...teamAPlayers,
            ...teamBPlayers,
            userId,
          ]);
          final avgA = _calculateTeamAverageRating(teamAPlayers, ratings);
          final avgB = _calculateTeamAverageRating(teamBPlayers, ratings);
          final bool addToA;
          if (teamAPlayers.length < teamBPlayers.length) {
            addToA = true;
          } else if (teamBPlayers.length < teamAPlayers.length) {
            addToA = false;
          } else {
            addToA = avgA <= avgB;
          }
          if (addToA) {
            teamAPlayers.add(userId);
          } else {
            teamBPlayers.add(userId);
          }
          final newAvgA = _calculateTeamAverageRating(teamAPlayers, ratings);
          final newAvgB = _calculateTeamAverageRating(teamBPlayers, ratings);
          final withTeams = updated.copyWith(
            teamA: Team(
              name: updated.teamA?.name ?? 'Команда A',
              playerIds: teamAPlayers,
              averageRating: newAvgA,
              playerRatings: updated.teamA?.playerRatings ?? <String, double>{},
            ),
            teamB: Team(
              name: updated.teamB?.name ?? 'Команда B',
              playerIds: teamBPlayers,
              averageRating: newAvgB,
              playerRatings: updated.teamB?.playerRatings ?? <String, double>{},
            ),
            updatedAt: DateTime.now(),
          );
          await _remote.saveMatch(withTeams);
        }
      } catch (_) {}

      return true;
    } catch (e) {
      print('Error accepting application: $e');
      return false;
    }
  }

  @override
  Future<bool> rejectApplication(String matchId, String userId) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');

      final currentUserId = AppAuthContext.userId;
      if (currentUserId == null || currentUserId != match.organizerId) {
        throw Exception('Only organizer can perform this action');
      }

      if (!match.pendingApplications.contains(userId)) {
        throw Exception('No pending application from this user');
      }

      final updatedPending = List<String>.from(match.pendingApplications)..remove(userId);
      final updatedRejected = List<String>.from(match.rejectedApplications)..add(userId);

      final next = match.copyWith(
        pendingApplications: updatedPending,
        rejectedApplications: updatedRejected,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);

      try {
        final org = await _profiles.loadProfile(next.organizerId);
        final organizerName = org?.resolveDisplayName().isNotEmpty == true
            ? org!.resolveDisplayName()
            : 'Організатор';
        await NotificationService().sendMatchApplicationRejected(
          toUserId: userId,
          matchId: matchId,
          organizerName: organizerName,
        );
      } catch (_) {}

      return true;
    } catch (e) {
      print('Error rejecting application: $e');
      return false;
    }
  }

  @override
  Stream<List<String>> getMatchApplications(String matchId) {
    return _remote.watchMatchesTable().map((rows) {
      for (final m in rows) {
        if (m.id == matchId) return List<String>.from(m.pendingApplications);
      }
      return <String>[];
    });
  }
  @override
  Future<bool> autoBalanceTeams(String matchId) async {
    try {
      final initialMatch = await _remote.fetchMatch(matchId);
      if (initialMatch == null) throw Exception('Match not found');

      if (initialMatch.participants.length < 2) {
        throw Exception('Недостатньо гравців для формування команд (мінімум 2)');
      }
      if (initialMatch.hasTeams) {
        throw Exception('Команди вже сформовані');
      }

      final playerRatings = await _getPlayerRatings(initialMatch.participants);

      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');

      final currentUserId = AppAuthContext.userId;
      if (currentUserId == null || currentUserId != match.organizerId) {
        throw Exception('Only organizer can perform this action');
      }

      if (match.participants.length < 2) {
        throw Exception('Недостатньо гравців для формування команд (мінімум 2)');
      }
      if (match.hasTeams) {
        throw Exception('Команди вже сформовані');
      }

      final sortedPlayers = match.participants.toList()
        ..sort((a, b) => (playerRatings[b] ?? 0.0).compareTo(playerRatings[a] ?? 0.0));

      final teamAPlayers = <String>[];
      final teamBPlayers = <String>[];
      for (int i = 0; i < sortedPlayers.length; i++) {
        (i % 2 == 0 ? teamAPlayers : teamBPlayers).add(sortedPlayers[i]);
      }

      final names = MatchUtils.generateTeamNames(2);
      final nameA = names[0];
      final nameB = names[1];

      final teamA = Team(
        name: nameA,
        playerIds: teamAPlayers,
        averageRating: _calculateTeamAverageRating(teamAPlayers, playerRatings),
      );
      final teamB = Team(
        name: nameB,
        playerIds: teamBPlayers,
        averageRating: _calculateTeamAverageRating(teamBPlayers, playerRatings),
      );

      final next = match.copyWith(
        teamA: teamA,
        teamB: teamB,
        status: MatchStatus.full,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);
      return true;
    } catch (e) {
      print('Error auto-balancing teams: $e');
      return false;
    }
  }
  
  Future<Map<String, double>> _getPlayerRatings(List<String> playerIds) async {
    if (playerIds.isEmpty) return {};
    final map = <String, double>{for (final id in playerIds) id: 0.0};
    try {
      final rows = await _sb.from('profiles').select('id,rating').inFilter('id', playerIds);
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = m['id']?.toString();
        if (id == null) continue;
        map[id] = ((m['rating'] ?? 0.0) as num).toDouble();
      }
    } catch (_) {}
    return map;
  }
  
  // Розрахунок середнього рейтингу команди
  double _calculateTeamAverageRating(List<String> playerIds, Map<String, double> ratings) {
    if (playerIds.isEmpty) return 0.0;
    
    double totalRating = 0.0;
    int ratedPlayers = 0;
    
    for (String playerId in playerIds) {
      if (ratings.containsKey(playerId)) {
        totalRating += ratings[playerId]!;
        ratedPlayers++;
      }
    }
        return ratedPlayers > 0 ? totalRating / ratedPlayers : 0.0;
  }

  @override
  Future<bool> updateTeams(String matchId, List<String> teamAPlayers, List<String> teamBPlayers) async {
    try {
      final ratings = await _getPlayerRatings([...teamAPlayers, ...teamBPlayers]);

      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');

      final all = {...teamAPlayers, ...teamBPlayers}.toList();
      if (all.length != teamAPlayers.length + teamBPlayers.length) {
        throw Exception('Гравець не може бути у двох командах');
      }
      if (all.toSet().difference(match.participants.toSet()).isNotEmpty) {
        throw Exception('У складах є гравці, яких немає серед учасників матчу');
      }

      final existingNameA = match.teamA?.name ?? '';
      final existingNameB = match.teamB?.name ?? '';
      final generated = MatchUtils.generateTeamNames(2);
      final funA = generated[0];
      final funB = generated[1];
      final nameA = existingNameA.isNotEmpty ? existingNameA : funA;
      final nameB = existingNameB.isNotEmpty ? existingNameB : (funB == nameA ? MatchUtils.generateTeamNames(3)[2] : funB);

      final teamA = Team(
        name: nameA,
        playerIds: teamAPlayers,
        averageRating: _calculateTeamAverageRating(teamAPlayers, ratings),
      );
      final teamB = Team(
        name: nameB,
        playerIds: teamBPlayers,
        averageRating: _calculateTeamAverageRating(teamBPlayers, ratings),
      );

      final next = match.copyWith(
        teamA: teamA,
        teamB: teamB,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);
      return true;
    } catch (e) {
      print('Error updateTeams: $e');
      return false;
    }
  }

  @override
  Future<bool> updateTeamsFlexible(String matchId, List<List<String>> teams) async {
    try {
      final allPlayerIds = teams.expand((t) => t).toList();
      final ratings = await _getPlayerRatings(allPlayerIds);

      final generatedNames = MatchUtils.generateTeamNames(teams.length);
      final newTeams = <Team>[];
      for (var i = 0; i < teams.length; i++) {
        final ids = teams[i];
        newTeams.add(Team(
          name: generatedNames[i],
          playerIds: ids,
          averageRating: _calculateTeamAverageRating(ids, ratings),
        ));
      }

      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');

      Team? ta;
      Team? tb;
      if (newTeams.isNotEmpty) ta = newTeams[0];
      if (newTeams.length > 1) tb = newTeams[1];

      final next = match.copyWith(
        teams: newTeams,
        teamCount: teams.length,
        teamA: ta,
        teamB: tb,
        multiTeamStats: [],
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);

      await _remote.deleteAllFixtures(matchId);

      if (teams.length > 2) {
        final fixtures = <Map<String, dynamic>>[];
        for (var i = 0; i < teams.length; i++) {
          for (var j = i + 1; j < teams.length; j++) {
            fixtures.add({
              'teamAIndex': i,
              'teamBIndex': j,
              'teamAName': newTeams[i].name,
              'teamBName': newTeams[j].name,
              'scoreA': null,
              'scoreB': null,
              'status': 'pending',
            });
          }
        }
        await _remote.insertFixturesLegacy(matchId, fixtures);
        await _remote.patchDocumentOnly(matchId, {'currentGameIndex': 0});
      }

      return true;
    } catch (e) {
      print('Error updateTeamsFlexible: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFixtures(String matchId) =>
      _remote.fetchFixtures(matchId);

  @override
  Future<bool> finishGame(String matchId, String fixtureId, int scoreA, int scoreB) async {
    try {
      await _remote.updateFixtureScores(
        matchId: matchId,
        fixtureId: fixtureId,
        scoreA: scoreA,
        scoreB: scoreB,
        status: 'finished',
      );
      if (await _remote.allFixturesFinished(matchId)) {
        await _remote.markMatchFinished(matchId);
      }
      return true;
    } catch (e) {
      print('Error finishGame: $e');
      return false;
    }
  }

  @override
  Future<void> promptFinishGame(BuildContext context, String matchId, int fixtureIndex, String aName, String bName) async {
  final fixtures = await getFixtures(matchId);
  if (fixtureIndex < 0 || fixtureIndex >= fixtures.length) return;
  final f = fixtures[fixtureIndex];
  final ctrlA = TextEditingController();
  final ctrlB = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (ctx) {
    return AlertDialog(
      title: Text('Результат: $aName vs $bName'),
      content: Row(children: [
        Expanded(child: TextField(controller: ctrlA, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Голи $aName'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: ctrlB, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Голи $bName'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Зберегти')),
      ],
    );
  });
  if (ok == true) {
    final a = int.tryParse(ctrlA.text) ?? 0;
    final b = int.tryParse(ctrlB.text) ?? 0;
    await finishGame(matchId, f['id'] as String, a, b);
  }
}

  @override
  Future<void> ensureFixtures(String matchId) async {
    final m = await _remote.fetchMatch(matchId);
    if (m == null) return;
    if (m.teams.length <= 2) return;

    final existing = await _remote.fetchFixtures(matchId);
    if (existing.isNotEmpty) return;

    final fixtures = <Map<String, dynamic>>[];
    for (var i = 0; i < m.teams.length; i++) {
      for (var j = i + 1; j < m.teams.length; j++) {
        fixtures.add({
          'teamAIndex': i,
          'teamBIndex': j,
          'teamAName': m.teams[i].name,
          'teamBName': m.teams[j].name,
          'scoreA': null,
          'scoreB': null,
          'status': 'pending',
        });
      }
    }
    await _remote.insertFixturesLegacy(matchId, fixtures);
  }

  @override
  Future<bool> startMatch(String matchId) async {
    try {
      var match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');

      if (match.isUnplayedByTimeout) {
        await _markAsUnplayedTimedOut(matchId);
        throw Exception('Match expired and marked as unplayed');
      }

      final currentUserId = AppAuthContext.userId;
      if (currentUserId == null || currentUserId != match.organizerId) {
        throw Exception('Only organizer can perform this action');
      }

      if (!match.hasTeams) {
        final participants = List<String>.from(match.participants);
        if (participants.length < 2) {
          throw Exception('Потрібно щонайменше 2 учасники');
        }

        final half = (participants.length / 2).ceil();
        final teamAPlayers = participants.take(half).toList();
        final teamBPlayers = participants.skip(half).toList();

        final existingNameA = match.teamA?.name ?? '';
        final existingNameB = match.teamB?.name ?? '';
        final generated = MatchUtils.generateTeamNames(2);
        final funA = generated[0];
        final funB = generated[1];
        final nameA = existingNameA.isNotEmpty ? existingNameA : funA;
        final nameB = existingNameB.isNotEmpty ? existingNameB : funB;

        match = match.copyWith(
          teamA: Team(
            name: nameA,
            playerIds: teamAPlayers,
            averageRating: 0.0,
          ),
          teamB: Team(
            name: nameB,
            playerIds: teamBPlayers,
            averageRating: 0.0,
          ),
        );
      }

      if (match.isInProgress) {
        throw Exception('Матч вже почався');
      }

      if (match.isTeamMatch) {
        final rosterA = match.teamRosters['teamA'] ??
            match.teamA?.playerIds ??
            const <String>[];
        final rosterB = match.teamRosters['teamB'] ??
            match.teamB?.playerIds ??
            const <String>[];
        if (rosterA.isEmpty || rosterB.isEmpty) {
          throw Exception('Склади команд не заповнені');
        }
        final statusesA = match.teamRosterStatus['teamA'] ?? const {};
        final statusesB = match.teamRosterStatus['teamB'] ?? const {};
        final confirmedA = statusesA.values
            .where((status) => status == 'confirmed')
            .length;
        final confirmedB = statusesB.values
            .where((status) => status == 'confirmed')
            .length;
        if (confirmedA + confirmedB < 2) {
          throw Exception('Потрібно мінімум два підтверджені гравці');
        }
      } else if (match.participants.length < 2) {
        throw Exception('Потрібно щонайменше 2 учасники');
      }

      final now = DateTime.now();
      final next = match.copyWith(
        status: MatchStatus.inProgress,
        startedAt: now,
        updatedAt: now,
      );
      await _remote.saveMatch(next);
      return true;
    } catch (e) {
      print('Error starting match: $e');
      return false;
    }
  }
  
  Future<void> _applyProfileMatchFinish(
    String userId, {
    required int goalsDelta,
    required int winsDelta,
    required int lossesDelta,
    required int drawsDelta,
  }) async {
    final row = await _sb
        .from('profiles')
        .select('total_matches,matches,goals,wins,losses,draws')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return;
    await _sb.from('profiles').update({
      'total_matches': ((row['total_matches'] ?? 0) as num).toInt() + 1,
      'matches': ((row['matches'] ?? 0) as num).toInt() + 1,
      'goals': ((row['goals'] ?? 0) as num).toInt() + goalsDelta,
      'wins': ((row['wins'] ?? 0) as num).toInt() + winsDelta,
      'losses': ((row['losses'] ?? 0) as num).toInt() + lossesDelta,
      'draws': ((row['draws'] ?? 0) as num).toInt() + drawsDelta,
    }).eq('id', userId);
  }

  @override
  Future<bool> finishMatch(
    String matchId,
    MatchResult result,
    int teamAScore,
    int teamBScore, {
    Map<String, int> goalsByPlayer = const {},
  }) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');
      final currentUserId = AppAuthContext.userId;
      if (currentUserId == null || currentUserId != match.organizerId) {
        throw Exception('Only organizer can perform this action');
      }
      if (!match.isInProgress) {
        throw Exception('Матч не почався або вже завершений');
      }

      if (match.hasTeams && goalsByPlayer.isNotEmpty) {
        final assignments = match.playerTeamAssignments;
        int totalA = 0;
        int totalB = 0;
        goalsByPlayer.forEach((playerId, goals) {
          final teamKey = assignments[playerId];
          if (teamKey == 'teamA') {
            totalA += goals;
          } else if (teamKey == 'teamB') {
            totalB += goals;
          }
        });
        if (totalA > teamAScore || totalB > teamBScore) {
          throw Exception(
              'Сума голів заявлених гравців перевищує рахунок команди');
        }
      }

      final now = DateTime.now();
      final finished = match.copyWith(
        status: MatchStatus.finished,
        result: result,
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        goalsByPlayer: goalsByPlayer,
        finishedAt: now,
        updatedAt: now,
      );
      await _remote.saveMatch(finished);

      final m = finished;

      for (final uid in m.participants) {
        final playerGoals = goalsByPlayer[uid] ?? 0;
        var w = 0;
        var l = 0;
        var d = 0;
        if (m.hasTeams) {
          final a = m.teamA?.playerIds ?? const <String>[];
          final b = m.teamB?.playerIds ?? const <String>[];
          final inA = a.contains(uid);
          final inB = b.contains(uid);
          if (teamAScore > teamBScore) {
            if (inA) w = 1;
            if (inB) l = 1;
          } else if (teamBScore > teamAScore) {
            if (inB) w = 1;
            if (inA) l = 1;
          } else {
            if (inA || inB) d = 1;
          }
        }
        await _applyProfileMatchFinish(
          uid,
          goalsDelta: playerGoals,
          winsDelta: w,
          lossesDelta: l,
          drawsDelta: d,
        );
      }

      await _teams.applyStandingsAfterTeamMatch(
        m,
        teamAScore,
        teamBScore,
        goalsByPlayer,
      );
      try {
        final teamAName = m.teamA?.name ?? 'Команда A';
        final teamBName = m.teamB?.name ?? 'Команда B';
        for (final uid in m.participants) {
          await NotificationService().sendMatchFinished(
            toUserId: uid,
            matchId: matchId,
            teamAName: teamAName,
            teamBName: teamBName,
            teamAScore: teamAScore,
            teamBScore: teamBScore,
          );
        }
      } catch (_) {}
      return true;
    } catch (e) {
      print('Error finishing match: $e');
      return false;
    }
  }
  
  @override
  Stream<List<Match>> getMatchesForRating(String userId) {
    return _remote.watchMatchesTable().map((all) {
      final filtered = all
          .where((m) =>
              m.status == MatchStatus.finished &&
              m.participants.contains(userId) &&
              !m.playerRatings.any((r) => r.ratedBy == userId))
          .toList()
        ..sort((a, b) {
          final fa = a.finishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final fb = b.finishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return fb.compareTo(fa);
        });
      return filtered;
    });
  }

  @override
  Future<bool> cancelMatch(String matchId) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');

      final currentUserId = AppAuthContext.userId;
      if (currentUserId == null || currentUserId != match.organizerId) {
        throw Exception('Only organizer can perform this action');
      }

      if (match.isFinished || match.isCancelled) {
        throw Exception('Матч вже завершено або скасовано');
      }

      final next = match.copyWith(
        status: MatchStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);
      return true;
    } catch (e) {
      print('Error cancelling match: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteMatch(String matchId) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) throw Exception('Match not found');
      final currentUserId = AppAuthContext.userId;
      if (currentUserId == null || currentUserId != match.organizerId) {
        throw Exception('Only organizer can perform this action');
      }
      if (match.isInProgress || match.isFinished) {
        throw Exception('Неможливо видалити матч після старту');
      }

      await _remote.deleteMatchRow(matchId);

      return true;
    } catch (e) {
      print('Error deleting match: $e');
      return false;
    }
  }

  @override
  Future<bool> saveMultiTeamResults(
    String matchId,
    List<Map<String, int>> stats,
  ) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) return false;
      final next = match.copyWith(
        multiTeamStats: stats,
        updatedAt: DateTime.now(),
      );
      await _remote.saveMatch(next);
      return true;
    } catch (e) {
      print('Error saveMultiTeamResults: $e');
      return false;
    }
  }

  @override
  Future<void> setTeamRoster({
    required String matchId,
    required String teamKey,
    required AppTeam team,
    required List<String> playerIds,
  }) async {
    final match = await _remote.fetchMatch(matchId);
    if (match == null) {
      throw Exception('Матч не знайдено');
    }

    final rosterStatusRaw = match.teamRosterStatus.map(
      (k, v) => MapEntry(k, Map<String, String>.from(v)),
    );
    rosterStatusRaw[teamKey] = {
      for (final id in playerIds) id: 'pending',
    };

    final existingTeam = teamKey == 'teamA' ? match.teamA : match.teamB;

    final updated = match.copyWith(
      teamRosters: {...match.teamRosters, teamKey: playerIds},
      teamRosterStatus: rosterStatusRaw,
      teamAStatus: teamKey == 'teamA' ? 'pending' : match.teamAStatus,
      teamBStatus: teamKey == 'teamB' ? 'pending' : match.teamBStatus,
      teamAId: teamKey == 'teamA' ? team.id : match.teamAId,
      teamBId: teamKey == 'teamB' ? team.id : match.teamBId,
      teamA: teamKey == 'teamA'
          ? Team(
              name: team.name,
              playerIds: playerIds,
              averageRating: existingTeam?.averageRating ?? 0.0,
            )
          : match.teamA,
      teamB: teamKey == 'teamB'
          ? Team(
              name: team.name,
              playerIds: playerIds,
              averageRating: existingTeam?.averageRating ?? 0.0,
            )
          : match.teamB,
      updatedAt: DateTime.now(),
    );
    await _remote.saveMatch(updated);
  }

  @override
  Future<void> respondToRosterInvite({
    required String matchId,
    required String teamKey,
    required bool accept,
  }) async {
    final currentUserId = AppAuthContext.userId;
    if (currentUserId == null) {
      throw Exception('Потрібна авторизація');
    }

    final match = await _remote.fetchMatch(matchId);
    if (match == null) {
      throw Exception('Матч не знайдено');
    }

    final organizerId = match.organizerId;
    final rosterStatusRaw = match.teamRosterStatus.map(
      (k, v) => MapEntry(k, Map<String, String>.from(v)),
    );
    if (!rosterStatusRaw.containsKey(teamKey)) {
      throw Exception('Склад не знайдено');
    }
    final teamStatusMap = Map<String, String>.from(rosterStatusRaw[teamKey]!);
    if (!teamStatusMap.containsKey(currentUserId)) {
      throw Exception('Вас не заявлено на цей матч');
    }

    teamStatusMap[currentUserId] = accept ? 'confirmed' : 'declined';
    rosterStatusRaw[teamKey] = teamStatusMap;

    var participants = List<String>.from(match.participants);
    if (accept) {
      if (!participants.contains(currentUserId)) {
        participants.add(currentUserId);
      }
    } else {
      participants.remove(currentUserId);
    }

    final allConfirmed =
        teamStatusMap.values.every((status) => status == 'confirmed');
    final currentTeamConfirmed = allConfirmed;

    final currentTeamAStatus = match.teamAStatus ?? 'pending';
    final currentTeamBStatus = match.teamBStatus ?? 'pending';
    final newTeamAStatus = teamKey == 'teamA'
        ? (currentTeamConfirmed ? 'confirmed' : currentTeamAStatus)
        : currentTeamAStatus;
    final newTeamBStatus = teamKey == 'teamB'
        ? (currentTeamConfirmed ? 'confirmed' : currentTeamBStatus)
        : currentTeamBStatus;

    var notifyOrganizer = false;
    var readyTeamAName = 'Team A';
    var readyTeamBName = 'Team B';

    final alreadyNotified = match.teamsReadyNotified;
    final isTeamMatch = match.isTeamMatch;
    if (isTeamMatch &&
        !alreadyNotified &&
        newTeamAStatus == 'confirmed' &&
        newTeamBStatus == 'confirmed') {
      readyTeamAName = match.teamA?.name ?? 'Team A';
      readyTeamBName = match.teamB?.name ?? 'Team B';
      notifyOrganizer = organizerId.isNotEmpty;
    }

    final updated = match.copyWith(
      teamRosterStatus: rosterStatusRaw,
      participants: participants,
      teamAStatus: newTeamAStatus,
      teamBStatus: newTeamBStatus,
      teamsReadyNotified: (isTeamMatch &&
              !alreadyNotified &&
              newTeamAStatus == 'confirmed' &&
              newTeamBStatus == 'confirmed')
          ? true
          : match.teamsReadyNotified,
      teamsReadyNotifiedAt: (isTeamMatch &&
              !alreadyNotified &&
              newTeamAStatus == 'confirmed' &&
              newTeamBStatus == 'confirmed')
          ? DateTime.now()
          : match.teamsReadyNotifiedAt,
      updatedAt: DateTime.now(),
    );

    await _remote.saveMatch(updated);

    if (notifyOrganizer && organizerId.isNotEmpty) {
      await NotificationService().sendTeamMatchReadyNotification(
        toUserId: organizerId,
        matchId: matchId,
        teamAName: readyTeamAName,
        teamBName: readyTeamBName,
      );
    }
  }

  @override
  Future<void> updateCoverPhoto({
    required String matchId,
    required String photoUrl,
  }) async {
    try {
      final match = await _remote.fetchMatch(matchId);
      if (match == null) return;
      final now = DateTime.now();
      final next = match.copyWith(
        coverPhotoUrl: photoUrl,
        coverPhotoUpdatedAt: now,
        updatedAt: now,
      );
      await _remote.saveMatch(next);
    } catch (e) {
      print('Error updating match cover photo: $e');
      rethrow;
    }
  }
}