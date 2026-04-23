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
  final String? monthlyTheme;
  final String createdBy;
  final EventStatus status;
  final int tasksCount;

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
    this.monthlyTheme,
  });

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
      monthlyTheme: data['monthlyTheme'] as String?,
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
      if (bannerUrl != null) 'bannerUrl': bannerUrl,
      if (monthlyTheme != null) 'monthlyTheme': monthlyTheme,
    };
  }
}
