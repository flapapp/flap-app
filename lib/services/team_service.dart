import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../features/teams/data/models/app_team.dart';
import '../features/teams/data/models/team_invite.dart';
import '../features/teams/data/models/team_join_request.dart';
import '../features/teams/data/models/team_match_request.dart';
import '../features/notifications/data/models/notification.dart';
import 'notification_service.dart';
import '../utils/i18n.dart';

class TeamService {
  TeamService._();
  static final TeamService _instance = TeamService._();
  factory TeamService() => _instance;

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _teamsCollection =>
    _firestore.collection('teams');
  CollectionReference<Map<String, dynamic>> get _invitesCollection =>
      _firestore.collection('teamInvites');
  CollectionReference<Map<String, dynamic>> get _matchRequestsCollection =>
      _firestore.collection('teamMatchRequests');
  CollectionReference<Map<String, dynamic>> get _joinRequestsCollection =>
      _firestore.collection('teamJoinRequests');
  CollectionReference<Map<String, dynamic>> get _activityFeedCollection =>
      _firestore.collection('activityFeed');

  Stream<List<AppTeam>> watchUserTeams(String userId) {
    return _teamsCollection
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs.map(AppTeam.fromDoc).toList());
  }

  Future<List<AppTeam>> fetchUserTeams(String userId) async {
    final snap = await _teamsCollection
        .where('memberIds', arrayContains: userId)
        .get();
    return snap.docs.map(AppTeam.fromDoc).toList();
  }

  Future<AppTeam?> getTeam(String teamId) async {
    final doc = await _teamsCollection.doc(teamId).get();
    if (!doc.exists) return null;
    return AppTeam.fromDoc(doc);
  }

  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic = true,
    Uint8List? logoBytes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Користувач не авторизований');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final now = DateTime.now();
    final teamRef = _teamsCollection.doc();

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final existingTeams =
          List<String>.from(userSnap.data()?['teamIds'] ?? const []);
      if (existingTeams.length >= 3) {
        throw Exception('Максимум 3 команди на гравця');
      }

      transaction.set(teamRef, {
        'name': name,
        'nameLower': name.toLowerCase(),
        'description': description,
        'captainId': user.uid,
        'viceCaptainIds': <String>[],
        'memberIds': [user.uid],
        'isPublic': isPublic,
        'logoUrl': null,
        'city': city,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'playerGoals': <String, int>{},
        'recentMatches': <Map<String, dynamic>>[],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      transaction.set(
        userRef,
        {
          'teamIds': FieldValue.arrayUnion([teamRef.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    if (logoBytes != null) {
      final logoUrl = await _uploadTeamLogo(teamRef.id, logoBytes);
      await teamRef.update({'logoUrl': logoUrl});
    }

    return teamRef.id;
  }

  Future<String> _uploadTeamLogo(String teamId, Uint8List bytes) async {
    final ref = _storage.ref('team_logos/$teamId-${DateTime.now().millisecondsSinceEpoch}.png');
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return task.ref.getDownloadURL();
  }

  Future<void> setViceCaptainMembership({
    required String teamId,
    required String memberId,
    required bool addAsVice,
  }) async {
    await _teamsCollection.doc(teamId).update({
      'viceCaptainIds': addAsVice
          ? FieldValue.arrayUnion([memberId])
          : FieldValue.arrayRemove([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTeamInfo({
    required String teamId,
    String? name,
    String? description,
    String? city,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) {
      updates['name'] = name;
      updates['nameLower'] = name.toLowerCase();
    }
    if (description != null) updates['description'] = description;
    if (city != null) updates['city'] = city;
    if (isPublic != null) updates['isPublic'] = isPublic;
    await _teamsCollection.doc(teamId).update(updates);
  }

  Future<void> invitePlayers({
    required String teamId,
    required String teamName,
    required List<String> userIds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final batch = _firestore.batch();
    for (final targetId in userIds) {
      final doc = _invitesCollection.doc();
      batch.set(doc, TeamInvite(
        id: doc.id,
        teamId: teamId,
        teamName: teamName,
        userId: targetId,
        invitedBy: user.uid,
        status: TeamInviteStatus.pending,
        createdAt: DateTime.now(),
      ).toFirestore());
    }
    await batch.commit();
    for (final uid in userIds) {
      await NotificationService().sendNotification(
        AppNotification.teamInvite(
          userId: uid,
          teamId: teamId,
          teamName: teamName,
        ),
      );
    }
  }

  Stream<List<TeamInvite>> watchInvites(String userId) {
    return _invitesCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(TeamInvite.fromDoc).toList());
  }

  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  }) async {
    final userTeams = await fetchUserTeams(invite.userId);
    if (accept && userTeams.length >= 3) {
      throw Exception('Максимум 3 команди на гравця');
    }
    final batch = _firestore.batch();
    final inviteRef = _invitesCollection.doc(invite.id);
    final teamRef = _teamsCollection.doc(invite.teamId);
    final userRef = _firestore.collection('users').doc(invite.userId);

    batch.update(inviteRef, {
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (accept) {
      batch.update(teamRef, {
        'memberIds': FieldValue.arrayUnion([invite.userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        userRef,
        {
          'teamIds': FieldValue.arrayUnion([invite.teamId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    if (accept) {
      final userDoc = await _firestore.collection('users').doc(invite.userId).get();
      final userName = (userDoc.data()?['displayName'] ??
              userDoc.data()?['name'] ??
              userDoc.data()?['authorName'] ??
              'Player')
          .toString();
      await _publishTeamMovementNews(
        action: 'joined_team',
        teamId: invite.teamId,
        teamName: invite.teamName,
        userId: invite.userId,
        userName: userName,
      );
    }
  }

  Stream<List<TeamJoinRequest>> watchJoinRequests(String teamId) {
    return _joinRequestsCollection
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(TeamJoinRequest.fromDoc).toList());
  }

  Stream<TeamJoinRequest?> watchMyJoinRequest(
      String teamId, String userId) {
    return _joinRequestsCollection
        .where('teamId', isEqualTo: teamId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : TeamJoinRequest.fromDoc(snap.docs.first));
  }

  Future<void> requestToJoinTeam({
    required String teamId,
    required String teamName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Потрібна авторизація');
    }
    final teamDoc = await _teamsCollection.doc(teamId).get();
    if (!teamDoc.exists) {
      throw Exception('Команду не знайдено');
    }
    final memberIds =
        List<String>.from(teamDoc.data()?['memberIds'] ?? const []);
    if (memberIds.contains(user.uid)) {
      throw Exception('Ви вже у цій команді');
    }

    final pendingExisting = await _joinRequestsCollection
        .where('teamId', isEqualTo: teamId)
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pendingExisting.docs.isNotEmpty) {
      throw Exception('Запит вже надіслано');
    }

    final requesterName = user.displayName ??
        user.photoURL ??
        (user.email?.split('@').first ?? 'Player');
    final reqRef = await _joinRequestsCollection.add({
      'teamId': teamId,
      'teamName': teamName,
      'userId': user.uid,
      'userName': requesterName,
      'status': 'pending',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    try {
      final data = teamDoc.data() ?? {};
      final captainId = (data['captainId'] ?? '').toString();
      final viceIds =
          List<String>.from(data['viceCaptainIds'] ?? const <String>[]);
      final recipients = {
        if (captainId.isNotEmpty) captainId,
        ...viceIds.where((id) => id.isNotEmpty),
      }..remove(user.uid);
      if (recipients.isNotEmpty) {
        final notifier = NotificationService();
        final resolvedTeamName =
            teamName.isNotEmpty ? teamName : (data['name'] ?? 'Team').toString();
        for (final target in recipients) {
          await notifier.sendTeamJoinRequestNotification(
            toUserId: target,
            teamId: teamId,
            teamName: resolvedTeamName,
            requesterName: requesterName,
            requestId: reqRef.id,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> respondToJoinRequest({
    required TeamJoinRequest request,
    required bool accept,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final teamDoc = await _teamsCollection.doc(request.teamId).get();
    if (!teamDoc.exists) {
      throw Exception('Команду не знайдено');
    }
    final data = teamDoc.data() ?? {};
    final captainId = (data['captainId'] ?? '').toString();
    final viceIds =
        List<String>.from(data['viceCaptainIds'] ?? const <String>[]);
    final canManage =
        captainId == currentUser.uid || viceIds.contains(currentUser.uid);
    if (!canManage) {
      throw Exception('Недостатньо прав');
    }

    final batch = _firestore.batch();
    final reqRef = _joinRequestsCollection.doc(request.id);
    batch.update(reqRef, {
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (accept) {
      batch.update(_teamsCollection.doc(request.teamId), {
        'memberIds': FieldValue.arrayUnion([request.userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        _firestore.collection('users').doc(request.userId),
        {
          'teamIds': FieldValue.arrayUnion([request.teamId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    if (accept) {
      await _publishTeamMovementNews(
        action: 'joined_team',
        teamId: request.teamId,
        teamName: request.teamName,
        userId: request.userId,
        userName: request.userName,
      );
    }
  }

  Stream<List<TeamMatchRequest>> watchMatchRequests(String teamId) {
    return _matchRequestsCollection
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(TeamMatchRequest.fromDoc).toList());
  }

  Future<void> sendMatchRequest({
    required String teamId,
    required String opponentTeamId,
    required String opponentName,
    required String matchId,
    List<String> proposedRoster = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final docRef = await _matchRequestsCollection.add(TeamMatchRequest(
      id: '',
      matchId: matchId,
      teamId: teamId,
      opponentTeamId: opponentTeamId,
      opponentName: opponentName,
      createdBy: user.uid,
      status: TeamMatchRequestStatus.pending,
      createdAt: DateTime.now(),
      proposedRoster: proposedRoster,
    ).toFirestore());
    try {
      final teamDoc = await _teamsCollection.doc(teamId).get();
      if (teamDoc.exists) {
        final data = teamDoc.data() ?? {};
        final captainId = data['captainId'] as String?;
        final viceCaptainIds = List<String>.from(data['viceCaptainIds'] ?? const []);
        final recipients = {
          if (captainId != null) captainId,
          ...viceCaptainIds,
        }.whereType<String>().toSet();

        for (final recipient in recipients) {
          await NotificationService().sendNotification(
            AppNotification.teamMatchRequest(
              userId: recipient,
              opponentTeamName: opponentName,
              matchId: matchId,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> respondToMatchRequest({
    required TeamMatchRequest request,
    required bool accept,
    List<String> confirmedRoster = const [],
  }) async {
    final batch = _firestore.batch();
    final reqRef = _matchRequestsCollection.doc(request.id);
    batch.update(reqRef, {
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    String? assignedTeamKey;

    if (accept) {
      final matchRef = _firestore.collection('matches').doc(request.matchId);
      final matchSnap = await matchRef.get();
      final matchData = matchSnap.data() ?? {};
      assignedTeamKey =
          (matchData['teamAId'] == request.teamId) ? 'teamA' : 'teamB';
      final teamDoc = await _teamsCollection.doc(request.teamId).get();
      final teamName = (teamDoc.data()?['name'] ?? 'Team') as String;
      final rosterStatus = {
        for (final uid in confirmedRoster) uid: 'pending',
      };
      final statusField =
          assignedTeamKey == 'teamA' ? 'teamAStatus' : 'teamBStatus';
      final teamField = assignedTeamKey!;
      final updateData = <String, dynamic>{
        'participants': FieldValue.arrayUnion(confirmedRoster),
        'updatedAt': FieldValue.serverTimestamp(),
        'teamRosters.$teamField': confirmedRoster,
        'teamRosterStatus.$teamField': rosterStatus,
        statusField: 'pending',
      };
      updateData[teamField] = {
        'name': teamName,
        'playerIds': confirmedRoster,
        'averageRating': 0.0,
      };
      if (teamField == 'teamA') {
        updateData['teamAId'] = request.teamId;
      } else {
        updateData['teamBId'] = request.teamId;
      }
      batch.update(matchRef, updateData);
    } else {
      final matchRef = _firestore.collection('matches').doc(request.matchId);
      final matchSnap = await matchRef.get();
      final matchData = matchSnap.data() ?? {};
      final isHost = (matchData['teamAId'] == request.teamId);
      batch.update(matchRef, {
        isHost ? 'teamAStatus' : 'teamBStatus': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    if (accept && assignedTeamKey != null && confirmedRoster.isNotEmpty) {
      final teamDoc = await _teamsCollection.doc(request.teamId).get();
      final teamName = (teamDoc.data()?['name'] ?? 'Team') as String;
      final notif = NotificationService();
      for (final playerId in confirmedRoster) {
        await notif.sendTeamRosterInvite(
          toUserId: playerId,
          matchId: request.matchId,
          teamName: teamName,
          teamKey: assignedTeamKey!,
        );
      }
    }
  }

  Future<List<AppTeam>> searchTeams(String query, {int limit = 10}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    final snap = await _teamsCollection.limit(200).get();
    final matches = <AppTeam>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString();
      final city = (data['city'] ?? '').toString();
      if (name.toLowerCase().contains(trimmed) ||
          city.toLowerCase().contains(trimmed)) {
        matches.add(AppTeam.fromDoc(doc));
      }
    }
    matches.sort((a, b) => a.name.compareTo(b.name));
    return matches.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> searchPlayers(String query,
      {int limit = 10}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final lower = trimmed.toLowerCase();
    final snap = await _firestore.collection('users').limit(200).get();
    final results = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final displayNameRaw =
          (data['displayName'] ?? data['name'] ?? data['authorName'] ?? '')
              .toString()
              .trim();
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      final nickName = (data['nickname'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();

      final searchFields = <String>[
        displayNameRaw.toLowerCase(),
        firstName.toLowerCase(),
        lastName.toLowerCase(),
        '$firstName $lastName'.trim().toLowerCase(),
        nickName.toLowerCase(),
        email.toLowerCase(),
      ];

      final keywords = (data['searchKeywords'] is List)
          ? (data['searchKeywords'] as List)
              .whereType<String>()
              .map((e) => e.toLowerCase())
              .toList()
          : const <String>[];
      searchFields.addAll(keywords);

      bool matches = false;
      for (final field in searchFields) {
        if (field.isEmpty) continue;
        if (field.startsWith(lower) || field.contains(lower)) {
          matches = true;
          break;
        }
      }

      if (matches) {
        results.add({
          'id': doc.id,
          'displayName':
              displayNameRaw.isNotEmpty ? displayNameRaw : I18n.inline('Гравець', 'Player'),
          'avatarUrl': (data['avatarUrl'] ?? data['avatar'] ?? '').toString(),
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
        });
      }
    }

    results.sort((a, b) {
      String normalize(dynamic value) =>
          (value ?? '').toString().toLowerCase().trim();
      final aName = normalize(a['displayName']);
      final bName = normalize(b['displayName']);

      final aExact = aName == lower ? 1 : 0;
      final bExact = bName == lower ? 1 : 0;
      if (aExact != bExact) return bExact - aExact;

      final aStartsWith = aName.startsWith(lower) ? 1 : 0;
      final bStartsWith = bName.startsWith(lower) ? 1 : 0;
      if (aStartsWith != bStartsWith) return bStartsWith - aStartsWith;

      return aName.compareTo(bName);
    });

    return results.take(limit).toList();
  }

  Future<void> leaveTeam({
  required String teamId,
  required String userId,
}) async {
  final teamRef = _teamsCollection.doc(teamId);
  final userRef = _firestore.collection('users').doc(userId);

  // Потрібно для стрічки новин після транзакції
  String teamNameForFeed = 'Team';
  final teamSnapForFeed = await teamRef.get();
  if (teamSnapForFeed.exists) {
    teamNameForFeed = (teamSnapForFeed.data()?['name'] ?? 'Team').toString();
  }

  await _firestore.runTransaction((tx) async {
    final teamSnap = await tx.get(teamRef);
    if (!teamSnap.exists) {
      throw Exception(I18n.inline('Команду не знайдено', 'Team not found'));
    }

    final data = teamSnap.data() ?? {};
    final memberIds = List<String>.from(data['memberIds'] ?? const <String>[]);
    final viceIds = List<String>.from(data['viceCaptainIds'] ?? const <String>[]);
    final captainId = (data['captainId'] ?? '').toString();

    if (!memberIds.contains(userId)) {
      throw Exception(
        I18n.inline(
          'Ви не є учасником цієї команди',
          'You are not a member of this team',
        ),
      );
    }

    // Якщо капітан останній у команді — не даємо "осиротити" команду
    if (captainId == userId && memberIds.length == 1) {
      throw Exception(
        I18n.inline(
          'Ви останній учасник. Видаліть команду або передайте капітанство.',
          'You are the last member. Delete the team or transfer captain role.',
        ),
      );
    }

    final updatedMembers = List<String>.from(memberIds)..remove(userId);
    final updatedVice = List<String>.from(viceIds)..remove(userId);

    final updates = <String, dynamic>{
      'memberIds': updatedMembers,
      'viceCaptainIds': updatedVice,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Якщо виходить капітан — передаємо капітанство іншому учаснику
    if (captainId == userId) {
      String? nextCaptain;
      if (updatedVice.isNotEmpty) {
        nextCaptain = updatedVice.first;
      } else if (updatedMembers.isNotEmpty) {
        nextCaptain = updatedMembers.first;
      }

      if (nextCaptain == null || nextCaptain.isEmpty) {
        throw Exception(
          I18n.inline(
            'Не вдалося визначити нового капітана',
            'Failed to determine next captain',
          ),
        );
      }

      updates['captainId'] = nextCaptain;
      // Новий капітан не має одночасно бути віце
      updates['viceCaptainIds'] = List<String>.from(updatedVice)..remove(nextCaptain);
    }

    tx.update(teamRef, updates);

    tx.set(
      userRef,
      {
        'teamIds': FieldValue.arrayRemove([teamId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  });

  // Після успішного виходу — новина в activity feed
  final userDoc = await userRef.get();
  final userName = (userDoc.data()?['displayName'] ??
          userDoc.data()?['name'] ??
          userDoc.data()?['authorName'] ??
          'Player')
      .toString();

  await _publishTeamMovementNews(
    action: 'left_team',
    teamId: teamId,
    teamName: teamNameForFeed,
    userId: userId,
    userName: userName,
  );
}
  Future<void> _publishTeamMovementNews({
    required String action, // joined_team | left_team
    required String teamId,
    required String teamName,
    required String userId,
    required String userName,
  }) async {
    try {
      await _activityFeedCollection.add({
        'type': action,
        'teamId': teamId,
        'teamName': teamName,
        'userId': userId,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // best-effort feed
    }
  }
}

