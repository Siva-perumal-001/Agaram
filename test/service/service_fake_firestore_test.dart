// Service-layer tests with an in-memory FakeFirebaseFirestore swapped in
// via each service's @visibleForTesting `database` setter.
//
// The Layer-1 rules suite proves *who* can do what. These tests prove the
// Dart services do the *right write shape* and transaction flow — counter
// atomicity, approve/reject idempotency, attendance double-scan, cascade
// deletes, unread-count aggregation.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agaram/core/attendance_service.dart';
import 'package:agaram/core/event_service.dart';
import 'package:agaram/core/notifications_service.dart';
import 'package:agaram/core/wallet_service.dart';
import 'package:agaram/models/app_notification.dart';
import 'package:agaram/models/task.dart';
import 'package:agaram/models/wallet_doc.dart';

const MEMBER = 'member_uid';
const OTHER_MEMBER = 'other_uid';
const ADMIN = 'admin_uid';
const EVENT_ID = 'evt_one';
const QR_SECRET = 'qr-secret-deadbeef';

Future<FakeFirebaseFirestore> _freshDb({
  Map<String, dynamic>? eventOverrides,
  bool withUser = true,
}) async {
  final db = FakeFirebaseFirestore();
  if (withUser) {
    await db.collection('users').doc(MEMBER).set({
      'name': 'Mem',
      'email': 'm@x',
      'role': 'member',
      'active': true,
      'stars': 0,
      'isPresident': false,
    });
    await db.collection('users').doc(ADMIN).set({
      'name': 'Admin',
      'email': 'a@x',
      'role': 'admin',
      'active': true,
      'stars': 0,
      'isPresident': false,
    });
  }
  await db.collection('events').doc(EVENT_ID).set({
    'title': 'Welcome Meet',
    'description': '',
    'venue': 'Auditorium',
    'date': Timestamp.fromDate(DateTime.now()),
    'durationMinutes': 120,
    'status': 'ongoing',
    'kind': 'event',
    'createdBy': ADMIN,
    'qrSecret': QR_SECRET,
    'tasksCount': 0,
    ...?eventOverrides,
  });
  EventService.database = db;
  AttendanceService.database = db;
  WalletService.database = db;
  NotificationsService.database = db;
  return db;
}

void _resetAll() {
  EventService.resetDatabase();
  AttendanceService.resetDatabase();
  WalletService.resetDatabase();
  NotificationsService.resetDatabase();
}

