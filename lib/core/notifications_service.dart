import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

class NotificationsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  static Stream<int> unreadCount(String uid) {
    // Only re-fetch the notification count when `lastReadNotificationsAt`
    // actually moves — unrelated user-doc changes (stars, phone, photo)
    // used to re-fire this query on every write and burn Firestore reads.
    final lastReadStream = _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) =>
            (s.data()?['lastReadNotificationsAt'] as Timestamp?)?.toDate())
        .distinct();
    return lastReadStream.asyncMap((lastRead) async {
      // Aggregate .count() costs 1 read regardless of how many notifications
      // match — fixes the old bug where >50 unread capped the badge at 50
      // and ascending-ordered the wrong page.
      final query = lastRead == null
          ? _col
          : _col.where('sentAt', isGreaterThan: Timestamp.fromDate(lastRead));
      final agg = await query.count().get();
      return agg.count ?? 0;
    });
  }
}
