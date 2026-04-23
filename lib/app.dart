import 'package:flutter/material.dart';

import 'core/routes.dart';
import 'core/theme.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/shell/home_shell.dart';

class AgaramApp extends StatelessWidget {
  const AgaramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agaram',
      debugShowCheckedModeBanner: false,
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
