import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_secrets.dart';

class MemberCreationResult {
  final String uid;
  final String email;
  final String generatedPassword;
  const MemberCreationResult({
    required this.uid,
    required this.email,
    required this.generatedPassword,
  });
}

class MembersService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static String _generatePassword({int length = 10}) {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(length, (_) => alphabet[rand.nextInt(alphabet.length)])
        .join();
  }

  /// Creates a new Firebase Auth user + Firestore profile without signing the
  /// current admin out. Uses a temporary secondary [FirebaseApp] instance.
  static Future<MemberCreationResult> createMember({
    required String name,
    required String email,
    String? phone,
    required String role,
  }) async {
    final password = _generatePassword();
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

      await _users.doc(uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone?.trim(),
        'role': role,
        'isPresident': false,
        'stars': 0,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await auth.signOut();
      return MemberCreationResult(
        uid: uid,
        email: email.trim(),
        generatedPassword: password,
      );
    } finally {
      await secondary.delete();
    }
  }

  static Future<void> setRole(String uid, {required String role}) {
    return _users.doc(uid).update({'role': role});
  }
}
