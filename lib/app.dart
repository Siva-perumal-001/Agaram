import 'package:flutter/material.dart';

import 'core/nav.dart';
import 'core/reminder_service.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/shell/home_shell.dart';

class AgaramApp extends StatefulWidget {
  const AgaramApp({super.key});

  @override
  State<AgaramApp> createState() => _AgaramAppState();
}

class _AgaramAppState extends State<AgaramApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync local reminders after the app comes back to the foreground
      // in case the event list changed while we were away.
      ReminderService.syncUpcoming();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agaram',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNav.navigatorKey,
      theme: AgaramTheme.light(),
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (_) => const SplashScreen(),
        Routes.login: (_) => const LoginScreen(),
        Routes.forgotPassword: (_) => const ForgotPasswordScreen(),
        Routes.home: (_) => const HomeShell(),
      },
    );
  }
}
