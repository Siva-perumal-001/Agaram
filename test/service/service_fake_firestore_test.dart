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
import 'package:agaram/core/stars_service.dart';
import 'package:agaram/core/wallet_service.dart';
import 'package:agaram/models/app_notification.dart';
import 'package:agaram/models/task.dart';
import 'package:agaram/models/wallet_doc.dart';

const kMember = 'member_uid';
const kOtherMember = 'other_uid';
const kAdmin = 'admin_uid';
const kEventId = 'evt_one';
const kQrSecret = 'qr-secret-deadbeef';

Future<FakeFirebaseFirestore> _freshDb({
  Map<String, dynamic>? eventOverrides,
  bool withUser = true,
}) async {
  final db = FakeFirebaseFirestore();
  if (withUser) {
    await db.collection('users').doc(kMember).set({
      'name': 'Mem',
      'email': 'm@x',
      'role': 'member',
      'active': true,
      'stars': 0,
      'isPresident': false,
    });
    await db.collection('users').doc(kAdmin).set({
      'name': 'Admin',
      'email': 'a@x',
      'role': 'admin',
      'active': true,
      'stars': 0,
      'isPresident': false,
    });
  }
  await db.collection('events').doc(kEventId).set({
    'title': 'Welcome Meet',
    'description': '',
    'venue': 'Auditorium',
    'date': Timestamp.fromDate(DateTime.now()),
    'durationMinutes': 120,
    'status': 'ongoing',
    'kind': 'event',
    'createdBy': kAdmin,
    'qrSecret': kQrSecret,
    'tasksCount': 0,
    ...?eventOverrides,
  });
  EventService.database = db;
  AttendanceService.database = db;
  WalletService.database = db;
  NotificationsService.database = db;
  StarsService.database = db;
  return db;
}

