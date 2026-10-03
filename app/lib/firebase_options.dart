// Firebase client configuration (public by design; access is governed by Firebase rules and the
// backend API). These are the same client keys used in v16; they belong to project therapylink69.
// Android entry requires com.therapylink.therapylink registered in the Firebase console.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => ios,
      TargetPlatform.windows => web,
      _ => throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform'),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyD07OCh78rUizyRRYOPukbpg_8x8UAjQTA',
    appId: '1:975276530329:web:c232b74b4e3e98f3863608',
    messagingSenderId: '975276530329',
    projectId: 'therapylink69',
    authDomain: 'therapylink69.firebaseapp.com',
    storageBucket: 'therapylink69.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAh71Q1hN_Ol9trmteBqo1jr0aOrYh-f1s',
    appId: '1:975276530329:android:a77c42db70a5181b863608',
    messagingSenderId: '975276530329',
    projectId: 'therapylink69',
    storageBucket: 'therapylink69.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyB73LEPg4H019YFq9TadgIBLlYhiX6H0Io',
    appId: '1:975276530329:ios:464f3e9630757742863608',
    messagingSenderId: '975276530329',
    projectId: 'therapylink69',
    storageBucket: 'therapylink69.firebasestorage.app',
    iosClientId:
        '975276530329-t2gac7jo6gne8qd3bvagehcm70jpfabb.apps.googleusercontent.com',
    iosBundleId: 'com.therapylink.therapylink',
  );
}

/// Web / desktop Google sign-in client ID (not needed on Android/iOS, which
/// use the platform SDK). Kept here so it stays next to the other Firebase config.
const webGoogleClientId =
    '975276530329-5u9pf583f3jun8orsrhgvm1op18hvh31.apps.googleusercontent.com';
