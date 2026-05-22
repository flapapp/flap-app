import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase config for `flap-app-prod`.
///
/// Defaults are read from the committed native config files:
/// - Android: [android/app/google-services.json]
/// - iOS: [ios/Runner/GoogleService-Info.plist]
///
/// Override at build time with `--dart-define=FIREBASE_*=...` when needed.
class DefaultFirebaseOptions {
  static const _prodProjectId = 'flap-app-prod';
  static const _prodMessagingSenderId = '1094049674871';
  static const _prodStorageBucket = 'flap-app-prod.firebasestorage.app';

  // Android — google-services.json (package com.flap.flap_app)
  static const _prodAndroidAppId = '1:1094049674871:android:fdb8c7f0ce8d1dc1dfb872';
  static const _prodAndroidApiKey = 'AIzaSyDAGkC1PdHjXb3xOhy3dYGZ4N1eafaFqbE';

  // iOS — GoogleService-Info.plist (bundle com.flap.flapapp)
  static const _prodIosAppId = '1:1094049674871:ios:7c1e509996e3fe25dfb872';
  static const _prodIosApiKey = 'AIzaSyCLMY2C9agHJqODn7oTRw9hcu1ciehEvZA';
  static const _prodIosBundleId = 'com.flap.flapapp';

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

  static FirebaseOptions get _android {
    const appId = String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: _prodAndroidAppId,
    );
    const senderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _prodMessagingSenderId,
    );
    const projectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _prodProjectId,
    );
    const apiKey = String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: _prodAndroidApiKey,
    );
    const storageBucket = String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _prodStorageBucket,
    );
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );
  }

  static FirebaseOptions get _ios {
    const appId = String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: _prodIosAppId,
    );
    const senderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _prodMessagingSenderId,
    );
    const projectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _prodProjectId,
    );
    const apiKey = String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: _prodIosApiKey,
    );
    const iosBundleId = String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: _prodIosBundleId,
    );
    const storageBucket = String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _prodStorageBucket,
    );
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      iosBundleId: iosBundleId,
      storageBucket: storageBucket,
    );
  }
}