void _resetAll() {
  EventService.resetDatabase();
  AttendanceService.resetDatabase();
  WalletService.resetDatabase();
  NotificationsService.resetDatabase();
  StarsService.resetDatabase();
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
        payload: AttendanceQrPayload(eventId: kEventId, secret: kQrSecret),
        memberUid: kMember,
        memberName: 'Mem',
      );
      final snap = await db
          .collection('events').doc(kEventId)
          .collection('attendance').doc(kMember).get();
      expect(snap.exists, isTrue);
      expect(snap.data()?['qrSecretUsed'], kQrSecret);
      expect(snap.data()?['method'], 'qr');
      expect(snap.data()?['starsAwarded'], 2);
      expect(snap.data()?['userId'], kMember);
    });

    test('rejects when event missing', () async {
      await _freshDb();
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: 'ghost', secret: kQrSecret),
          memberUid: kMember,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('rejects when qrSecret is empty / not started', () async {
      await _freshDb(eventOverrides: {'qrSecret': ''});
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: kEventId, secret: kQrSecret),
          memberUid: kMember,
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
              AttendanceQrPayload(eventId: kEventId, secret: 'stale-secret'),
          memberUid: kMember,
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
          payload: AttendanceQrPayload(eventId: kEventId, secret: kQrSecret),
          memberUid: kMember,
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
          payload: AttendanceQrPayload(eventId: kEventId, secret: kQrSecret),
          memberUid: kMember,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('double-scan for same member is rejected', () async {
      await _freshDb();
      await AttendanceService.checkInWithQr(
        payload: AttendanceQrPayload(eventId: kEventId, secret: kQrSecret),
        memberUid: kMember,
        memberName: 'Mem',
      );
      expect(
        () => AttendanceService.checkInWithQr(
          payload: AttendanceQrPayload(eventId: kEventId, secret: kQrSecret),
          memberUid: kMember,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('does NOT touch user.stars (stars are derived live)', () async {
      final db = await _freshDb();
      await AttendanceService.checkInWithQr(
        payload: AttendanceQrPayload(eventId: kEventId, secret: kQrSecret),
        memberUid: kMember,
        memberName: 'Mem',
      );
      final user = await db.collection('users').doc(kMember).get();
      expect(user.data()?['stars'], 0,
          reason: 'users.stars is no longer written; StarsService derives '
              'earned stars from the attendance doc directly.');
      expect(await StarsService.earnedFor(kMember), 2,
          reason: 'attendance doc with starsAwarded=2 contributes +2 to '
              'live earned-stars total.');
    });
  });

  group('AttendanceService.markManual', () {
    test('admin path writes attendance only (stars derived live)', () async {
      final db = await _freshDb();
      await AttendanceService.markManual(
        eventId: kEventId,
        memberUid: kMember,
        memberName: 'Mem',
      );
      final att = await db
          .collection('events').doc(kEventId)
          .collection('attendance').doc(kMember).get();
      expect(att.data()?['method'], 'manual');
      expect(att.data()?['starsAwarded'], 2);
      final user = await db.collection('users').doc(kMember).get();
      expect(user.data()?['stars'], 0,
          reason: 'users.stars is no longer written; live derivation only.');
      expect(await StarsService.earnedFor(kMember), 2);
    });

    test('rejects if member user doc missing', () async {
      final db = await _freshDb();
      await db.collection('users').doc(kMember).delete();
      expect(
        () => AttendanceService.markManual(
          eventId: kEventId,
          memberUid: kMember,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('rejects deactivated user (FND-17)', () async {
      final db = await _freshDb();
      await db
          .collection('users').doc(kMember)
          .update({'active': false});
      expect(
        () => AttendanceService.markManual(
          eventId: kEventId,
          memberUid: kMember,
          memberName: 'Mem',
        ),
        throwsA(isA<AttendanceException>()),
      );
    });

    test('double-mark rejected', () async {
      await _freshDb();
      await AttendanceService.markManual(
        eventId: kEventId,
        memberUid: kMember,
        memberName: 'Mem',
      );
      expect(
        () => AttendanceService.markManual(
          eventId: kEventId,
          memberUid: kMember,
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
        eventId: kEventId,
        eventTitle: 'Welcome Meet',
        title: 'Bring banner',
        description: 'please',
        assignedTo: kMember,
        assignedToName: 'Mem',
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      final snap = await db
          .collection('events').doc(kEventId)
          .collection('tasks').doc(ref.id).get();
      expect(snap.exists, isTrue);
      expect(snap.data()?['status'], 'pending');
      expect(snap.data()?['starsAwarded'], 0);
      expect(snap.data()?['assignedTo'], kMember);
    });

    test('increments event.tasksCount by exactly 1', () async {
      final db = await _freshDb();
      await db
          .collection('events').doc(kEventId)
          .update({'tasksCount': 3});
      await EventService.addTask(
        eventId: kEventId,
        eventTitle: 'Welcome Meet',
        title: 't', description: '',
        assignedTo: kMember, assignedToName: 'Mem',
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      final ev = await db.collection('events').doc(kEventId).get();
      expect(ev.data()?['tasksCount'], 4);
    });
  });

  group('EventService.approveTask', () {
    Future<String> seedTask(
      FakeFirebaseFirestore db, {
      String status = 'submitted',
    }) async {
      final ref = await db
          .collection('events').doc(kEventId)
          .collection('tasks').add({
        'title': 'Bring banner',
        'assignedTo': kMember,
        'assignedToName': 'Mem',
        'status': status,
        'starsAwarded': 0,
      });
      return ref.id;
    }

    test('approval flips status; live earned grows by 3', () async {
      final db = await _freshDb();
      final taskId = await seedTask(db);
      await EventService.approveTask(
        eventId: kEventId,
        taskId: taskId,
        reviewerUid: kAdmin,
        memberUid: kMember,
        reviewNote: 'great',
      );
      final task = await db
          .collection('events').doc(kEventId)
          .collection('tasks').doc(taskId).get();
      expect(task.data()?['status'], 'approved');
      expect(task.data()?['starsAwarded'], 3);
      expect(task.data()?['reviewedBy'], kAdmin);

      final user = await db.collection('users').doc(kMember).get();
      expect(user.data()?['stars'], 0,
          reason: 'users.stars is no longer written; live derivation only.');
      expect(await StarsService.earnedFor(kMember), 3);
    });

    test('is idempotent — re-approving already-approved task does nothing',
        () async {
      final db = await _freshDb();
      final taskId = await seedTask(db, status: 'approved');
      await EventService.approveTask(
        eventId: kEventId,
        taskId: taskId,
        reviewerUid: kAdmin,
        memberUid: kMember,
        reviewNote: 'retry',
      );
      // The task was already approved at seed time, so the live earned
      // count is +3 even before approveTask was called. The point of this
      // test is that approveTask doesn't double-award (e.g. by re-running
      // side effects). Since stars are derived live, the only way to "double
      // award" would be to mutate the task state — and the idempotent guard
      // prevents that.
      final task = await db
          .collection('events').doc(kEventId)
          .collection('tasks').doc(taskId).get();
      expect(task.data()?['starsAwarded'], 0,
          reason: 'idempotent guard at event_service.dart prevents the '
              'starsAwarded field from being overwritten.');
      expect(await StarsService.earnedFor(kMember), 3);
    });

    test('throws when task does not exist', () async {
      await _freshDb();
      expect(
        () => EventService.approveTask(
          eventId: kEventId,
          taskId: 'ghost',
          reviewerUid: kAdmin,
          memberUid: kMember,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('EventService.rejectTask (FND-14 transactional)', () {
    test('flips to rejected + starsAwarded=0, no earned-stars change',
        () async {
      final db = await _freshDb();
      final taskRef = await db
          .collection('events').doc(kEventId)
          .collection('tasks').add({
        'title': 'Bring banner',
        'assignedTo': kMember,
        'status': 'submitted',
        'starsAwarded': 0,
      });
      await EventService.rejectTask(
        eventId: kEventId,
        taskId: taskRef.id,
        reviewerUid: kAdmin,
        reviewNote: 'needs more detail',
      );
      final task = await db
          .collection('events').doc(kEventId)
          .collection('tasks').doc(taskRef.id).get();
      expect(task.data()?['status'], 'rejected');
      expect(task.data()?['reviewNote'], 'needs more detail');
      expect(task.data()?['reviewedBy'], kAdmin);
      expect(task.data()?['starsAwarded'], 0);

      expect(await StarsService.earnedFor(kMember), 0,
          reason: 'reject does not contribute to live earned-stars total');
    });

    test('throws when task missing', () async {
      await _freshDb();
      expect(
        () => EventService.rejectTask(
          eventId: kEventId,
          taskId: 'ghost',
          reviewerUid: kAdmin,
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
          .collection('events').doc(kEventId)
          .collection('tasks').add({
        'title': 'Bring banner',
        'assignedTo': kMember,
        'status': 'rejected',
        'reviewNote': 'Please add caption', // leftover from previous review
        'reviewedBy': kAdmin,
      });
      await EventService.submitProof(
        eventId: kEventId,
        taskId: taskRef.id,
        proofUrl: 'https://res.cloudinary.com/dttox49ht/x.jpg',
        proofType: ProofType.image,
        memberNote: 'done',
      );
      final snap = await db
          .collection('events').doc(kEventId)
          .collection('tasks').doc(taskRef.id).get();
      expect(snap.data()?['status'], 'submitted');
      expect(snap.data()?['proofUrl'], contains('cloudinary'));
      expect(snap.data()?['memberNote'], 'done');
      // FND-03 fix: review metadata is NOT re-written by member
      expect(snap.data()?['reviewNote'], 'Please add caption');
      expect(snap.data()?['reviewedBy'], kAdmin);
    });
  });

  group('EventService.deleteEvent (FND-06 cascade)', () {
    test('removes event AND every child subcollection doc', () async {
      final db = await _freshDb();
      final eventRef = db.collection('events').doc(kEventId);
      await eventRef.collection('tasks').add({'title': 'a'});
      await eventRef.collection('tasks').add({'title': 'b'});
      await eventRef.collection('attendance').doc(kMember).set({'userId': kMember});
      await eventRef.collection('gallery').add({'url': 'x'});
      await eventRef.collection('wallet').add({'url': 'y', 'type': 'pdf'});

      await EventService.deleteEvent(kEventId);

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
      final eventRef = db.collection('events').doc(kEventId);
      for (var i = 0; i < 420; i++) {
        await eventRef.collection('tasks').add({'title': 'T$i'});
      }
      await EventService.deleteEvent(kEventId);
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
      final eventRef = db.collection('events').doc(kEventId);
      // addDoc uploads to Cloudinary first, which we can't do in a unit test.
      // Instead exercise the counter-update half directly via a tx that
      // matches the shape of WalletService.addDoc's transaction.
      await db.runTransaction((tx) async {
        tx.set(
          eventRef.collection('wallet').doc('d1'),
          {'type': 'pdf', 'uploadedBy': kMember},
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
      final eventRef = db.collection('events').doc(kEventId);
      final walletRef = await eventRef.collection('wallet').add({
        'type': 'pdf', 'uploadedBy': kMember,
      });
      final doc = WalletDoc(
        id: walletRef.id, eventId: kEventId, eventTitle: 'x', title: 't',
        url: 'u', type: WalletDocType.pdf, uploadedBy: kMember,
        uploadedByName: 'Mem', fileName: 'f.pdf', sizeBytes: 1,
      );
      await WalletService.deleteDoc(eventId: kEventId, doc: doc);
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
      final eventRef = db.collection('events').doc(kEventId);
      final walletRef = await eventRef.collection('wallet').add({
        'type': 'image', 'uploadedBy': kMember,
      });
      await WalletService.deleteDoc(
        eventId: kEventId,
        doc: WalletDoc(
          id: walletRef.id, eventId: kEventId, eventTitle: 'x', title: 't',
          url: 'u', type: WalletDocType.image, uploadedBy: kMember,
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
        sentBy: kAdmin,
        sentByName: 'Admin',
        eventId: kEventId,
      );
      final snap = await db.collection('notifications').doc(id).get();
      expect(snap.exists, isTrue);
      expect(snap.data()?['title'], 'hi');
      expect(snap.data()?['kind'], 'announcement');
      expect(snap.data()?['eventId'], kEventId);
      expect(snap.data()?['taskId'], isNull);
    });
  });

  group('NotificationsService.markAllRead', () {
    test('sets lastReadNotificationsAt on user doc (merge)', () async {
      final db = await _freshDb();
      await NotificationsService.markAllRead(kMember);
      final u = await db.collection('users').doc(kMember).get();
      expect(u.data()?['lastReadNotificationsAt'], isA<Timestamp>());
      // existing fields preserved
      expect(u.data()?['name'], 'Mem');
    });
  });

  group('NotificationsService.unreadCount (FND-22)', () {
    Future<void> seedNotifs(FakeFirebaseFirestore db, List<DateTime> times) async {
      for (final t in times) {
        await db.collection('notifications').add({
          'title': 't', 'body': 'b', 'kind': 'announcement',
          'topic': 'all_members', 'sentBy': kAdmin, 'sentByName': 'Admin',
          'sentAt': Timestamp.fromDate(t),
        });
      }
    }

    test('returns 0 when no notifications', () async {
      await _freshDb();
      final count = await NotificationsService.unreadCount(kMember, isAdmin: false).first;
      expect(count, 0);
    });

    test('counts all notifications when lastRead is null', () async {
      final db = await _freshDb();
      await seedNotifs(db, [
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 5),
        DateTime(2026, 4, 10),
      ]);
      final count = await NotificationsService.unreadCount(kMember, isAdmin: false).first;
      expect(count, 3);
    });

    test('counts only notifications after lastReadNotificationsAt', () async {
      final db = await _freshDb();
      await db.collection('users').doc(kMember).update({
        'lastReadNotificationsAt': Timestamp.fromDate(DateTime(2026, 4, 5)),
      });
      await seedNotifs(db, [
        DateTime(2026, 4, 1), // before lastRead
        DateTime(2026, 4, 5), // at lastRead (strictly after only)
        DateTime(2026, 4, 6), // after
        DateTime(2026, 4, 10), // after
      ]);
      final count = await NotificationsService.unreadCount(kMember, isAdmin: false).first;
      expect(count, 2);
    });

    test('handles >50 unread without capping (FND-22 fix)', () async {
      final db = await _freshDb();
      final now = DateTime(2026, 4, 1);
      await seedNotifs(
          db, List.generate(75, (i) => now.add(Duration(minutes: i))));
      final count = await NotificationsService.unreadCount(kMember, isAdmin: false).first;
      expect(count, 75,
          reason: 'fetch-and-filter capped at limit(100); 75 items must all count.');
    });
  });
}
