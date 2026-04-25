import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'fcm_service.dart';
import 'notifications_service.dart';
import 'reminder_service.dart';
import 'stars_service.dart';
import '../models/app_notification.dart';
import '../models/task.dart';

class EventService {
  static FirebaseFirestore? _override;
  static FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @visibleForTesting
  static set database(FirebaseFirestore db) => _override = db;
  @visibleForTesting
  static void resetDatabase() => _override = null;

  static CollectionReference<Map<String, dynamic>> get events =>
      _db.collection('events');

  static CollectionReference<Map<String, dynamic>> tasks(String eventId) =>
      _db.collection('events').doc(eventId).collection('tasks');

  static Future<DocumentReference<Map<String, dynamic>>> createEvent(
    Map<String, dynamic> data,
  ) async {
    final ref = await events.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final sender = _senderContext();
    final title = data['title'] as String? ?? 'Event';
    final kind = data['kind'] as String? ?? 'event';
    final kindLabel = kind == 'meeting' ? 'meeting' : 'event';

    await _fireAndForget(() => NotificationsService.save(
          title: 'New $kindLabel: $title',
          body: (data['description'] as String?)?.isNotEmpty == true
              ? data['description'] as String
              : 'Tap to view details.',
          kind: AppNotificationKind.event,
          topic: AppConfig.topicAllMembers,
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: ref.id,
        ));
    await _fireAndForget(() => FcmService.sendToTopic(
          topic: AppConfig.topicAllMembers,
          title: 'New $kindLabel: $title',
          body: (data['venue'] as String?)?.isNotEmpty == true
              ? 'At ${data['venue']}'
              : 'Tap to view details.',
          data: {
            'kind': 'event',
            'eventId': ref.id,
          },
        ));
    await _fireAndForget(() => ReminderService.syncUpcoming());
    return ref;
  }

  static Future<void> updateEvent(
    String eventId,
    Map<String, dynamic> data,
  ) async {
    await events.doc(eventId).update(data);
    await _fireAndForget(() => ReminderService.syncUpcoming());
  }

  /// Deletes an event and every subcollection (tasks, attendance, gallery,
  /// wallet) so collection-group queries (My Tasks, Review Queue) don't
  /// surface orphaned children. Spark has no recursive-delete; we batch
  /// client-side in chunks of 400 to stay under the 500-op batch limit.
  ///
  /// Admins should always route delete through here — never call
  /// `events.doc(id).delete()` directly or use the Firebase Console.
  static Future<void> deleteEvent(String eventId) async {
    const subcollections = ['tasks', 'attendance', 'gallery', 'wallet'];
    for (final name in subcollections) {
      final col = events.doc(eventId).collection(name);
      while (true) {
        final snap = await col.limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (snap.docs.length < 400) break;
      }
    }
    await events.doc(eventId).delete();
    await _fireAndForget(() => ReminderService.syncUpcoming());
  }

