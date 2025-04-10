// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyANXjVUfUz09wv17ndFoRcWc2nvEVttDaQ',
    appId: '1:352872723000:android:a26b1fbce269e3fbcfeccd',
    messagingSenderId: '352872723000',
    projectId: 'quickride-3fa23',
    storageBucket: 'quickride-3fa23.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCUZ2w2D-bj_ODNfjsD58Mrobtb87iomZM',
    appId: '1:352872723000:ios:aca311587d6640decfeccd',
    messagingSenderId: '352872723000',
    projectId: 'quickride-3fa23',
    storageBucket: 'quickride-3fa23.firebasestorage.app',
    androidClientId: '352872723000-d49mq07n7jv8ngh4d3hl1r7io84ckkop.apps.googleusercontent.com',
    iosClientId: '352872723000-8vns44hf8u3183gp9hnknbsp6g110h7b.apps.googleusercontent.com',
    iosBundleId: 'com.lori.quickride',
  );

}