import 'package:cloud_firestore/cloud_firestore.dart';

enum EventStatus { upcoming, ongoing, done }

EventStatus _parseStatus(String? raw) {
  switch (raw) {
    case 'ongoing':
      return EventStatus.ongoing;
    case 'done':
      return EventStatus.done;
    case 'upcoming':
    default:
      return EventStatus.upcoming;
  }
}

String eventStatusToString(EventStatus s) => s.name;

class AgaramEvent {
  final String id;
  final String title;
  final String description;
  final String venue;
  final DateTime date;
  final String? bannerUrl;
  final String createdBy;
  final EventStatus status;
  final int tasksCount;

  /// `'event'` (default) or `'meeting'`. Meetings reuse the same attendance
  /// and QR flow but the UI hides the banner field.
  final String kind;

  /// Expected duration in minutes — used to close the QR attendance window
  /// after the session ends. Defaults to 120 minutes when unset.
  final int durationMinutes;

  const AgaramEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.date,
    required this.createdBy,
    required this.status,
    required this.tasksCount,
    this.bannerUrl,
    this.kind = 'event',
    this.durationMinutes = 120,
  });

  bool get isMeeting => kind == 'meeting';

  /// When the QR attendance window opens (3 hours before the scheduled start).
  DateTime get attendanceWindowOpensAt =>
      date.subtract(const Duration(hours: 3));

  /// When the QR attendance window closes (after the scheduled end).
  DateTime get attendanceWindowClosesAt =>
      date.add(Duration(minutes: durationMinutes));

  bool isAttendanceOpenAt(DateTime now) =>
      !now.isBefore(attendanceWindowOpensAt) &&
      !now.isAfter(attendanceWindowClosesAt);

  factory AgaramEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AgaramEvent(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      venue: data['venue'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      tasksCount: (data['tasksCount'] as num?)?.toInt() ?? 0,
      bannerUrl: data['bannerUrl'] as String?,
      kind: data['kind'] as String? ?? 'event',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 120,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'venue': venue,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'status': eventStatusToString(status),
      'tasksCount': tasksCount,
      'kind': kind,
      'durationMinutes': durationMinutes,
      if (bannerUrl != null) 'bannerUrl': bannerUrl,
    };
  }
}
