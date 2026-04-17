import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/register_request.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl();

  @override
  Future<Result<AuthUser>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } catch (_) {}
    }
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        return const Result.failure(
          Failure.unexpected('missing-user-after-sign-in'),
        );
      }
      return Result.success(AuthUser(uid: uid));
    } on FirebaseAuthException catch (e) {
      return Result.failure(
        Failure.auth(code: e.code, message: e.message),
      );
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }

  @override
  Future<Result<AuthUser>> registerNewUser(RegisterRequest r) async {
    UserCredential userCredential;
    try {
      userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: r.email.trim(),
        password: r.password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      return Result.failure(
        Failure.auth(code: e.code, message: e.message),
      );
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }

    final uid = userCredential.user?.uid;
    if (uid == null) {
      return const Result.failure(
        Failure.unexpected('missing-user-after-register'),
      );
    }

    String? avatarUrl;
    final bytes = r.avatarBytes;
    if (bytes != null && bytes.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('avatars')
            .child(uid)
            .child('avatar.jpg');
        await ref.putData(Uint8List.fromList(bytes));
        avatarUrl = await ref.getDownloadURL();
      } catch (_) {
        // Non-fatal — profile still created without avatar
      }
    }

    try {
      final now = DateTime.now();
      final premiumExpiry = now.add(const Duration(days: 14));
      final fullName = '${r.name.trim()} ${r.surname.trim()}'.trim();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'authorName': fullName,
        'displayName': fullName,
        'name': r.name.trim(),
        'surname': r.surname.trim(),
        'email': r.email.trim(),
        'phone': r.phone.trim(),
        'city': r.city.trim(),
        'age': r.age,
        'position': r.position,
        'experience': r.experience,
        'avatarUrl': avatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 3.0,
        'matchRating': 3.0,
        'videoRating': 3.0,
        'totalMatches': 0,
        'totalVideos': 0,
        'ratingHistory': [],
        'lastRatingUpdate': FieldValue.serverTimestamp(),
        'coins': 160,
        'matches': 0,
        'goals': 0,
        'assists': 0,
        'subscription': 'champions_league',
        'subscriptionExpiry': Timestamp.fromDate(premiumExpiry),
        'subscriptionActive': true,
        'challengesCreated': 0,
        'maxChallengesPerMonth': 999,
      });
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }

    return Result.success(AuthUser(uid: uid));
  }
}
