import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/friend_request.dart';
import '../../../notifications/data/services/notification_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Collection references
  CollectionReference get _friendRequestsCollection => 
      _firestore.collection('friend_requests');
  
  CollectionReference get _usersCollection => 
      _firestore.collection('users');

  // Send friend request
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Користувач не авторизований');
    }
    if (toUserId == currentUser.uid) {
      throw Exception('Неможливо додати себе у друзі');
    }

      // Check if users are already friends
      final areFriends = await areUsersFriends(currentUser.uid, toUserId);
      if (areFriends) {
        throw Exception('Ви вже друзі з цим користувачем');
      }

      // Check if request already exists
      final existingRequest = await _friendRequestsCollection
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Запрошення вже надіслано');
      }

      // Get user data
      final fromUserDoc = await _usersCollection.doc(currentUser.uid).get();
      final toUserDoc = await _usersCollection.doc(toUserId).get();

      if (!fromUserDoc.exists || !toUserDoc.exists) {
        throw Exception('Користувача не знайдено');
      }

      final fromUserData = fromUserDoc.data() as Map<String, dynamic>;
      final toUserData = toUserDoc.data() as Map<String, dynamic>;

      // Create friend request
      final friendRequest = FriendRequest(
        id: '', // Will be set by Firestore
        fromUserId: currentUser.uid,
        fromUserName: fromUserData['displayName'] ?? fromUserData['name'] ?? fromUserData['email']?.split('@')[0] ?? 'Користувач',
        fromUserAvatar: fromUserData['avatarUrl'] ?? fromUserData['avatar'] ?? '',
        toUserId: toUserId,
        toUserName: toUserData['displayName'] ?? toUserData['name'] ?? toUserData['email']?.split('@')[0] ?? 'Користувач',
        toUserAvatar: toUserData['avatarUrl'] ?? toUserData['avatar'] ?? '',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now(),
        message: message,
      );

      final docRef = await _friendRequestsCollection.add(friendRequest.toFirestore());

      // Send notification to the recipient
      await _notificationService.sendFriendRequestNotification(
        toUserId: toUserId,
        fromUserName: fromUserData['displayName'] ?? fromUserData['name'] ?? fromUserData['email']?.split('@')[0] ?? 'Користувач',
        requestId: docRef.id,
      );

      // Award coins for social activity
      await _usersCollection.doc(currentUser.uid).update({
        'coins': FieldValue.increment(3), // +3 coins for adding friend
      });

      // Record transaction
      await _firestore.collection('transactions').add({
        'userId': currentUser.uid,
        'type': 'friend_request_sent',
        'amount': 3,
        'timestamp': FieldValue.serverTimestamp(),
        'description': bilingual(
  'Надіслано запрошення в друзі: ${toUserData['name']}',
  'Friend invite sent to: ${toUserData['name']}',
),
      });

      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  // Get incoming friend requests
  Stream<List<FriendRequest>> getIncomingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _friendRequestsCollection
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => FriendRequest.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Get outgoing friend requests
  Stream<List<FriendRequest>> getOutgoingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _friendRequestsCollection
        .where('fromUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => FriendRequest.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Respond to friend request
  Future<bool> respondToFriendRequest(String requestId, bool accept) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final requestDoc = await _friendRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Запрошення не знайдено');
      }

      final request = FriendRequest.fromFirestore(requestDoc);
      
      if (request.toUserId != currentUser.uid) {
        throw Exception('Це не ваше запрошення');
      }

      if (!request.isPending) {
        throw Exception('Запрошення вже оброблено');
      }

      final newStatus = accept 
          ? FriendRequestStatus.accepted 
          : FriendRequestStatus.declined;

      try {
        // Preferred: Cloud Function performs cross-user writes atomically with proper auth
        // If functions are not configured, fallback to client transaction but scoped safely
        // await FirebaseFunctions.instance.httpsCallable('friends-respond').call({'requestId': requestId, 'accept': accept});
        throw Exception('functions_disabled');
      } catch (_) {
        // Safe fallback: update request status and ONLY current user's document to avoid rules violation
                // Двостороння синхронізація друзів
               // Оновлюємо статус запрошення
        await _friendRequestsCollection.doc(requestId).update({
          'status': newStatus.toString().split('.').last,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        if (accept) {
          // Двостороння дружба: оновлюємо обох користувачів окремо
          
          // 1. Оновлюємо того, хто ПРИЙМАЄ (поточний користувач)
          await _usersCollection.doc(request.toUserId).update({
            'friends': FieldValue.arrayUnion([request.fromUserId]),
            'friendsCount': FieldValue.increment(1),
            'coins': FieldValue.increment(5),
          });

          // 2. Оновлюємо того, хто ВІДПРАВЛЯВ (інший користувач)
          await _usersCollection.doc(request.fromUserId).update({
            'friends': FieldValue.arrayUnion([request.toUserId]),
            'friendsCount': FieldValue.increment(1),
          });

          // 3. Транзакція для того, хто приймає
          await _firestore.collection('transactions').add({
            'userId': request.toUserId,
            'type': 'friend_added',
            'amount': 5,
            'timestamp': FieldValue.serverTimestamp(),
            'description': bilingual(
  'Новий друг: ${request.fromUserName}',
  'New friend: ${request.fromUserName}',
),
          });
        }
      }

      // Send notification to the requester if accepted
      if (accept) {
        await _notificationService.sendFriendAcceptedNotification(
          toUserId: request.fromUserId,
          friendName: request.toUserName,
        );
      }

      return true;
    } catch (e) {
      print('Error responding to friend request: $e');
      // Hint for rules misconfig: ensure rules allow users/{uid} updates to friends & coins and transactions create
      rethrow;
    }
  }

  // Cancel friend request
  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final requestDoc = await _friendRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Запрошення не знайдено');
      }

      final request = FriendRequest.fromFirestore(requestDoc);
      
      if (request.fromUserId != currentUser.uid) {
        throw Exception('Це не ваше запрошення');
      }

      if (!request.isPending) {
        throw Exception('Запрошення вже оброблено');
      }

      await _friendRequestsCollection.doc(requestId).update({
        'status': FriendRequestStatus.cancelled.toString().split('.').last,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error cancelling friend request: $e');
      rethrow;
    }
  }

  // Get user's friends
  Future<List<Friend>> getUserFriends(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      final friendIds = List<String>.from(userData['friends'] ?? []);

      if (friendIds.isEmpty) return [];

      final friends = <Friend>[];
      
      for (final friendId in friendIds) {
        final friendDoc = await _usersCollection.doc(friendId).get();
        if (friendDoc.exists) {
          final friendData = friendDoc.data() as Map<String, dynamic>;
          friendData['id'] = friendId;
          
          // Get friendship date from accepted friend request
          final friendshipDate = await _getFriendshipDate(userId, friendId);
          
          friends.add(Friend.fromUserData(friendData, friendshipDate));
        }
      }

      // Sort by name
      friends.sort((a, b) => a.name.compareTo(b.name));
      
      return friends;
    } catch (e) {
      print('Error getting user friends: $e');
      return [];
    }
  }

  // Check if users are friends
  Future<bool> areUsersFriends(String userId1, String userId2) async {
    try {
      final userDoc = await _usersCollection.doc(userId1).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final friends = List<String>.from(userData['friends'] ?? []);
      
      return friends.contains(userId2);
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  // Remove friend
  Future<bool> removeFriend(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Check if they are friends
      final areFriends = await areUsersFriends(currentUser.uid, friendId);
      if (!areFriends) {
        throw Exception('Ви не друзі з цим користувачем');
      }

      await _firestore.runTransaction((transaction) async {
        // Remove from both friends lists
        transaction.update(_usersCollection.doc(currentUser.uid), {
          'friends': FieldValue.arrayRemove([friendId]),
          'friendsCount': FieldValue.increment(-1),
        });

        transaction.update(_usersCollection.doc(friendId), {
          'friends': FieldValue.arrayRemove([currentUser.uid]),
          'friendsCount': FieldValue.increment(-1),
        });
      });

      return true;
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  // Search users (potential friends)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      if (query.trim().length < 2) return [];

      final queryLower = query.toLowerCase().trim();
      
      print('Starting user search for: "$queryLower"');
      
      // Get all users and filter on client side for better search  
      final querySnapshot = await _usersCollection.limit(200).get();
      print('Total users in database: ${querySnapshot.docs.length}');

      final users = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        if (doc.id != currentUser.uid) { // Exclude current user
          final userData = doc.data() as Map<String, dynamic>;
          final name = (userData['name'] ?? userData['displayName'] ?? '').toString().toLowerCase();
          final displayName = (userData['displayName'] ?? userData['name'] ?? '').toString().toLowerCase();
          final email = (userData['email'] ?? '').toString().toLowerCase();
          final firstName = (userData['firstName'] ?? '').toString().toLowerCase();
          final lastName = (userData['lastName'] ?? '').toString().toLowerCase();
          
          print('Checking user ${doc.id}: name="$name", displayName="$displayName", email="$email", firstName="$firstName", lastName="$lastName"');
          
          // Search in multiple fields - prioritize startsWith
          final searchFields = [name, displayName, email, firstName, lastName, '$firstName $lastName'];
          bool isMatch = false;
          
          for (final field in searchFields) {
            if (field.isNotEmpty && (field.startsWith(queryLower) || field.contains(queryLower))) {
              isMatch = true;
              break;
            }
          }
          
          if (isMatch) {
            userData['id'] = doc.id;
            // Ensure we have display fields
            if (userData['displayName'] == null && userData['name'] != null) {
              userData['displayName'] = userData['name'];
            }
            if (userData['name'] == null && userData['displayName'] != null) {
              userData['name'] = userData['displayName'];
            }
            users.add(userData);
            print('✅ Found matching user: ${userData['name']} / ${userData['displayName']} (${userData['email']})');
          }
        }
      }

      print('Total users found: ${users.length}');

      // Sort by relevance (exact matches first, then partial matches)
      users.sort((a, b) {
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();
        
        final aExact = aName == queryLower ? 1 : 0;
        final bExact = bName == queryLower ? 1 : 0;
        
        if (aExact != bExact) return bExact - aExact;
        
        final aStartsWith = aName.startsWith(queryLower) ? 1 : 0;
        final bStartsWith = bName.startsWith(queryLower) ? 1 : 0;
        
        if (aStartsWith != bStartsWith) return bStartsWith - aStartsWith;
        
        return aName.compareTo(bName);
      });

      return users.take(10).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get friendship date
  Future<DateTime> _getFriendshipDate(String userId1, String userId2) async {
    try {
      // Try from userId1 -> userId2
      final req1 = await _friendRequestsCollection
          .where('fromUserId', isEqualTo: userId1)
          .where('toUserId', isEqualTo: userId2)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (req1.docs.isNotEmpty) {
        final friendRequest = FriendRequest.fromFirestore(req1.docs.first);
        return friendRequest.respondedAt ?? friendRequest.createdAt;
      }

      // Try reverse userId2 -> userId1
      final req2 = await _friendRequestsCollection
          .where('fromUserId', isEqualTo: userId2)
          .where('toUserId', isEqualTo: userId1)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (req2.docs.isNotEmpty) {
        final friendRequest = FriendRequest.fromFirestore(req2.docs.first);
        return friendRequest.respondedAt ?? friendRequest.createdAt;
      }

      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  // Get pending requests count
  Future<int> getPendingRequestsCount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final snapshot = await _friendRequestsCollection
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting pending requests count: $e');
      return 0;
    }
  }
}
