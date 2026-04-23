import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'fcm_service.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthService() {
    _auth.authStateChanges().listen(_handleAuthChange);
  }

  Future<void> _handleAuthChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      final lastUid = _currentUser?.uid;
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      try {
        await FcmService.unsubscribeAll(uid: lastUid);
      } catch (_) {
        // topic unsubscribe is best-effort.
      }
      notifyListeners();
      return;
    }
    try {
      await _loadUser(firebaseUser.uid);
      _status = AuthStatus.authenticated;
      if (_currentUser?.isAdmin ?? false) {
        await FcmService.subscribeForAdmin(firebaseUser.uid);
      } else {
        await FcmService.subscribeForMember(firebaseUser.uid);
      }
    } catch (e) {
      await _auth.signOut();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw AuthException(
        'Your account exists but is not set up yet. Contact your club admin.',
      );
    }
    final user = AppUser.fromFirestore(doc);
    if (!user.active) {
      throw AuthException(
        'This account has been deactivated by your admin. Contact them if this is a mistake.',
      );
    }
    _currentUser = user;
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your admin.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a few minutes.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