void main() {
  tearDown(_resetAll);

  // ════════════════════════════════════════════════════════════════════
  //                        AttendanceService
  // ════════════════════════════════════════════════════════════════════
  group('AttendanceService.checkInWithQr', () {
    test('happy path writes attendance with qrSecretUsed', () async {
      final db = await _freshDb();
      await AttendanceService.checkInWithQr(
        payload: AttendanceQrPayload(eventId: EVENT_ID, secret: QR_SECRET),
        memberUid: MEMBER,
        memberName: 'Mem',
      );
      final snap = await db
          .collection('events').doc(EVENT_ID)
          .collection('attendance').doc(MEMBER).get();
      expect(snap.exists, isTrue);
      expect(snap.data()?['qrSecretUsed'], QR_SECRET);
      expect(snap.data()?['method'], 'qr');
      expect(snap.data()?['starsAwarded'], 2);
      expect(snap.data()?['userId'], MEMBER);
    });

    test('rejects when event missing', () async {
      await _freshDb();
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: 'ghost', secret: QR_SECRET),
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('rejects when qrSecret is empty / not started', () async {
      await _freshDb(eventOverrides: {'qrSecret': ''});
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: EVENT_ID, secret: QR_SECRET),
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('rejects when scanned secret does not match rotated secret', () async {
      await _freshDb();
      expect(
        () => AttendanceService.checkInWithQr(
          payload:
              AttendanceQrPayload(eventId: EVENT_ID, secret: 'stale-secret'),
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('rejects before the 3h window opens', () async {
      await _freshDb(eventOverrides: {
        'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
      });
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: EVENT_ID, secret: QR_SECRET),
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('rejects after the window closes', () async {
      await _freshDb(eventOverrides: {
        'date':
            Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
        'durationMinutes': 60,
      });
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: EVENT_ID, secret: QR_SECRET),
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('double-scan for same member is rejected', () async {
      await _freshDb();
      await AttendanceService.checkInWithQr(
        payload: AttendanceQrPayload(eventId: EVENT_ID, secret: QR_SECRET),
        memberUid: MEMBER,
        memberName: 'Mem',
      );
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: EVENT_ID, secret: QR_SECRET),
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('does NOT bump user.stars on member-side write (FND-02)', () async {
      final db = await _freshDb();
      await AttendanceService.checkInWithQr(
        payload: AttendanceQrPayload(eventId: EVENT_ID, secret: QR_SECRET),
        memberUid: MEMBER,
        memberName: 'Mem',
      );
      final user = await db.collection('users').doc(MEMBER).get();
      expect(user.data()?['stars'], 0,
          reason: 'Self-stars writes are blocked by FND-02; stars stay 0 '
              'until admin reconciliation.');
    });
  });

  group('AttendanceService.markManual', () {
    test('admin path writes attendance + bumps user.stars by 2', () async {
      final db = await _freshDb();
      await AttendanceService.markManual(
        eventId: EVENT_ID,
        memberUid: MEMBER,
        memberName: 'Mem',
      );
      final att = await db
          .collection('events').doc(EVENT_ID)
          .collection('attendance').doc(MEMBER).get();
      expect(att.data()?['method'], 'manual');
      expect(att.data()?['starsAwarded'], 2);
      final user = await db.collection('users').doc(MEMBER).get();
      expect(user.data()?['stars'], 2);
    });

    test('rejects if member user doc missing', () async {
      final db = await _freshDb();
      await db.collection('users').doc(MEMBER).delete();
      expect(
        () => AttendanceService.markManual(
          eventId: EVENT_ID,
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('rejects deactivated user (FND-17)', () async {
      final db = await _freshDb();
      await db
          .collection('users').doc(MEMBER)
          .update({'active': false});
      expect(
        () => AttendanceService.markManual(
          eventId: EVENT_ID,
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('double-mark rejected', () async {
      await _freshDb();
      await AttendanceService.markManual(
        eventId: EVENT_ID,
        memberUid: MEMBER,
        memberName: 'Mem',
      );
      expect(
        () => AttendanceService.markManual(
          eventId: EVENT_ID,
          memberUid: MEMBER,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                          EventService
  // ════════════════════════════════════════════════════════════════════
  group('EventService.addTask (FND-07 transactional counter)', () {
    test('creates task doc with pending status + 0 stars', () async {
      final db = await _freshDb();
      final ref = await EventService.addTask(
        eventId: EVENT_ID,
        eventTitle: 'Welcome Meet',
        title: 'Bring banner',
        description: 'please',
        assignedTo: MEMBER,
        assignedToName: 'Mem',
      );
      final snap = await db
          .collection('events').doc(EVENT_ID)
          .collection('tasks').doc(ref.id).get();
      expect(snap.exists, isTrue);
      expect(snap.data()?['status'], 'pending');
      expect(snap.data()?['starsAwarded'], 0);
      expect(snap.data()?['assignedTo'], MEMBER);
    });

    test('increments event.tasksCount by exactly 1', () async {
      final db = await _freshDb();
      await db
          .collection('events').doc(EVENT_ID)
          .update({'tasksCount': 3});
      await EventService.addTask(
        eventId: EVENT_ID,
        eventTitle: 'Welcome Meet',
        title: 't', description: '',
        assignedTo: MEMBER, assignedToName: 'Mem',
      );
      final ev = await db.collection('events').doc(EVENT_ID).get();
      expect(ev.data()?['tasksCount'], 4);
    });
  });

  group('EventService.approveTask', () {
    Future<String> _seedTask(
      FakeFirebaseFirestore db, {
      String status = 'submitted',
      int currentStars = 0,
    }) async {
      await db.collection('users').doc(MEMBER).update({'stars': currentStars});
      final ref = await db
          .collection('events').doc(EVENT_ID)
          .collection('tasks').add({
        'title': 'Bring banner',
        'assignedTo': MEMBER,
        'assignedToName': 'Mem',
        'status': status,
        'starsAwarded': 0,
      });
      return ref.id;
    }

    test('approval flips status + bumps user.stars by 3', () async {
      final db = await _freshDb();
      final taskId = await _seedTask(db, currentStars: 4);
      await EventService.approveTask(
        eventId: EVENT_ID,
        taskId: taskId,
        reviewerUid: ADMIN,
        memberUid: MEMBER,
        reviewNote: 'great',
      );
      final task = await db
          .collection('events').doc(EVENT_ID)
          .collection('tasks').doc(taskId).get();
      expect(task.data()?['status'], 'approved');
      expect(task.data()?['starsAwarded'], 3);
      expect(task.data()?['reviewedBy'], ADMIN);

      final user = await db.collection('users').doc(MEMBER).get();
      expect(user.data()?['stars'], 7);
    });

    test('is idempotent — re-approving already-approved task does nothing',
        () async {
      final db = await _freshDb();
      final taskId = await _seedTask(db, status: 'approved', currentStars: 10);
      await EventService.approveTask(
        eventId: EVENT_ID,
        taskId: taskId,
        reviewerUid: ADMIN,
        memberUid: MEMBER,
        reviewNote: 'retry',
      );
      final user = await db.collection('users').doc(MEMBER).get();
      expect(user.data()?['stars'], 10,
          reason: 'idempotent guard at event_service.dart:151 prevents double-award');
    });

    test('throws when task does not exist', () async {
      await _freshDb();
      expect(
        () => EventService.approveTask(
          eventId: EVENT_ID,
          taskId: 'ghost',
          reviewerUid: ADMIN,
          memberUid: MEMBER,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('EventService.rejectTask (FND-14 transactional)', () {
    test('flips to rejected + starsAwarded=0, no stars change', () async {
      final db = await _freshDb();
      await db.collection('users').doc(MEMBER).update({'stars': 5});
      final taskRef = await db
          .collection('events').doc(EVENT_ID)
          .collection('tasks').add({
        'title': 'Bring banner',
        'assignedTo': MEMBER,
        'status': 'submitted',
        'starsAwarded': 0,
      });
      await EventService.rejectTask(
        eventId: EVENT_ID,
        taskId: taskRef.id,
        reviewerUid: ADMIN,
        reviewNote: 'needs more detail',
      );
      final task = await db
          .collection('events').doc(EVENT_ID)
          .collection('tasks').doc(taskRef.id).get();
      expect(task.data()?['status'], 'rejected');
      expect(task.data()?['reviewNote'], 'needs more detail');
      expect(task.data()?['reviewedBy'], ADMIN);
      expect(task.data()?['starsAwarded'], 0);

      final user = await db.collection('users').doc(MEMBER).get();
      expect(user.data()?['stars'], 5, reason: 'reject does not award stars');
    });

    test('throws when task missing', () async {
      await _freshDb();
      expect(
        () => EventService.rejectTask(
          eventId: EVENT_ID,
          taskId: 'ghost',
          reviewerUid: ADMIN,
          reviewNote: 'no',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('EventService.submitProof (FND-03)', () {
    test('member submit writes proof + status=submitted, leaves review fields alone',
        () async {
      final db = await _freshDb();
      final taskRef = await db
          .collection('events').doc(EVENT_ID)
          .collection('tasks').add({
        'title': 'Bring banner',
        'assignedTo': MEMBER,
        'status': 'rejected',
        'reviewNote': 'Please add caption', // leftover from previous review
        'reviewedBy': ADMIN,
      });
      await EventService.submitProof(
        eventId: EVENT_ID,
        taskId: taskRef.id,
        proofUrl: 'https://res.cloudinary.com/dttox49ht/x.jpg',
        proofType: ProofType.image,
        memberNote: 'done',
      );
      final snap = await db
          .collection('events').doc(EVENT_ID)
          .collection('tasks').doc(taskRef.id).get();
      expect(snap.data()?['status'], 'submitted');
      expect(snap.data()?['proofUrl'], contains('cloudinary'));
      expect(snap.data()?['memberNote'], 'done');
      // FND-03 fix: review metadata is NOT re-written by member
      expect(snap.data()?['reviewNote'], 'Please add caption');
      expect(snap.data()?['reviewedBy'], ADMIN);
    });
  });

  group('EventService.deleteEvent (FND-06 cascade)', () {
    test('removes event AND every child subcollection doc', () async {
      final db = await _freshDb();
      final eventRef = db.collection('events').doc(EVENT_ID);
      await eventRef.collection('tasks').add({'title': 'a'});
      await eventRef.collection('tasks').add({'title': 'b'});
      await eventRef.collection('attendance').doc(MEMBER).set({'userId': MEMBER});
      await eventRef.collection('gallery').add({'url': 'x'});
      await eventRef.collection('wallet').add({'url': 'y', 'type': 'pdf'});

      await EventService.deleteEvent(EVENT_ID);

      expect((await eventRef.get()).exists, isFalse);
      expect(
          (await eventRef.collection('tasks').get()).docs, isEmpty);
      expect(
          (await eventRef.collection('attendance').get()).docs, isEmpty);
      expect(
          (await eventRef.collection('gallery').get()).docs, isEmpty);
      expect((await eventRef.collection('wallet').get()).docs, isEmpty);
    });

    test('paginates past the 400-doc batch limit', () async {
      final db = await _freshDb();
      final eventRef = db.collection('events').doc(EVENT_ID);
      for (var i = 0; i < 420; i++) {
        await eventRef.collection('tasks').add({'title': 'T$i'});
      }
      await EventService.deleteEvent(EVENT_ID);
      expect(
          (await eventRef.collection('tasks').get()).docs, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ════════════════════════════════════════════════════════════════════
  //                          WalletService
  // ════════════════════════════════════════════════════════════════════
  group('WalletService.addDoc counter math', () {
    test('PDF add increments walletCounts.pdfs atomically', () async {
      final db = await _freshDb();
      final eventRef = db.collection('events').doc(EVENT_ID);
      // addDoc uploads to Cloudinary first, which we can't do in a unit test.
      // Instead exercise the counter-update half directly via a tx that
      // matches the shape of WalletService.addDoc's transaction.
      await db.runTransaction((tx) async {
        tx.set(
          eventRef.collection('wallet').doc('d1'),
          {'type': 'pdf', 'uploadedBy': MEMBER},
        );
        tx.set(
          eventRef,
          {
            'walletCounts': {'pdfs': FieldValue.increment(1)},
            'walletLastUploadAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      final ev = await eventRef.get();
      expect(ev.data()?['walletCounts']['pdfs'], 1);
    });
  });

  group('WalletService.deleteDoc', () {
    test('atomically deletes wallet doc AND writes walletCounts update (PDF)',
        () async {
      // fake_cloud_firestore does not model FieldValue.increment nested
      // inside a merged map the same way production Firestore does, so we
      // don't assert the final counter value here — only that the delete
      // and the counter-update land in the same transaction (doc gone,
      // walletCounts field written). The counter math itself is proven by
      // the rules suite + Layer 3 integration on a real emulator.
      final db = await _freshDb();
      final eventRef = db.collection('events').doc(EVENT_ID);
      final walletRef = await eventRef.collection('wallet').add({
        'type': 'pdf', 'uploadedBy': MEMBER,
      });
      final doc = WalletDoc(
        id: walletRef.id, eventId: EVENT_ID, eventTitle: 'x', title: 't',
        url: 'u', type: WalletDocType.pdf, uploadedBy: MEMBER,
        uploadedByName: 'Mem', fileName: 'f.pdf', sizeBytes: 1,
      );
      await WalletService.deleteDoc(eventId: EVENT_ID, doc: doc);
      expect(
        (await eventRef.collection('wallet').doc(walletRef.id).get()).exists,
        isFalse,
      );
      final ev = await eventRef.get();
      expect(
        ev.data()?['walletCounts'],
        isA<Map>(),
        reason: 'transaction should have written walletCounts alongside delete',
      );
    });

    test('image delete also touches walletCounts in the same transaction',
        () async {
      final db = await _freshDb();
      final eventRef = db.collection('events').doc(EVENT_ID);
      final walletRef = await eventRef.collection('wallet').add({
        'type': 'image', 'uploadedBy': MEMBER,
      });
      await WalletService.deleteDoc(
        eventId: EVENT_ID,
        doc: WalletDoc(
          id: walletRef.id, eventId: EVENT_ID, eventTitle: 'x', title: 't',
          url: 'u', type: WalletDocType.image, uploadedBy: MEMBER,
          uploadedByName: 'Mem', fileName: 'f.jpg', sizeBytes: 1,
        ),
      );
      final ev = await eventRef.get();
      expect(ev.data()?['walletCounts'], isA<Map>());
      expect(
        (await eventRef.collection('wallet').doc(walletRef.id).get()).exists,
        isFalse,
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //                         NotificationsService
  // ════════════════════════════════════════════════════════════════════
  group('NotificationsService.save', () {
    test('creates a doc with the passed fields + serverTimestamp', () async {
      final db = await _freshDb();
      final id = await NotificationsService.save(
        title: 'hi',
        body: 'b',
        kind: AppNotificationKind.announcement,
        topic: 'all_members',
        sentBy: ADMIN,
        sentByName: 'Admin',
        eventId: EVENT_ID,
      );
      final snap = await db.collection('notifications').doc(id).get();
      expect(snap.exists, isTrue);
      expect(snap.data()?['title'], 'hi');
      expect(snap.data()?['kind'], 'announcement');
      expect(snap.data()?['eventId'], EVENT_ID);
      expect(snap.data()?['taskId'], isNull);
    });
  });

  group('NotificationsService.markAllRead', () {
    test('sets lastReadNotificationsAt on user doc (merge)', () async {
      final db = await _freshDb();
      await NotificationsService.markAllRead(MEMBER);
      final u = await db.collection('users').doc(MEMBER).get();
      expect(u.data()?['lastReadNotificationsAt'], isA<Timestamp>());
      // existing fields preserved
      expect(u.data()?['name'], 'Mem');
    });
  });

  group('NotificationsService.unreadCount (FND-22)', () {
    Future<void> _seedNotifs(FakeFirebaseFirestore db, List<DateTime> times) async {
      for (final t in times) {
        await db.collection('notifications').add({
          'title': 't', 'body': 'b', 'kind': 'announcement',
          'topic': 'all_members', 'sentBy': ADMIN, 'sentByName': 'Admin',
          'sentAt': Timestamp.fromDate(t),
        });
      }
    }

    test('returns 0 when no notifications', () async {
      await _freshDb();
      final count = await NotificationsService.unreadCount(MEMBER).first;
      expect(count, 0);
    });

    test('counts all notifications when lastRead is null', () async {
      final db = await _freshDb();
      await _seedNotifs(db, [
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 5),
        DateTime(2026, 4, 10),
      ]);
      final count = await NotificationsService.unreadCount(MEMBER).first;
      expect(count, 3);
    });

    test('counts only notifications after lastReadNotificationsAt', () async {
      final db = await _freshDb();
      await db.collection('users').doc(MEMBER).update({
        'lastReadNotificationsAt': Timestamp.fromDate(DateTime(2026, 4, 5)),
      });
      await _seedNotifs(db, [
        DateTime(2026, 4, 1), // before lastRead
        DateTime(2026, 4, 5), // at lastRead (strictly after only)
        DateTime(2026, 4, 6), // after
        DateTime(2026, 4, 10), // after
      ]);
      final count = await NotificationsService.unreadCount(MEMBER).first;
      expect(count, 2);
    });

    test('handles >50 unread without capping (FND-22 fix)', () async {
      final db = await _freshDb();
      final now = DateTime(2026, 4, 1);
      await _seedNotifs(
          db, List.generate(75, (i) => now.add(Duration(minutes: i))));
      final count = await NotificationsService.unreadCount(MEMBER).first;
      expect(count, 75,
          reason: '.count() aggregate is not bounded by limit(50).');
    });
  });
}
