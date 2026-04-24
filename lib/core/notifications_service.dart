import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'app_config.dart';
import 'fcm_service.dart';

/// `topic` records who the notification was sent to. Inbox display and unread
/// count must mirror the FCM audience: broadcast for `all_members`, only the
/// matching uid for `user_<uid>`, only admins for `admins_only`. Unknown topics
/// fall through as broadcast so legitimate notifications are never silently
/// hidden.
bool isNotificationForViewer(AppNotification n, String? uid, bool isAdmin) {
  final topic = n.topic;
  if (topic.startsWith('user_')) {
    return uid != null && topic == FcmService.userTopic(uid);
  }
  if (topic == AppConfig.topicAdmins) return isAdmin;
  return true;
}

class NotificationsService {
  static FirebaseFirestore? _override;
  static FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @visibleForTesting
  static set database(FirebaseFirestore db) => _override = db;
  @visibleForTesting
  static void resetDatabase() => _override = null;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  static Stream<QuerySnapshot<Map<String, dynamic>>> stream() {
    return _col.orderBy('sentAt', descending: true).limit(100).snapshots();
  }

  static Future<String> save({
    required String title,
    required String body,
    required AppNotificationKind kind,
    required String topic,
    required String sentBy,
    required String sentByName,
    String? eventId,
    String? taskId,
  }) async {
    final ref = await _col.add({
      'title': title,
      'body': body,
      'kind': kindToString(kind),
      'topic': topic,
      'sentBy': sentBy,
      'sentByName': sentByName,
      'sentAt': FieldValue.serverTimestamp(),
      'eventId': ?eventId,
      'taskId': ?taskId,
    });
    return ref.id;
  }

  static Future<void> markAllRead(String uid) {
    return _db.collection('users').doc(uid).set(
      {'lastReadNotificationsAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  static Stream<int> unreadCount(String uid, {required bool isAdmin}) {
    // Only re-fetch when `lastReadNotificationsAt` actually moves — unrelated
    // user-doc changes (stars, phone, photo) used to re-fire this query on
    // every write and burn Firestore reads.
    final lastReadStream = _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) =>
            (s.data()?['lastReadNotificationsAt'] as Timestamp?)?.toDate())
        .distinct();
    return lastReadStream.asyncMap((lastRead) async {
      // We can't use a count() aggregate here because audience filtering by
      // `topic` happens client-side (avoids a composite index on topic+sentAt).
      // Cap at 100 so a long backlog can't blow up reads — UI shows "99+".
      final query = lastRead == null
          ? _col.orderBy('sentAt', descending: true).limit(100)
          : _col
              .where('sentAt', isGreaterThan: Timestamp.fromDate(lastRead))
              .orderBy('sentAt', descending: true)
              .limit(100);
      final snap = await query.get();
      return snap.docs
          .map(AppNotification.fromFirestore)
          .where((n) => isNotificationForViewer(n, uid, isAdmin))
          .length;
    });
  }
}
