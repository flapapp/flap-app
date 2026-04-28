import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
        return _ios;
      default:
        return null;
    }
  }

  static FirebaseOptions? get _android {
    const appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');
    const senderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    if (appId.isEmpty || senderId.isEmpty || projectId.isEmpty || apiKey.isEmpty) {
      return null;
    }
    return const FirebaseOptions(
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      apiKey: apiKey,
    );
  }

  static FirebaseOptions? get _ios {
    const appId = String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');
    const senderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: '');
    if (appId.isEmpty ||
        senderId.isEmpty ||
        projectId.isEmpty ||
        apiKey.isEmpty ||
        iosBundleId.isEmpty) {
      return null;
    }
    return const FirebaseOptions(
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      apiKey: apiKey,
      iosBundleId: iosBundleId,
    );
  }
}
