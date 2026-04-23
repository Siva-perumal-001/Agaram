import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'app_config.dart';
import 'event_service.dart';

class AttendanceQrPayload {
  final String eventId;
  final String secret;
  const AttendanceQrPayload({required this.eventId, required this.secret});

  String encode() => jsonEncode({'t': 'agaram-att', 'e': eventId, 's': secret});

  static AttendanceQrPayload? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['t'] != 'agaram-att') return null;
      return AttendanceQrPayload(
        eventId: map['e'] as String,
        secret: map['s'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class AttendanceException implements Exception {
  final String message;
  AttendanceException(this.message);
  @override
  String toString() => message;
}

class AttendanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> attendance(String eventId) =>
      EventService.events.doc(eventId).collection('attendance');

  static Future<String> rotateQrSecret(String eventId) async {
    final secret = const Uuid().v4();
    await EventService.events.doc(eventId).update({
      'qrSecret': secret,
      'qrSecretRotatedAt': FieldValue.serverTimestamp(),
    });
    return secret;
  }

  static Future<void> checkInWithQr({
    required AttendanceQrPayload payload,
    required String memberUid,
    required String memberName,
  }) async {
    await _db.runTransaction((tx) async {
      final eventRef = EventService.events.doc(payload.eventId);
      final attendanceRef = attendance(payload.eventId).doc(memberUid);

      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw AttendanceException('This event no longer exists.');
      }
      final eventData = eventSnap.data()!;
      final eventSecret = eventData['qrSecret'] as String?;
      if (eventSecret == null || eventSecret.isEmpty) {
        throw AttendanceException(
          'Attendance isn’t open yet. Ask your admin to start it.',
        );
      }
      if (eventSecret != payload.secret) {
        throw AttendanceException(
          'That QR is invalid or expired. Ask your admin for a fresh one.',
        );
      }

      // 3-hour window enforcement (server-side safety net).
      final startTs = eventData['date'] as Timestamp?;
      if (startTs != null) {
        final start = startTs.toDate();
        final duration =
            (eventData['durationMinutes'] as num?)?.toInt() ?? 120;
        final windowOpen = start.subtract(const Duration(hours: 3));
        final windowClose = start.add(Duration(minutes: duration));
        final now = DateTime.now();
        if (now.isBefore(windowOpen)) {
          throw AttendanceException(
            'Check-in opens 3 hours before the session starts.',
          );
        }
        if (now.isAfter(windowClose)) {
          throw AttendanceException(
            'Check-in for this session has closed.',
          );
        }
      }

      final attendanceSnap = await tx.get(attendanceRef);
      if (attendanceSnap.exists) {
        throw AttendanceException('You’re already checked in for this event.');
      }

      // qrSecretUsed is required by firestore.rules — the rule re-reads the
      // event's current qrSecret and refuses the write if it doesn't match,
      // so a member cannot forge attendance without a freshly rotated QR.
      tx.set(attendanceRef, {
        'userId': memberUid,
        'userName': memberName,
        'checkedInAt': FieldValue.serverTimestamp(),
        'method': 'qr',
        'starsAwarded': AppConfig.starsPerAttendance,
        'qrSecretUsed': payload.secret,
      });
      // Member clients cannot write their own `stars` under the tightened
      // self-update rule. Attendance stars live on the attendance doc
      // (`starsAwarded: 2`); admin-side reconciliation writes them into
      // `user.stars` via the admin branch of the user-update rule.
    });
  }

  static Future<void> markManual({
    required String eventId,
    required String memberUid,
    required String memberName,
  }) async {
    await _db.runTransaction((tx) async {
      final attendanceRef = attendance(eventId).doc(memberUid);
      final userRef = _db.collection('users').doc(memberUid);

      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw AttendanceException('That member no longer exists.');
      }
      // Refuse to credit a deactivated account — stars awarded here would
      // show on the leaderboard for someone who can't even sign in.
      final isActive = userSnap.data()?['active'] as bool? ?? true;
      if (!isActive) {
        throw AttendanceException(
          'This member is deactivated. Reactivate them before marking attendance.',
        );
      }

      final existing = await tx.get(attendanceRef);
      if (existing.exists) {
        throw AttendanceException('Already marked present.');
      }
      final currentStars = (userSnap.data()?['stars'] as num?)?.toInt() ?? 0;

      tx.set(attendanceRef, {
        'userId': memberUid,
        'userName': memberName,
        'checkedInAt': FieldValue.serverTimestamp(),
        'method': 'manual',
        'starsAwarded': AppConfig.starsPerAttendance,
      });
      tx.update(userRef, {
        'stars': currentStars + AppConfig.starsPerAttendance,
      });
    });
  }
}
