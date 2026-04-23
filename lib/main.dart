import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth_service.dart';
import 'core/fcm_service.dart';

/// Compile-time flag — set via `--dart-define=USE_EMULATORS=true` for
/// integration tests. Never on in a release build.
const bool _useEmulators =
    bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp();

  if (_useEmulators) {
    // Android emulator reaches the host machine at 10.0.2.2; everything
    // else (iOS sim, desktop, web, physical device with adb reverse) uses
    // localhost.
    final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    // GoogleFonts fetches from fonts.gstatic.com on first render; emulator
    // networking can be flaky during CI and the unhandled exception would
    // fail every widget test. Swallow only the font-load failure so the
    // app keeps rendering with the system fallback.
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      if (msg.contains('Failed to load font')) return;
      prior?.call(details);
    };
    if (kDebugMode) debugPrint('[agaram] Using Firebase emulators at $host');
  }

  // FCM requests a system notification permission on Android 13+, which
  // pops a modal dialog that blocks integration-test driving. Skip the
  // push setup when running against emulators — tests don't need pushes,
  // and release builds still run it normally.
  if (!_useEmulators) {
    try {
      await FcmService.initOnStart();
    } catch (e) {
      debugPrint('FCM init failed (non-fatal): $e');
    }
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const AgaramApp(),
    ),
  );
}
