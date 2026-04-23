import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'fcm_service.dart';
import 'notifications_service.dart';
import 'reminder_service.dart';
import '../models/app_notification.dart';
import '../models/task.dart';

class EventService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get events =>
      _db.collection('events');

  static CollectionReference<Map<String, dynamic>> tasks(String eventId) =>
      events.doc(eventId).collection('tasks');

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

  static Future<DocumentReference<Map<String, dynamic>>> addTask({
    required String eventId,
    required String eventTitle,
    required String title,
    required String description,
    required String assignedTo,
    required String assignedToName,
    DateTime? dueDate,
  }) async {
    final ref = await tasks(eventId).add({
      'eventId': eventId,
      'eventTitle': eventTitle,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'status': taskStatusToString(TaskStatus.pending),
      'starsAwarded': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await events.doc(eventId).update({
      'tasksCount': FieldValue.increment(1),
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
  }) {
    return tasks(eventId).doc(taskId).update({
      'proofUrl': proofUrl,
      'proofType': proofType == ProofType.image ? 'image' : 'pdf',
      'memberNote': memberNote,
      'status': taskStatusToString(TaskStatus.submitted),
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewNote': null,
      'reviewedBy': null,
      'reviewedAt': null,
    });
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
      final userRef = _db.collection('users').doc(memberUid);

      final taskSnap = await tx.get(taskRef);
      if (!taskSnap.exists) throw Exception('Task not found');
      final currentStatus = taskSnap.data()?['status'] as String? ?? 'pending';
      if (currentStatus == 'approved') return;
      taskTitle = taskSnap.data()?['title'] as String?;

      final userSnap = await tx.get(userRef);
      final currentStars =
          (userSnap.data()?['stars'] as num?)?.toInt() ?? 0;

      tx.update(taskRef, {
        'status': taskStatusToString(TaskStatus.approved),
        'reviewedBy': reviewerUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': reviewNote,
        'starsAwarded': AppConfig.starsPerApprovedTask,
      });
      tx.update(userRef, {
        'stars': currentStars + AppConfig.starsPerApprovedTask,
      });
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
    await tasks(eventId).doc(taskId).update({
      'status': taskStatusToString(TaskStatus.rejected),
      'reviewedBy': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNote': reviewNote,
      'starsAwarded': 0,
    });

    final taskSnap = await tasks(eventId).doc(taskId).get();
    final taskData = taskSnap.data() ?? {};
    final memberUid = taskData['assignedTo'] as String?;
    final taskTitle = taskData['title'] as String? ?? 'your task';
    if (memberUid == null) return;

    final sender = _senderContext();
    await _fireAndForget(() => NotificationsService.save(
          title: 'Needs resubmission',
          body: '"$taskTitle": $reviewNote',
          kind: AppNotificationKind.task,
          topic: FcmService.userTopic(memberUid),
          sentBy: sender.uid,
          sentByName: sender.name,
          eventId: eventId,
          taskId: taskId,
        ));
    await _fireAndForget(() => FcmService.sendToUser(
          uid: memberUid,
          title: 'Needs resubmission',
          body: '"$taskTitle": $reviewNote',
          data: {
            'kind': 'task',
            'eventId': eventId,
            'taskId': taskId,
          },
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
    final u = FirebaseAuth.instance.currentUser;
    return (
      uid: u?.uid ?? '',
      name: u?.displayName ??
          (u?.email?.split('@').first ?? 'Admin'),
    );
  }
}
