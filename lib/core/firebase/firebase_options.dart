import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase Web options have not been configured for this project.',
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => throw UnsupportedError(
        'Firebase iOS options have not been configured yet.',
      ),
      TargetPlatform.macOS => throw UnsupportedError(
        'Firebase macOS options have not been configured yet.',
      ),
      TargetPlatform.windows => throw UnsupportedError(
        'Firebase Windows options have not been configured yet.',
      ),
      TargetPlatform.linux => throw UnsupportedError(
        'Firebase Linux options have not been configured yet.',
      ),
      TargetPlatform.fuchsia => throw UnsupportedError(
        'Firebase Fuchsia options have not been configured yet.',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVjwKrUFUtXBII9t7KBpT5h1aE1B44PGU',
    appId: '1:993519322530:android:ba15e241624f46a4abdefb',
    messagingSenderId: '993519322530',
    projectId: 'mini-order-app-umt',
    storageBucket: 'mini-order-app-umt.firebasestorage.app',
  );
}
