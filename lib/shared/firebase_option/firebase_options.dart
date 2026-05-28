import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions();

  /// Prod
  static const FirebaseOptions androidProd = FirebaseOptions(
    apiKey: "AIzaSyC9GQ_IAasLPrOhl4fflGjGGP3OPfAxcLQ",
    appId: "1:903789590606:android:f04c643b383b358673ab1f",
    messagingSenderId: "903789590606",
    projectId: "erp-project-ba24f",
  );

  static const FirebaseOptions iosProd = FirebaseOptions(
    apiKey: "AIzaSyAU3aKulNmdc1VOHCjcunR0exme3pEed38",
    appId: "1:981068595271:ios:3e6c6ac75062e96c33f162",
    messagingSenderId: "981068595271",
    projectId: "e-customer-dev",
  );

  FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidProd;
      case TargetPlatform.iOS:
        return iosProd;
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
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }
}
