// Pure-Dart unit tests for models and pure-logic services.
//
// No Firebase init, no emulator, no network — everything runs in the
// Dart VM under `flutter test`. Rules behaviour is covered by the
// emulator suite in tool/firestore-tests. Service methods that touch
// FirebaseFirestore.instance are intentionally OUT of scope here;
// those belong to the future emulator-backed service tests.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agaram/core/app_config.dart';
import 'package:agaram/core/attendance_service.dart';
import 'package:agaram/core/members_service.dart';
import 'package:agaram/models/app_notification.dart';
import 'package:agaram/models/app_user.dart';
import 'package:agaram/models/attendance.dart';
import 'package:agaram/models/event.dart';
import 'package:agaram/models/task.dart';

Future<DocumentSnapshot<Map<String, dynamic>>> _seed(
  String path,
  Map<String, dynamic> data, {
  FakeFirebaseFirestore? firestore,
}) async {
  final db = firestore ?? FakeFirebaseFirestore();
  await db.doc(path).set(data);
  return db.doc(path).get();
}

void main() {
  // ════════════════════════════════════════════════════════════════════
  //                      MODEL · AppUser
  // ════════════════════════════════════════════════════════════════════
  group('AppUser', () {
    test('isAdmin reads the role field', () {
      final admin = AppUser(
        uid: 'u', name: 'a', email: 'a@x', role: 'admin',
        isPresident: false, stars: 0,
      );
      final member = AppUser(
        uid: 'u', name: 'b', email: 'b@x', role: 'member',
        isPresident: false, stars: 0,
      );
      expect(admin.isAdmin, isTrue);
      expect(member.isAdmin, isFalse);
    });

    test('fromFirestore hydrates every field', () async {
      final snap = await _seed('users/u1', {
        'name': 'Alice',
        'email': 'alice@club.test',
        'role': 'admin',
        'isPresident': true,
        'position': 'president',
        'active': true,
        'stars': 42,
        'joinedAt': Timestamp.fromDate(DateTime.utc(2025, 1, 15)),
        'photoUrl': 'https://res.cloudinary.com/dttox49ht/x.jpg',
        'phone': '555',
      });
      final u = AppUser.fromFirestore(snap);
      expect(u.uid, 'u1');
      expect(u.name, 'Alice');
      expect(u.email, 'alice@club.test');
      expect(u.role, 'admin');
      expect(u.isPresident, isTrue);
      expect(u.position, 'president');
      expect(u.active, isTrue);
      expect(u.stars, 42);
      expect(
        u.joinedAt?.isAtSameMomentAs(DateTime.utc(2025, 1, 15)),
        isTrue,
      );
      expect(u.photoUrl, endsWith('x.jpg'));
      expect(u.phone, '555');
      expect(u.isAdmin, isTrue);
    });

    test('fromFirestore tolerates missing fields with safe defaults', () async {
      final snap = await _seed('users/u2', <String, dynamic>{});
      final u = AppUser.fromFirestore(snap);
      expect(u.name, '');
      expect(u.email, '');
      expect(u.role, 'member');
      expect(u.isPresident, isFalse);
      expect(u.active, isTrue);
      expect(u.stars, 0);
      expect(u.joinedAt, isNull);
      expect(u.isAdmin, isFalse);
    });

    test('fromFirestore coerces numeric stars (double → int)', () async {
      final snap = await _seed('users/u3', {'stars': 7.0});
      expect(AppUser.fromFirestore(snap).stars, 7);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                      MODEL · AppPosition labels
  // ════════════════════════════════════════════════════════════════════
  group('AppPosition.label', () {
    test('maps every known position', () {
      expect(AppPosition.label('secretary'), 'Secretary');
      expect(AppPosition.label('joint_secretary'), 'Joint Secretary');
      expect(AppPosition.label('treasurer'), 'Treasurer');
      expect(AppPosition.label('joint_treasurer'), 'Joint Treasurer');
      expect(AppPosition.label('vice_president'), 'Vice President');
      expect(AppPosition.label('president'), 'President');
      expect(AppPosition.label('member'), 'Member');
    });
    test('falls back to Member on unknown / null', () {
      expect(AppPosition.label(null), 'Member');
      expect(AppPosition.label('cto'), 'Member');
    });
    test('exposes the canonical `all` ordering', () {
      expect(AppPosition.all.first, 'member');
      expect(AppPosition.all.last, 'president');
      expect(AppPosition.all.length, 7);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                      MODEL · AgaramTask
  // ════════════════════════════════════════════════════════════════════
  group('AgaramTask', () {
    test('parseTaskStatus covers all cases', () {
      expect(parseTaskStatus('pending'), TaskStatus.pending);
      expect(parseTaskStatus('submitted'), TaskStatus.submitted);
      expect(parseTaskStatus('approved'), TaskStatus.approved);
      expect(parseTaskStatus('rejected'), TaskStatus.rejected);
      expect(parseTaskStatus(null), TaskStatus.pending);
      expect(parseTaskStatus('garbage'), TaskStatus.pending);
    });
    test('taskStatusToString roundtrips', () {
      for (final s in TaskStatus.values) {
        expect(parseTaskStatus(taskStatusToString(s)), s);
      }
    });
    test('parseProofType returns null on unknown', () {
      expect(parseProofType('image'), ProofType.image);
      expect(parseProofType('pdf'), ProofType.pdf);
      expect(parseProofType(null), isNull);
      expect(parseProofType('mp4'), isNull);
    });

    test('fromFirestore derives eventId from parent ref if field missing', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('events').doc('evt-42')
          .collection('tasks').doc('t1')
          .set({
        'title': 'Bring banner',
        'assignedTo': 'u1',
        'status': 'submitted',
        'starsAwarded': 3,
      });
      final snap = await db
          .collection('events').doc('evt-42')
          .collection('tasks').doc('t1').get();
      final task = AgaramTask.fromFirestore(snap);
      expect(task.id, 't1');
      expect(task.eventId, 'evt-42',
          reason: 'Should walk parent.parent when eventId field is absent.');
      expect(task.title, 'Bring banner');
      expect(task.assignedTo, 'u1');
      expect(task.status, TaskStatus.submitted);
      expect(task.starsAwarded, 3);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                    MODEL · AppNotification
  // ════════════════════════════════════════════════════════════════════
  group('AppNotification', () {
    test('kindToString / _parseKind roundtrip', () async {
      for (final k in AppNotificationKind.values) {
        final snap = await _seed('notifications/n${k.name}', {
          'kind': kindToString(k),
          'title': 't',
          'body': 'b',
          'topic': 'all_members',
          'sentBy': 'admin',
          'sentByName': 'Admin',
        });
        expect(AppNotification.fromFirestore(snap).kind, k);
      }
    });
    test('kind falls back to announcement on unknown string', () async {
      final snap = await _seed('notifications/x', {'kind': 'mystery'});
      expect(AppNotification.fromFirestore(snap).kind,
          AppNotificationKind.announcement);
    });
    test('fromFirestore preserves optional eventId/taskId', () async {
      final snap = await _seed('notifications/a1', {
        'kind': 'task',
        'title': 'Approved',
        'body': 'nice',
        'topic': 'user_u1',
        'sentBy': 'admin',
        'sentByName': 'Admin',
        'eventId': 'evt-1',
        'taskId': 'task-1',
        'sentAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      final n = AppNotification.fromFirestore(snap);
      expect(n.eventId, 'evt-1');
      expect(n.taskId, 'task-1');
      expect(
        n.sentAt?.isAtSameMomentAs(DateTime.utc(2026, 4, 1)),
        isTrue,
      );
      expect(n.kind, AppNotificationKind.task);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                      MODEL · AgaramEvent
  // ════════════════════════════════════════════════════════════════════
  group('AgaramEvent attendance window', () {
    final start = DateTime.utc(2026, 5, 10, 18, 0);
    final event = AgaramEvent(
      id: 'e',
      title: 't',
      description: '',
      venue: '',
      date: start,
      createdBy: 'admin',
      status: EventStatus.upcoming,
      tasksCount: 0,
      durationMinutes: 120,
    );

    test('opens 3h before start', () {
      expect(event.attendanceWindowOpensAt,
          DateTime.utc(2026, 5, 10, 15, 0));
    });
    test('closes start + durationMinutes', () {
      expect(event.attendanceWindowClosesAt,
          DateTime.utc(2026, 5, 10, 20, 0));
    });
    test('isAttendanceOpenAt — before window', () {
      expect(event.isAttendanceOpenAt(DateTime.utc(2026, 5, 10, 14, 59)),
          isFalse);
    });
    test('isAttendanceOpenAt — exactly at opening', () {
      expect(event.isAttendanceOpenAt(DateTime.utc(2026, 5, 10, 15, 0)),
          isTrue);
    });
    test('isAttendanceOpenAt — middle of window', () {
      expect(event.isAttendanceOpenAt(DateTime.utc(2026, 5, 10, 18, 30)),
          isTrue);
    });
    test('isAttendanceOpenAt — exactly at close', () {
      expect(event.isAttendanceOpenAt(DateTime.utc(2026, 5, 10, 20, 0)),
          isTrue);
    });
    test('isAttendanceOpenAt — after close', () {
      expect(event.isAttendanceOpenAt(DateTime.utc(2026, 5, 10, 20, 1)),
          isFalse);
    });
    test('isMeeting true when kind == meeting', () {
      final meeting = AgaramEvent(
        id: 'm', title: 'm', description: '', venue: '', date: start,
        createdBy: 'a', status: EventStatus.upcoming, tasksCount: 0,
        kind: 'meeting',
      );
      expect(meeting.isMeeting, isTrue);
      expect(event.isMeeting, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                      MODEL · AttendanceEntry
  // ════════════════════════════════════════════════════════════════════
  group('AttendanceEntry', () {
    test('methodToString roundtrips', () async {
      for (final m in AttendanceMethod.values) {
        final snap = await _seed('events/e/attendance/${m.name}', {
          'method': methodToString(m),
          'starsAwarded': 2,
        });
        expect(AttendanceEntry.fromFirestore(snap).method, m);
      }
    });
    test('unknown method falls back to qr', () async {
      final snap = await _seed('events/e/attendance/x', {'method': 'alien'});
      expect(AttendanceEntry.fromFirestore(snap).method, AttendanceMethod.qr);
    });
    test('userId comes from doc id, not payload', () async {
      final snap = await _seed('events/e/attendance/actual-uid', {
        'userId': 'forged-uid',
        'starsAwarded': 2,
      });
      expect(AttendanceEntry.fromFirestore(snap).userId, 'actual-uid');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                   SERVICE · AttendanceQrPayload
  // ════════════════════════════════════════════════════════════════════
  group('AttendanceQrPayload', () {
    test('encode then tryDecode roundtrips', () {
      final p = AttendanceQrPayload(eventId: 'evt_1', secret: 'abc-123');
      final decoded = AttendanceQrPayload.tryDecode(p.encode());
      expect(decoded?.eventId, 'evt_1');
      expect(decoded?.secret, 'abc-123');
    });
    test('tryDecode returns null on malformed JSON', () {
      expect(AttendanceQrPayload.tryDecode('not-json'), isNull);
      expect(AttendanceQrPayload.tryDecode(''), isNull);
      expect(AttendanceQrPayload.tryDecode('{"}'), isNull);
    });
    test('tryDecode rejects non-agaram payloads', () {
      expect(
        AttendanceQrPayload.tryDecode('{"t":"other","e":"x","s":"y"}'),
        isNull,
      );
    });
    test('tryDecode rejects missing e / s fields', () {
      // Missing secret — cast to String will throw, caught as null.
      expect(
        AttendanceQrPayload.tryDecode('{"t":"agaram-att","e":"x"}'),
        isNull,
      );
      expect(
        AttendanceQrPayload.tryDecode('{"t":"agaram-att","s":"y"}'),
        isNull,
      );
    });
    test('encode produces stable JSON prefix', () {
      final p = AttendanceQrPayload(eventId: 'e', secret: 's');
      expect(p.encode(), contains('"t":"agaram-att"'));
      expect(p.encode(), contains('"e":"e"'));
      expect(p.encode(), contains('"s":"s"'));
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                   SERVICE · MembersService.suggestPassword
  // ════════════════════════════════════════════════════════════════════
  group('MembersService.suggestPassword', () {
    test('respects requested length', () {
      expect(MembersService.suggestPassword(length: 6).length, 6);
      expect(MembersService.suggestPassword(length: 10).length, 10);
      expect(MembersService.suggestPassword(length: 20).length, 20);
    });
    test('defaults to length 10', () {
      expect(MembersService.suggestPassword().length, 10);
    });
    test('uses only the curated alphabet (no 0/O/l/I confusion)', () {
      const alphabet =
          'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
      for (var i = 0; i < 50; i++) {
        final pw = MembersService.suggestPassword(length: 10);
        for (final ch in pw.split('')) {
          expect(alphabet.contains(ch), isTrue,
              reason: 'Forbidden char "$ch" in "$pw"');
        }
      }
    });
    test('non-deterministic across successive calls', () {
      final samples = <String>{};
      for (var i = 0; i < 100; i++) {
        samples.add(MembersService.suggestPassword(length: 10));
      }
      // 100 random 10-char picks from a 55-char alphabet should not collide.
      expect(samples.length, greaterThan(90));
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                          AppConfig constants
  // ════════════════════════════════════════════════════════════════════
  group('AppConfig', () {
    test('star constants match rules expectations (FND-04)', () {
      expect(AppConfig.starsPerAttendance, 2);
      expect(AppConfig.starsPerApprovedTask, 3);
    });
    test('upload caps are sane', () {
      expect(AppConfig.maxProofFileSizeMb, 10);
      expect(AppConfig.maxGalleryFileSizeMb, 10);
      expect(AppConfig.maxWalletFileSizeMb, 10);
      expect(AppConfig.maxBannerFileSizeMb, lessThan(10));
      expect(AppConfig.maxAvatarFileSizeMb, lessThan(10));
    });
    test('cloudinary config points at the agaram bucket', () {
      expect(AppConfig.cloudinaryCloudName, 'dttox49ht');
      expect(AppConfig.cloudinaryUploadPreset, 'agaram_uploads');
      expect(AppConfig.cloudinaryFolderRoot, 'agaram');
    });
    test('topic names are stable (FND-09 reconciliation depends on them)', () {
      expect(AppConfig.topicAllMembers, 'all_members');
      expect(AppConfig.topicAdmins, 'admins_only');
    });
  });
}
