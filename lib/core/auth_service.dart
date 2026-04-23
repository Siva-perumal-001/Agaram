import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'fcm_service.dart';
import 'reminder_service.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<User?>? _authSub;
  bool _disposed = false;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthService() {
    _authSub = _auth.authStateChanges().listen(_handleAuthChange);
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> _handleAuthChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      final lastUid = _currentUser?.uid;
      await _userSub?.cancel();
      _userSub = null;
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      try {
        await FcmService.unsubscribeAll(uid: lastUid);
      } catch (_) {
        // topic unsubscribe is best-effort.
      }
      unawaited(ReminderService.cancelAll());
      _safeNotify();
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
      // Refresh local event reminders for the freshly signed-in member.
      unawaited(ReminderService.syncUpcoming());
      _watchActiveFlag(firebaseUser.uid);
    } catch (e) {
      await _auth.signOut();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      rethrow;
    } finally {
      _safeNotify();
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

  /// Streams the signed-in user's doc so a mid-session deactivation
  /// (admin flips `active` to false, or role/position changes) kicks the
  /// user out immediately instead of waiting for the next cold start.
  void _watchActiveFlag(String uid) {
    _userSub?.cancel();
    _userSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) {
        // Profile deleted by president — sign out.
        await _auth.signOut();
        return;
      }
      final user = AppUser.fromFirestore(snap);
      if (!user.active) {
        await _auth.signOut();
        return;
      }
      // Keep FCM topic membership in sync with the current role so a
      // demoted admin stops receiving admins_only pushes without having
      // to sign out and back in.
      final wasAdmin = _currentUser?.isAdmin ?? false;
      if (wasAdmin != user.isAdmin) {
        try {
          if (user.isAdmin) {
            await FcmService.subscribeForAdmin(uid);
          } else {
            await FcmService
                .unsubscribeFromAdminTopic(); // just the admins_only topic
          }
        } catch (_) {
          // topic reconciliation is best-effort.
        }
      }
      _currentUser = user;
      _safeNotify();
    });
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
      // Reset flow must not reveal whether an address is registered — a
      // 'user-not-found' response would enumerate club membership. Surface
      // only the two network-style errors; everything else (including
      // missing account) returns the neutral copy the UI already shows
      // alongside the success state.
      if (e.code == 'invalid-email') {
        throw AuthException('That email address looks invalid.');
      }
      if (e.code == 'network-request-failed') {
        throw AuthException('Network error. Check your internet connection.');
      }
      if (kDebugMode) {
        debugPrint('[auth] suppressed reset error: ${e.code}');
      }
      // Silent success — caller shows "If that email is registered, we sent a link."
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
