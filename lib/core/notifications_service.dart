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
    final userStream = _db.collection('users').doc(uid).snapshots();
    return userStream.asyncMap((userSnap) async {
      final lastRead =
          (userSnap.data()?['lastReadNotificationsAt'] as Timestamp?)?.toDate();
      final query = lastRead == null
          ? _col.orderBy('sentAt', descending: true).limit(50)
          : _col
              .where('sentAt', isGreaterThan: Timestamp.fromDate(lastRead))
              .limit(50);
      final snap = await query.get();
      return snap.docs.length;
    });
  }
}
