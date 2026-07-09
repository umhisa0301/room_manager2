// File generated manually from android/app/google-services.json for Android-only
// Phase 1 Firebase setup. Re-run `flutterfire configure` when Firebase CLI auth is available.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS in Phase 1.',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAz1U4C9AxZowRoQJ4PfTLkJzEAopXvBdo',
    appId: '1:556014838107:android:8259c16016fead19e83a7e',
    messagingSenderId: '556014838107',
    projectId: 'roommanager-production',
    storageBucket: 'roommanager-production.firebasestorage.app',
  );
}
