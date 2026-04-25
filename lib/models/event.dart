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

/// Derived status from a date + duration, ignoring whatever value is stored
/// in the `status` field. The stored field is unreliable because the app has
/// no scheduled job to advance it past `'upcoming'`.
EventStatus effectiveEventStatus({
  required DateTime date,
  required int durationMinutes,
  required DateTime now,
}) {
  final end = date.add(Duration(minutes: durationMinutes));
  if (now.isBefore(date)) return EventStatus.upcoming;
  if (now.isAfter(end)) return EventStatus.done;
  return EventStatus.ongoing;
}

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

  /// Set the first time an admin archives this event's wallet docs to
  /// Google Drive. Drives the in-app banner and stops the local "archive
  /// reminder" notification from re-firing.
  final DateTime? lastArchivedAt;

  /// Number of wallet docs (pdfs + images) attached to this event,
  /// derived from the `walletCounts` map maintained by [WalletService].
  final int walletDocsCount;

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
    this.lastArchivedAt,
    this.walletDocsCount = 0,
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

  EventStatus effectiveStatus(DateTime now) => effectiveEventStatus(
        date: date,
        durationMinutes: durationMinutes,
        now: now,
      );

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
      lastArchivedAt: (data['lastArchivedAt'] as Timestamp?)?.toDate(),
      walletDocsCount: _walletDocsCountFrom(data),
    );
  }

  static int _walletDocsCountFrom(Map<String, dynamic> data) {
    final counts = data['walletCounts'] as Map<String, dynamic>?;
    if (counts == null) return 0;
    final pdfs = (counts['pdfs'] as num?)?.toInt() ?? 0;
    final images = (counts['images'] as num?)?.toInt() ?? 0;
    return pdfs + images;
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
