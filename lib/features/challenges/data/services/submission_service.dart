import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/submission.dart';
import '../../../notifications/data/services/notification_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

class SubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Collection reference
  CollectionReference get _submissionsCollection => 
      _firestore.collection('submissions');

  // Get submissions for a challenge
  Stream<List<Submission>> getChallengeSubmissions(String challengeId) {
    // Simplified query to avoid composite index requirement
    return _submissionsCollection
        .where('challengeId', isEqualTo: challengeId)
        .snapshots()
        .map((snapshot) {
          print('Submissions loaded for challenge $challengeId: ${snapshot.docs.length} documents');
          return snapshot.docs
              .map((doc) {
                try {
                  final submission = Submission.fromFirestore(doc);
                  // Filter on client side to avoid index requirement
                  if (!submission.isActive) return null;
                  return submission;
                } catch (e) {
                  print('Error parsing submission ${doc.id}: $e');
                  return null;
                }
              })
              .where((submission) => submission != null)
              .cast<Submission>()
              .toList()
            ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt)); // Sort on client side
        })
        .handleError((error) {
          print('Error loading submissions for challenge $challengeId: $error');
          return <Submission>[];
        });
  }

  // Get user's submissions
  Stream<List<Submission>> getUserSubmissions(String userId) {
    // Simplified query to avoid composite index requirement
    return _submissionsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Submission.fromFirestore(doc))
            .where((submission) => submission.isActive) // Filter on client side
            .toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt))); // Sort on client side
  }

  // Submit video to challenge
  Future<String?> submitVideoToChallenge({
    required String challengeId,
    required String videoUrl,
    String? thumbnailUrl,
    required String title,
    String? description,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('Дані користувача не знайдено');
      }

      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Невідомий користувач';
      final userAvatar = userData['avatar'] ?? '';

      // Check if user already submitted to this challenge
      final existingSubmission = await _submissionsCollection
          .where('challengeId', isEqualTo: challengeId)
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existingSubmission.docs.isNotEmpty) {
        throw Exception('Ви вже подали відео до цього челенджу');
      }

      // Create submission
      final submission = Submission(
        id: '', // Will be set by Firestore
        challengeId: challengeId,
        userId: currentUser.uid,
        userName: userName,
        userAvatar: userAvatar,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: description,
        submittedAt: DateTime.now(),
        votes: {},
        averageRating: 0.0,
        totalVotes: 0,
      );

      // Add to Firestore
      final docRef = await _submissionsCollection.add(submission.toFirestore());

      // Update challenge with submission ID
      await _firestore.collection('challenges').doc(challengeId).update({
        'submissions': FieldValue.arrayUnion([docRef.id]),
      });

      // Award coins for submission
      await _firestore.collection('users').doc(currentUser.uid).update({
        'coins': FieldValue.increment(20), // +20 coins for challenge participation
      });

      // Record transaction
      await _firestore.collection('transactions').add({
        'userId': currentUser.uid,
        'type': 'challenge_submission',
        'amount': 20,
        'challengeId': challengeId,
        'submissionId': docRef.id,
        'timestamp': FieldValue.serverTimestamp(),
          'description': bilingual(
    'Участь в челенджі: $title',
    'Challenge entry: $title',
  ),
      });

      return docRef.id;
    } catch (e) {
      print('Error submitting video to challenge: $e');
      rethrow;
    }
  }

  // Vote for submission
  Future<bool> voteForSubmission(String submissionId, double rating) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Validate rating
      if (rating < 0.0 || rating > 5.0) {
        throw Exception('Оцінка має бути від 0.0 до 5.0');
      }

      // Get submission
      final submissionDoc = await _submissionsCollection.doc(submissionId).get();
      if (!submissionDoc.exists) {
        throw Exception('Відео не знайдено');
      }

      final submission = Submission.fromFirestore(submissionDoc);

      // Check if user is trying to vote for their own submission
      if (submission.userId == currentUser.uid) {
        throw Exception('Ви не можете голосувати за власне відео');
      }

      // Check if user already voted
      if (submission.hasUserVoted(currentUser.uid)) {
        throw Exception('Ви вже проголосували за це відео');
      }

      // Add vote
      final updatedSubmission = submission.addVote(currentUser.uid, rating);

      // Update in Firestore
      await _submissionsCollection.doc(submissionId).update({
        'votes': updatedSubmission.votes,
        'averageRating': updatedSubmission.averageRating,
        'totalVotes': updatedSubmission.totalVotes,
      });

      // Also update in challenge's submissionVotes
      await _firestore.collection('challenges').doc(submission.challengeId).update({
        'submissionVotes.${submissionId}.${currentUser.uid}': rating,
      });

      // Get voter's name for notification
      final voterDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final voterName = voterDoc.data()?['name'] ?? 'Анонім';

      // Send notification to video author
      await _notificationService.sendVideoVoteNotification(
        toUserId: submission.userId,
        videoTitle: 'Ваше відео', // Could be improved with actual video title
        voterName: voterName,
        rating: rating,
      );

      return true;
    } catch (e) {
      print('Error voting for submission: $e');
      rethrow;
    }
  }

  // Get specific submission
  Future<Submission?> getSubmission(String submissionId) async {
    try {
      final doc = await _submissionsCollection.doc(submissionId).get();
      if (doc.exists) {
        return Submission.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting submission: $e');
      return null;
    }
  }

  // Delete submission (only owner)
  Future<bool> deleteSubmission(String submissionId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final submissionDoc = await _submissionsCollection.doc(submissionId).get();
      if (!submissionDoc.exists) {
        throw Exception('Відео не знайдено');
      }

      final submission = Submission.fromFirestore(submissionDoc);
      if (submission.userId != currentUser.uid) {
        throw Exception('Ви можете видаляти тільки свої відео');
      }

      // Soft delete
      await _submissionsCollection.doc(submissionId).update({
        'isActive': false,
      });

      // Remove from challenge submissions
      await _firestore.collection('challenges').doc(submission.challengeId).update({
        'submissions': FieldValue.arrayRemove([submissionId]),
      });

      return true;
    } catch (e) {
      print('Error deleting submission: $e');
      rethrow;
    }
  }

  // Get submissions stats
  Future<Map<String, dynamic>> getSubmissionStats(String submissionId) async {
    try {
      final submission = await getSubmission(submissionId);
      if (submission == null) return {};

      return {
        'submissionId': submissionId,
        'averageRating': submission.averageRating,
        'totalVotes': submission.totalVotes,
        'ratingDistribution': _calculateRatingDistribution(submission.votes),
      };
    } catch (e) {
      print('Error getting submission stats: $e');
      return {};
    }
  }

  // Calculate rating distribution
  Map<String, int> _calculateRatingDistribution(Map<String, double> votes) {
    final distribution = {
      '5': 0, '4': 0, '3': 0, '2': 0, '1': 0, '0': 0,
    };

    for (final rating in votes.values) {
      final roundedRating = rating.round().toString();
      distribution[roundedRating] = (distribution[roundedRating] ?? 0) + 1;
    }

    return distribution;
  }

  // Award coins for voting (when user votes for all videos in challenge)
  Future<bool> awardVotingCoins(String challengeId, String userId) async {
    try {
      // Check if user voted for all submissions in challenge
      final challengeDoc = await _firestore.collection('challenges').doc(challengeId).get();
      if (!challengeDoc.exists) return false;

      final challengeData = challengeDoc.data()!;
      final submissionIds = List<String>.from(challengeData['submissions'] ?? []);
      final submissionVotes = challengeData['submissionVotes'] as Map<String, dynamic>? ?? {};

      // Count how many submissions user voted for
      int userVotesCount = 0;
      for (final submissionId in submissionIds) {
        if (submissionVotes[submissionId] != null && 
            submissionVotes[submissionId][userId] != null) {
          userVotesCount++;
        }
      }

      // If user voted for all submissions, award coins
      if (userVotesCount == submissionIds.length && submissionIds.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'coins': FieldValue.increment(5), // +5 coins for voting for all videos
        });

        // Record transaction
        await _firestore.collection('transactions').add({
          'userId': userId,
          'type': 'challenge_voting_complete',
          'amount': 5,
          'challengeId': challengeId,
          'timestamp': FieldValue.serverTimestamp(),
            'description': tr('il_e9f698ce68'),
        });

        return true;
      }

      return false;
    } catch (e) {
      print('Error awarding voting coins: $e');
      return false;
    }
  }

  // Rate a submission
  Future<void> rateSubmission(String submissionId, double rating, String userId) async {
    try {
      final submissionRef = _submissionsCollection.doc(submissionId);
      
      await _firestore.runTransaction((transaction) async {
        final submissionDoc = await transaction.get(submissionRef);
        if (!submissionDoc.exists) {
          throw Exception('Submission not found');
        }

        final data = submissionDoc.data() as Map<String, dynamic>;
        final votes = Map<String, dynamic>.from(data['votes'] ?? {});
        final previousVote = votes[userId] as double?;
        
        // Update vote
        votes[userId] = rating;
        
        // Recalculate average rating
        double totalRating = 0.0;
        int voteCount = 0;
        
        for (final vote in votes.values) {
          if (vote is num) {
            totalRating += vote.toDouble();
            voteCount++;
          }
        }
        
        final averageRating = voteCount > 0 ? totalRating / voteCount : 0.0;
        
        // Update submission
        transaction.update(submissionRef, {
          'votes': votes,
          'averageRating': averageRating,
          'totalVotes': voteCount,
        });
      });

      print('Rating updated for submission $submissionId: $rating');
    } catch (e) {
      print('Error rating submission: $e');
      throw e;
    }
  }
}
