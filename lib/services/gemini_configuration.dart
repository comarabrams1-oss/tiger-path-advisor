import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class GeminiConfiguration {
  static const model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );
  static Future<FirebaseApp>? _initializing;

  static Future<FirebaseApp> initialize() {
    return _initializing ??= _initialize().catchError((Object error) {
      _initializing = null;
      throw error;
    });
  }

  static Future<FirebaseApp> _initialize() async {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const appleAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const macAppId = String.fromEnvironment('FIREBASE_MACOS_APP_ID');
    const webSiteKey = String.fromEnvironment('FIREBASE_RECAPTCHA_SITE_KEY');
    final appId = kIsWeb
        ? webAppId
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => androidAppId,
            TargetPlatform.iOS => appleAppId,
            TargetPlatform.macOS => macAppId,
            _ => '',
          };
    if (apiKey.isEmpty ||
        projectId.isEmpty ||
        senderId.isEmpty ||
        appId.isEmpty ||
        (kIsWeb && webSiteKey.isEmpty)) {
      throw const GeminiNotConfigured();
    }
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: apiKey,
              appId: appId,
              messagingSenderId: senderId,
              projectId: projectId,
              authDomain: kIsWeb ? '$projectId.firebaseapp.com' : null,
              iosBundleId: 'com.example.tigerPath',
            ),
          )
        : Firebase.app();
    await FirebaseAppCheck.instanceFor(app: app).activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      providerWeb: kIsWeb ? ReCaptchaV3Provider(webSiteKey) : null,
    );
    return app;
  }
}

class GeminiNotConfigured implements Exception {
  const GeminiNotConfigured();
}
