import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'app_secrets.dart';

class MemberCreationResult {
  final String uid;
  final String email;
  final String password;
  const MemberCreationResult({
    required this.uid,
    required this.email,
    required this.password,
  });
}

class MembersService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static String suggestPassword({int length = 10}) {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(length, (_) => alphabet[rand.nextInt(alphabet.length)])
        .join();
  }

  /// Creates a new Firebase Auth user + Firestore profile without signing the
  /// current admin out. Uses a temporary secondary [FirebaseApp] instance so
  /// the primary session is untouched.
  static Future<MemberCreationResult> createMember({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String role,
    String? position,
  }) async {
    final secondaryName =
        'agaram-secondary-${DateTime.now().millisecondsSinceEpoch}';

    final secondary = await Firebase.initializeApp(
      name: secondaryName,
      options: const FirebaseOptions(
        apiKey: AppSecrets.firebaseApiKey,
        appId: AppSecrets.firebaseAppId,
        messagingSenderId: AppSecrets.firebaseMessagingSenderId,
        projectId: AppSecrets.firebaseProjectId,
        storageBucket: AppSecrets.firebaseStorageBucket,
      ),
    );

    try {
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      // If the Firestore write fails the Auth account must be rolled back,
      // otherwise a retry hits 'email-already-in-use' and the member is
      // stuck with an Auth record that has no profile.
      try {
        await _users.doc(uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone?.trim(),
          'role': role,
          'isPresident': position == 'president',
          'position': position,
          'active': true,
          'stars': 0,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        try {
          await cred.user!.delete();
        } catch (_) {
          // If cleanup fails the admin retries manually via Firebase Console.
        }
        rethrow;
      }

      await auth.signOut();
      return MemberCreationResult(
        uid: uid,
        email: email.trim(),
        password: password,
      );
    } finally {
      await secondary.delete();
    }
  }

  static Future<void> setRole(String uid, {required String role}) {
    return _users.doc(uid).update({'role': role});
  }

  static Future<void> setPosition(String uid, {String? position}) {
    return _users.doc(uid).update({
      'position': position,
      'isPresident': position == 'president',
    });
  }

  /// Mark the member deactivated + disable their Firebase Auth account so new
  /// sign-in attempts fail with `user-disabled`. Reversible via [reactivate].
  ///
  /// Order matters: toggle Identity Toolkit first so a mid-operation failure
  /// leaves the admin UI consistent with actual sign-in behaviour. If
  /// Identity Toolkit succeeds and Firestore then fails, the user is blocked
  /// at Auth (safe) — the admin simply retries and the Firestore flag
  /// catches up.
  static Future<void> deactivate(String uid) async {
    await _setAuthAccountDisabled(uid, disabled: true);
    await _users.doc(uid).update({'active': false});
  }

  static Future<void> reactivate(String uid) async {
    await _setAuthAccountDisabled(uid, disabled: false);
    await _users.doc(uid).update({'active': true});
  }

  /// Removes a member's Firestore profile. Spark has no admin-SDK client
  /// delete, so we disable the Auth account instead — sign-in fails with
  /// `user-disabled`, matching the UX of a real delete. Only the president
  /// can call this (firestore.rules enforces the same).
  ///
  /// Always route deletes through here — never drop the doc from Firebase
  /// Console, or the orphaned Auth account will keep hitting the
  /// "not set up yet" branch in AuthService.
  static Future<void> deleteMember(String uid) async {
    await _setAuthAccountDisabled(uid, disabled: true);
    await _users.doc(uid).delete();
  }

  static Future<void> _setAuthAccountDisabled(
    String uid, {
    required bool disabled,
  }) async {
    final raw =
        await rootBundle.loadString(AppConfig.fcmServiceAccountAsset);
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['_placeholder'] == true) {
      // Without real credentials we can still flag `active` in Firestore;
      // sign-in is blocked by AuthService._loadUser regardless.
      return;
    }
    final creds = ServiceAccountCredentials.fromJson(decoded);
    final client = await clientViaServiceAccount(creds, const [
      'https://www.googleapis.com/auth/identitytoolkit',
    ]);
    try {
      final url =
          'https://identitytoolkit.googleapis.com/v1/projects/${AppSecrets.firebaseProjectId}/accounts:update';
      final response = await client.post(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'localId': uid, 'disableUser': disabled}),
      );
      if (response.statusCode != 200) {
        throw Exception('Identity Toolkit update failed: ${response.body}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error toggling account state: $e');
    } finally {
      client.close();
    }
  }
}
