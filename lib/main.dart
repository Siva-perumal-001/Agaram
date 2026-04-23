import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth_service.dart';
import 'core/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp();
  try {
    await FcmService.initOnStart();
  } catch (e) {
    debugPrint('FCM init failed (non-fatal): $e');
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const AgaramApp(),
    ),
  );
}
