// Layer-3 integration test — drives the real Flutter widget tree on a
// physical device or Android emulator against the local Firebase
// emulator suite (Auth + Firestore).
//
// Run with:
//   firebase --project=agaram-test --config=firebase.json \
//     emulators:exec --only auth,firestore \
//     "flutter test integration_test/login_flow_test.dart \
//        --dart-define=USE_EMULATORS=true"
//
// The emulators:exec wrapper boots auth+firestore, runs the test, tears
// down — so a failed test can never leak state into prod.

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:agaram/main.dart' as app;

const testEmail = 'integration@club.test';
const testPassword = 'integration-pw-123';
const testName = 'Integration Member';

/// Seeds a single member using plain SDK calls. Relies on the emulator
/// running with the permissive rules in `firestore.rules.integration`
/// (see README) so the write is accepted without admin bootstrap.
Future<void> _seedMember() async {
  final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
  try {
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  } catch (_) {
    // Emulator already wired by a previous run.
  }
  String uid;
  try {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: testEmail,
      password: testPassword,
    );
    uid = cred.user!.uid;
  } on FirebaseAuthException catch (e) {
    if (e.code != 'email-already-in-use') rethrow;
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: testEmail,
      password: testPassword,
    );
    uid = cred.user!.uid;
  }
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'name': testName,
    'email': testEmail,
    'role': 'member',
    'position': 'member',
    'isPresident': false,
    'active': true,
    'stars': 0,
    'joinedAt': FieldValue.serverTimestamp(),
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp();
    await _seedMember();
  });

  setUp(() async {
    // Every test starts signed-out so app.main() lands on the login
    // screen regardless of what the previous test left behind.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  });

  /// Pumps frames until [finder] resolves or the deadline passes. Works
  /// around flaky continuous animations (splash progress bar, route
  /// transitions) that can defeat a naive pumpAndSettle.
  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
    Duration step = const Duration(milliseconds: 200),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) return;
    }
    // Dump a small slice of the current widget tree for diagnostics.
    final dump = tester.binding.rootElement
            ?.toStringDeep(minLevel: DiagnosticLevel.info) ??
        '<no root element>';
    throw TestFailure(
      'Timed out after $timeout waiting for: $finder\n'
      '-- widget tree snapshot (first 2KB) --\n'
      '${dump.substring(0, dump.length > 2048 ? 2048 : dump.length)}',
    );
  }

  testWidgets(
    'launch → login → home → sign out returns to login',
    (tester) async {
      app.main();
      await tester.pump(); // initial frame

      // 1. Login screen appears once splash resolves auth + 2.2s animation.
      await pumpUntilFound(tester, find.byKey(const Key('login-email')));

      final emailField = find.byKey(const Key('login-email'));
      final passwordField = find.byKey(const Key('login-password'));
      final submitButton = find.byKey(const Key('login-submit'));

      // 2. Fill credentials + submit.
      await tester.enterText(emailField, testEmail);
      await tester.enterText(passwordField, testPassword);
      await tester.tap(submitButton);

      // 3. Wait until the home screen shows the member's first name.
      final firstName = testName.split(' ').first;
      await pumpUntilFound(tester, find.textContaining(firstName));

      // 4. Navigate to the Profile tab (bottom-nav icon with tooltip)
      //    and sign out.
      final profileTab = find.byTooltip('Profile');
      expect(profileTab, findsOneWidget,
          reason: 'Bottom nav should expose a Profile item with tooltip.');
      await tester.tap(profileTab);
      await pumpUntilFound(tester, find.byKey(const Key('profile-signout')));
      await tester.tap(find.byKey(const Key('profile-signout')));

      // 5. Back on the login screen.
      await pumpUntilFound(tester, find.byKey(const Key('login-email')));
    },
  );

  testWidgets(
    'wrong password shows the unified error copy',
    (tester) async {
      app.main();
      await tester.pump();
      await pumpUntilFound(tester, find.byKey(const Key('login-email')));

      await tester.enterText(
          find.byKey(const Key('login-email')), testEmail);
      await tester.enterText(
          find.byKey(const Key('login-password')), 'definitely-wrong');
      await tester.tap(find.byKey(const Key('login-submit')));

      await pumpUntilFound(
          tester, find.textContaining('Email or password is incorrect'));
    },
  );

  testWidgets(
    'unknown email shows the same unified error copy (no enumeration)',
    (tester) async {
      app.main();
      await tester.pump();
      await pumpUntilFound(tester, find.byKey(const Key('login-email')));

      await tester.enterText(
          find.byKey(const Key('login-email')), 'no-such-user@club.test');
      await tester.enterText(
          find.byKey(const Key('login-password')), 'whatever-pw');
      await tester.tap(find.byKey(const Key('login-submit')));

      await pumpUntilFound(
          tester, find.textContaining('Email or password is incorrect'));
    },
  );
}
