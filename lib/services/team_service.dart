import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_team.dart';
import '../models/team_invite.dart';
import '../models/team_match_request.dart';
import '../models/notification.dart';
import 'notification_service.dart';

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
    batch.update(inviteRef, {
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (accept) {
      final teamRef = _teamsCollection.doc(invite.teamId);
      batch.update(teamRef, {
        'memberIds': FieldValue.arrayUnion([invite.userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
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

    if (accept) {
      final matchRef = _firestore.collection('matches').doc(request.matchId);
      final teamDoc = await _teamsCollection.doc(request.teamId).get();
      final teamName = (teamDoc.data()?['name'] ?? 'Team') as String;
      batch.update(matchRef, {
        'teamBId': request.teamId,
        'teamBStatus': 'confirmed',
        'teamB': {
          'name': teamName,
          'playerIds': confirmedRoster,
          'averageRating': 0.0,
        },
        'teamRosters.teamB': confirmedRoster,
        'participants': FieldValue.arrayUnion(confirmedRoster),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final matchRef = _firestore.collection('matches').doc(request.matchId);
      batch.update(matchRef, {
        'teamBStatus': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<List<AppTeam>> searchTeams(String query, {int limit = 10}) async {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final snap = await _teamsCollection
        .where('nameLower', isGreaterThanOrEqualTo: lower)
        .where('nameLower', isLessThanOrEqualTo: '$lower\uf8ff')
        .limit(limit)
        .get();
    return snap.docs.map(AppTeam.fromDoc).toList();
  }

  Future<List<Map<String, dynamic>>> searchPlayers(String query,
      {int limit = 10}) async {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final snap = await _firestore
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: lower)
        .where('displayNameLower', isLessThanOrEqualTo: '$lower\uf8ff')
        .limit(limit)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'displayName': data['displayName'] ?? data['name'] ?? 'Гравець',
        'avatarUrl': data['avatarUrl'] ?? data['avatar'] ?? '',
      };
    }).toList();
  }
}