  static Future<DocumentReference<Map<String, dynamic>>> addTask({
    required String eventId,
    required String eventTitle,
    required String title,
    required String description,
    required String assignedTo,
    required String assignedToName,
    required DateTime dueDate,
  }) async {
    // Pre-generate the task doc ID so we can atomically set the task and
    // bump the event's tasksCount inside a single transaction — a crash
    // between the two writes used to leave the counter stale forever.
    final ref = tasks(eventId).doc();
    await _db.runTransaction((tx) async {
      tx.set(ref, {
        'eventId': eventId,
        'eventTitle': eventTitle,
        'title': title,
        'description': description,
        'assignedTo': assignedTo,
        'assignedToName': assignedToName,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': taskStatusToString(TaskStatus.pending),
        'starsAwarded': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(events.doc(eventId), {
        'tasksCount': FieldValue.increment(1),
      });
    });

    final sender = _senderContext();
    await _fireAndForget(() => NotificationsService.save(
          title: 'New task: $title',
          body: 'From $eventTitle. Tap to view.',
          kind: AppNotificationKind.task,
          topic: FcmService.userTopic(assignedTo),
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: ref.id,
        ));
    await _fireAndForget(() => FcmService.sendToUser(
          uid: assignedTo,
          title: 'New task: $title',
          body: 'From $eventTitle. Tap to view.',
          data: {
            'kind': 'task',
            'eventId': eventId,
            'taskId': ref.id,
          },
        ));
    return ref;
  }

  static Future<void> submitProof({
    required String eventId,
    required String taskId,
    required String proofUrl,
    required ProofType proofType,
    String? memberNote,
  }) async {
    // Review metadata (reviewNote / reviewedBy / reviewedAt) is admin-only
    // per firestore.rules and intentionally left in place here. On a
    // resubmit-after-rejection the previous reviewNote stays until the
    // admin writes a new review — review UI should show it as "previous
    // feedback" and the admin overwrites when they approve/reject the
    // fresh submission.
    String taskTitle = 'a task';
    String eventTitle = 'an event';
    String assigneeName = 'A member';
    await _db.runTransaction((tx) async {
      final ref = tasks(eventId).doc(taskId);
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data() ?? {};
        taskTitle = data['title'] as String? ?? taskTitle;
        eventTitle = data['eventTitle'] as String? ?? eventTitle;
        assigneeName = data['assignedToName'] as String? ?? assigneeName;
      }
      tx.update(ref, {
        'proofUrl': proofUrl,
        'proofType': proofType == ProofType.image ? 'image' : 'pdf',
        'memberNote': memberNote,
        'status': taskStatusToString(TaskStatus.submitted),
        'submittedAt': FieldValue.serverTimestamp(),
      });
    });

    final sender = _senderContext();
    final submitterName = assigneeName.isNotEmpty ? assigneeName : sender.name;
    await _fireAndForget(() => NotificationsService.save(
          title: 'Proof submitted: $taskTitle',
          body: '$submitterName uploaded proof for "$taskTitle" ($eventTitle).',
          kind: AppNotificationKind.task,
          topic: AppConfig.topicAdmins,
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToTopic(
          topic: AppConfig.topicAdmins,
          title: 'Proof submitted: $taskTitle',
          body: '$submitterName uploaded proof. Tap to review.',
          data: {
            'kind': 'task',
            'eventId': eventId,
            'taskId': taskId,
          },
        ));
  }

  static Future<void> approveTask({
    required String eventId,
    required String taskId,
    required String reviewerUid,
    required String memberUid,
    String? reviewNote,
  }) async {
    String? taskTitle;
    await _db.runTransaction((tx) async {
      final taskRef = tasks(eventId).doc(taskId);

      final taskSnap = await tx.get(taskRef);
      if (!taskSnap.exists) throw Exception('Task not found');
      final currentStatus = taskSnap.data()?['status'] as String? ?? 'pending';
      if (currentStatus == 'approved') return;
      taskTitle = taskSnap.data()?['title'] as String?;

      tx.update(taskRef, {
        'status': taskStatusToString(TaskStatus.approved),
        'reviewedBy': reviewerUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': reviewNote,
        'starsAwarded': AppConfig.starsPerApprovedTask,
      });
      // Stars are derived live from approved tasks + attendance docs (see
      // StarsService). No write to users.stars is needed.
    });

    final sender = _senderContext();
    final displayTitle = taskTitle ?? 'your task';
    await _fireAndForget(() => NotificationsService.save(
          title: 'Task approved · +${AppConfig.starsPerApprovedTask} stars',
          body: '"$displayTitle" was approved. Stars added to your profile.',
          kind: AppNotificationKind.task,
          topic: FcmService.userTopic(memberUid),
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToUser(
          uid: memberUid,
          title: 'Task approved · +${AppConfig.starsPerApprovedTask} stars',
          body: '"$displayTitle" was approved.',
          data: {
            'kind': 'task',
            'eventId': eventId,
            'taskId': taskId,
          },
        ));
  }

  static Future<void> rejectTask({
    required String eventId,
    required String taskId,
    required String reviewerUid,
    required String reviewNote,
  }) async {
    // Capture assignee + title inside the transaction so the push body
    // always matches the doc we just wrote — a plain update followed by a
    // re-read has a small race window where a concurrent admin edit could
    // change the values between the write and the read.
    String? memberUid;
    String taskTitle = 'your task';
    await _db.runTransaction((tx) async {
      final taskRef = tasks(eventId).doc(taskId);
      final snap = await tx.get(taskRef);
      if (!snap.exists) throw Exception('Task not found');
      final data = snap.data() ?? {};
      memberUid = data['assignedTo'] as String?;
      taskTitle = data['title'] as String? ?? 'your task';
      tx.update(taskRef, {
        'status': taskStatusToString(TaskStatus.rejected),
        'reviewedBy': reviewerUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': reviewNote,
        'starsAwarded': 0,
      });
    });
    final assignee = memberUid;
    if (assignee == null) return;

    final sender = _senderContext();
    await _fireAndForget(() => NotificationsService.save(
          title: 'Needs resubmission',
          body: '"$taskTitle": $reviewNote',
          kind: AppNotificationKind.task,
          topic: FcmService.userTopic(assignee),
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToUser(
          uid: assignee,
          title: 'Needs resubmission',
          body: '"$taskTitle": $reviewNote',
          data: {
            'kind': 'task',
            'eventId': eventId,
            'taskId': taskId,
          },
        ));
  }

  // ────────────────────────────────────────────────────────────────────────
  //                    Due-date extension request flow
  // ────────────────────────────────────────────────────────────────────────
  //
  // Cost ladder: the Nth member-initiated request on a task costs N stars.
  // `extensionCount` increments at REQUEST time (not review time) so the cost
  // is locked into the doc before the admin sees it. Denied requests do not
  // refund stars. Admin-proactive extensions never increment this counter.

  /// Member-initiated extension request. Records the ask on the task; the
  /// star cost is derived live from the task's `extensionCount` (see
  /// [StarsService.balanceFor]).
  static Future<void> requestExtension({
    required String eventId,
    required String taskId,
    required String memberUid,
    required int requestedDays,
    required String reason,
  }) async {
    if (requestedDays < 1 || requestedDays > 4) {
      throw ArgumentError('requestedDays must be 1..4');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('reason is required');
    }

    // Affordability is a live calculation (earned − spent), so it cannot
    // happen inside a Firestore transaction (no collectionGroup support).
    // We check it before opening the transaction; the transaction itself
    // re-reads the task to enforce per-task atomicity.
    final balance = await StarsService.balanceFor(memberUid);

    String taskTitle = 'your task';
    int cost = 0;
    await _db.runTransaction((tx) async {
      final taskRef = tasks(eventId).doc(taskId);
      final taskSnap = await tx.get(taskRef);
      if (!taskSnap.exists) throw Exception('Task not found');

      final data = taskSnap.data() ?? {};
      if (data['assignedTo'] != memberUid) {
        throw Exception('Only the assigned member can request an extension.');
      }
      final status = data['status'] as String? ?? 'pending';
      if (status != 'pending' && status != 'rejected') {
        throw Exception('This task is not open for extension.');
      }
      final extStatus = data['extensionStatus'] as String?;
      if (extStatus == 'pending') {
        throw Exception('You already have a pending request on this task.');
      }
      // If an earlier extension was approved and is still within its window,
      // there's nothing to extend further (member still has time).
      if (extStatus == 'approved') {
        final until = (data['extensionGrantedUntil'] as Timestamp?)?.toDate();
        if (until != null && DateTime.now().isBefore(until)) {
          throw Exception('Current extension is still active.');
        }
      }

      taskTitle = data['title'] as String? ?? taskTitle;
      final count = (data['extensionCount'] as num?)?.toInt() ?? 0;
      cost = count + 1;
      if (balance < cost) {
        throw Exception('Not enough stars. Need $cost, you have $balance.');
      }

      tx.update(taskRef, {
        'extensionStatus': extensionStatusToString(ExtensionStatus.pending),
        'extensionRequestedAt': FieldValue.serverTimestamp(),
        'extensionReason': reason.trim(),
        'extensionRequestedDays': requestedDays,
        'extensionAdminInitiated': false,
        'extensionStarCost': cost,
        'extensionCount': count + 1,
        // Clear prior review fields so the admin UI doesn't show stale state.
        'extensionGrantedUntil': null,
        'extensionGrantedDays': null,
        'extensionReviewedBy': null,
        'extensionReviewedAt': null,
        'extensionReviewNote': null,
      });
    });

    final sender = _senderContext();
    await _fireAndForget(() => NotificationsService.save(
          title: 'Extension requested: $taskTitle',
          body: '${sender.name} asked for $requestedDays day(s) '
              '(cost: -$cost stars). Tap to review.',
          kind: AppNotificationKind.task,
          topic: AppConfig.topicAdmins,
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToTopic(
          topic: AppConfig.topicAdmins,
          title: 'Extension requested: $taskTitle',
          body: '${sender.name} asked for $requestedDays day(s). Tap to review.',
          data: {'kind': 'task', 'eventId': eventId, 'taskId': taskId},
        ));
  }

  /// Admin approves a pending extension request.
  /// New effective due = original `dueDate + grantedDays`. If status was
  /// `rejected`, flip it back to `pending` so the member lands on the upload
  /// form.
  static Future<void> approveExtension({
    required String eventId,
    required String taskId,
    required String reviewerUid,
    required int grantedDays,
    String? reviewNote,
  }) async {
    if (grantedDays < 1 || grantedDays > 4) {
      throw ArgumentError('grantedDays must be 1..4');
    }
    String? memberUid;
    String taskTitle = 'your task';
    DateTime? newDue;
    await _db.runTransaction((tx) async {
      final taskRef = tasks(eventId).doc(taskId);
      final snap = await tx.get(taskRef);
      if (!snap.exists) throw Exception('Task not found');
      final data = snap.data() ?? {};
      if ((data['extensionStatus'] as String?) != 'pending') {
        throw Exception('No pending extension on this task.');
      }
      memberUid = data['assignedTo'] as String?;
      taskTitle = data['title'] as String? ?? taskTitle;
      final baseDue = (data['dueDate'] as Timestamp?)?.toDate();
      if (baseDue == null) {
        throw Exception('Task has no due date to extend.');
      }
      newDue = baseDue.add(Duration(days: grantedDays));

      final updates = <String, dynamic>{
        'extensionStatus': extensionStatusToString(ExtensionStatus.approved),
        'extensionGrantedDays': grantedDays,
        'extensionGrantedUntil': Timestamp.fromDate(newDue!),
        'extensionReviewedBy': reviewerUid,
        'extensionReviewedAt': FieldValue.serverTimestamp(),
        'extensionReviewNote': reviewNote,
      };
      // Reopen a rejected task so the member can upload again.
      if ((data['status'] as String?) == 'rejected') {
        updates['status'] = taskStatusToString(TaskStatus.pending);
      }
      tx.update(taskRef, updates);
    });

    final assignee = memberUid;
    if (assignee == null || newDue == null) return;
    final sender = _senderContext();
    await _fireAndForget(() => NotificationsService.save(
          title: 'Extension approved · +$grantedDays day(s)',
          body: '"$taskTitle": new due date is '
              '${newDue!.toIso8601String().split('T').first}.',
          kind: AppNotificationKind.task,
          topic: FcmService.userTopic(assignee),
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToUser(
          uid: assignee,
          title: 'Extension approved · +$grantedDays day(s)',
          body: '"$taskTitle": new due date '
              '${newDue!.toIso8601String().split('T').first}.',
          data: {'kind': 'task', 'eventId': eventId, 'taskId': taskId},
        ));
  }

  /// Admin denies a pending extension request. Stars are NOT refunded.
  static Future<void> denyExtension({
    required String eventId,
    required String taskId,
    required String reviewerUid,
    required String reviewNote,
  }) async {
    String? memberUid;
    String taskTitle = 'your task';
    await _db.runTransaction((tx) async {
      final taskRef = tasks(eventId).doc(taskId);
      final snap = await tx.get(taskRef);
      if (!snap.exists) throw Exception('Task not found');
      final data = snap.data() ?? {};
      if ((data['extensionStatus'] as String?) != 'pending') {
        throw Exception('No pending extension on this task.');
      }
      memberUid = data['assignedTo'] as String?;
      taskTitle = data['title'] as String? ?? taskTitle;
      tx.update(taskRef, {
        'extensionStatus': extensionStatusToString(ExtensionStatus.denied),
        'extensionReviewedBy': reviewerUid,
        'extensionReviewedAt': FieldValue.serverTimestamp(),
        'extensionReviewNote': reviewNote,
      });
    });

    final assignee = memberUid;
    if (assignee == null) return;
    final sender = _senderContext();
    await _fireAndForget(() => NotificationsService.save(
          title: 'Extension denied',
          body: '"$taskTitle": $reviewNote',
          kind: AppNotificationKind.task,
          topic: FcmService.userTopic(assignee),
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToUser(
          uid: assignee,
          title: 'Extension denied',
          body: '"$taskTitle": $reviewNote',
          data: {'kind': 'task', 'eventId': eventId, 'taskId': taskId},
        ));
  }

  /// Admin-initiated extension. No member request, no star cost, does not
  /// count against the cost ladder. Works on any task regardless of current
  /// extension state — if there was a pending member request, this implicitly
  /// resolves it as admin-approved.
  static Future<void> adminExtendTask({
    required String eventId,
    required String taskId,
    required String reviewerUid,
    required int grantedDays,
    String? reviewNote,
  }) async {
    if (grantedDays < 1 || grantedDays > 4) {
      throw ArgumentError('grantedDays must be 1..4');
    }
    String? memberUid;
    String taskTitle = 'your task';
    DateTime? newDue;
    await _db.runTransaction((tx) async {
      final taskRef = tasks(eventId).doc(taskId);
      final snap = await tx.get(taskRef);
      if (!snap.exists) throw Exception('Task not found');
      final data = snap.data() ?? {};
      memberUid = data['assignedTo'] as String?;
      taskTitle = data['title'] as String? ?? taskTitle;
      final baseDue = (data['dueDate'] as Timestamp?)?.toDate();
      if (baseDue == null) {
        throw Exception('Task has no due date to extend.');
      }
      newDue = baseDue.add(Duration(days: grantedDays));

      final updates = <String, dynamic>{
        'extensionStatus': extensionStatusToString(ExtensionStatus.approved),
        'extensionAdminInitiated': true,
        'extensionGrantedDays': grantedDays,
        'extensionGrantedUntil': Timestamp.fromDate(newDue!),
        'extensionReviewedBy': reviewerUid,
        'extensionReviewedAt': FieldValue.serverTimestamp(),
        'extensionReviewNote': reviewNote,
        // No change to extensionCount — admin kindness shouldn't punish the
        // member's next request cost.
      };
      if ((data['status'] as String?) == 'rejected') {
        updates['status'] = taskStatusToString(TaskStatus.pending);
      }
      tx.update(taskRef, updates);
    });

    final assignee = memberUid;
    if (assignee == null || newDue == null) return;
    final sender = _senderContext();
    await _fireAndForget(() => NotificationsService.save(
          title: 'Admin extended your task · +$grantedDays day(s)',
          body: '"$taskTitle": new due date is '
              '${newDue!.toIso8601String().split('T').first}.',
          kind: AppNotificationKind.task,
          topic: FcmService.userTopic(assignee),
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToUser(
          uid: assignee,
          title: 'Admin extended your task · +$grantedDays day(s)',
          body: '"$taskTitle": new due date '
              '${newDue!.toIso8601String().split('T').first}.',
          data: {'kind': 'task', 'eventId': eventId, 'taskId': taskId},
        ));
  }

  /// Push / inbox writes are side-effects; don't fail the primary Firestore
  /// action if the push fails (e.g. offline, SA missing in dev).
  static Future<void> _fireAndForget(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      if (kDebugMode) debugPrint('[event_service] side-effect failed: $e');
    }
  }

  static ({String uid, String name}) _senderContext() {
    // Guarded — unit tests run without a FirebaseAuth instance and would
    // otherwise blow up at the top of approve/reject/addTask.
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (
        uid: u?.uid ?? '',
        name: u?.displayName ??
            (u?.email?.split('@').first ?? 'Admin'),
      );
    } catch (_) {
      return (uid: '', name: 'Admin');
    }
  }
}
