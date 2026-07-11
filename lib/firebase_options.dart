// Generated from Firebase Console config for project: writesense-2
// Run `flutterfire configure` after adding Android/iOS apps to update this file.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.linux:
        // Linux desktop uses web SDK config
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run flutterfire configure after registering your iOS/macOS/Windows app.',
        );
    }
  }

  // Web app config (writesense-2)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyDxMIOZzJghPBvkDVwcjZGbfcEGV2yUBwc',
    appId:             '1:965759605050:web:dd8d64275fbaa4d3e8d803',
    messagingSenderId: '965759605050',
    projectId:         'writesense-2',
    authDomain:        'writesense-2.firebaseapp.com',
    storageBucket:     'writesense-2.firebasestorage.app',
    measurementId:     'G-LQS49ZQPWX',
  );

  // Android config
  // Package name: writesence.app
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyATz05whDzDjWAh6X-0kaiz2ta_wqBvfLg',
    appId:             '1:965759605050:android:5f8a3d9a032528cce8d803',
    messagingSenderId: '965759605050',
    projectId:         'writesense-2',
    storageBucket:     'writesense-2.firebasestorage.app',
  );
}
