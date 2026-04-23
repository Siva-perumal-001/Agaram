import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_config.dart';
import '../models/task.dart';

class EventService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get events =>
      _db.collection('events');

  static CollectionReference<Map<String, dynamic>> tasks(String eventId) =>
      events.doc(eventId).collection('tasks');

  static Future<DocumentReference<Map<String, dynamic>>> createEvent(
    Map<String, dynamic> data,
  ) {
    return events.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateEvent(
    String eventId,
    Map<String, dynamic> data,
  ) {
    return events.doc(eventId).update(data);
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
    await _db.runTransaction((tx) async {
      final taskRef = tasks(eventId).doc(taskId);
      final userRef = _db.collection('users').doc(memberUid);

      final taskSnap = await tx.get(taskRef);
      if (!taskSnap.exists) throw Exception('Task not found');
      final currentStatus = taskSnap.data()?['status'] as String? ?? 'pending';
      if (currentStatus == 'approved') return;

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
  }

  static Future<void> rejectTask({
    required String eventId,
    required String taskId,
    required String reviewerUid,
    required String reviewNote,
  }) {
    return tasks(eventId).doc(taskId).update({
      'status': taskStatusToString(TaskStatus.rejected),
      'reviewedBy': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNote': reviewNote,
      'starsAwarded': 0,
    });
  }
}
