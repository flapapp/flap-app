import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getCurrentSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const {};

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      return Map<String, dynamic>.from(data['settings'] ?? const <String, dynamic>{});
    } catch (_) {
      return const {};
    }
  }

  Future<bool> isNotificationsEnabled() async {
    final settings = await getCurrentSettings();
    return settings['notificationsEnabled'] ?? true;
  }

  Future<bool> isAutoplayEnabled() async {
    final settings = await getCurrentSettings();
    return settings['autoplayVideos'] ?? true;
  }
}
