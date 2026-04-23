import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationKind { event, task, announcement }

AppNotificationKind _parseKind(String? raw) {
  switch (raw) {
    case 'event':
      return AppNotificationKind.event;
    case 'task':
      return AppNotificationKind.task;
    case 'announcement':
    default:
      return AppNotificationKind.announcement;
  }
}

String kindToString(AppNotificationKind k) => k.name;

class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationKind kind;
  final String topic;
  final String sentBy;
  final String sentByName;
  final DateTime? sentAt;
  final String? eventId;
  final String? taskId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.topic,
    required this.sentBy,
    required this.sentByName,
    this.sentAt,
    this.eventId,
    this.taskId,
  });

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      kind: _parseKind(data['kind'] as String?),
      topic: data['topic'] as String? ?? '',
      sentBy: data['sentBy'] as String? ?? '',
      sentByName: data['sentByName'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      eventId: data['eventId'] as String?,
      taskId: data['taskId'] as String?,
    );
  }
}
