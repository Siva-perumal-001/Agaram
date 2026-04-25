import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'event_service.dart';

/// Schedules local "starts in 10 minutes" notifications for upcoming events.
/// Works with the device offline and without a server.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _tzInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'agaram_event_reminders',
    'Event Reminders',
    description: 'Heads-up 10 minutes before each event starts.',
    importance: Importance.high,
  );

  static const Duration _leadTime = Duration(minutes: 10);
  static const int _lookaheadDays = 30;
  static const int _archiveLookbackDays = 3;
  static const Duration _archiveDelay = Duration(hours: 24);

  static Future<void> _ensureTimezone() async {
    if (_tzInitialized) return;
    tzdata.initializeTimeZones();
    // Use the device's local timezone offset. We don't need an exact IANA
    // match for inexact alarms; `tz.local` defaults to UTC which is fine
    // because we convert from DateTime via `tz.TZDateTime.from`.
    _tzInitialized = true;
  }

  /// Pull events from the relevant window, cancel stale reminders, and
  /// schedule fresh ones. Call on auth change, app resume, and when the
  /// events stream updates.
  ///
  /// Pass [isPresident] true to additionally schedule "archive to Drive"
  /// reminders 24h after each event ends. Other admins/members receive only
  /// the start-time reminder.
  static Future<void> syncUpcoming({bool isPresident = false}) async {
    await _ensureTimezone();

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: _lookaheadDays));
    // Look back so events that just ended (and whose 24h archive reminder
    // is therefore still in the future) make it into the result set.
    final lookback = now.subtract(const Duration(days: _archiveLookbackDays));

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await EventService.events
          .where('date', isGreaterThan: Timestamp.fromDate(lookback))
          .where('date', isLessThan: Timestamp.fromDate(horizon))
          .get();
    } catch (e) {
      // Offline / permission issue — bail quietly; next call will retry.
      if (kDebugMode) debugPrint('[reminders] list failed: $e');
      return;
    }

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);

    // Clear all previously scheduled reminders — we reschedule a fresh set.
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // cancelAll may fail on some platforms; ignore.
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = data['date'];
      if (ts is! Timestamp) continue;
      final starts = ts.toDate();
      final title = (data['title'] as String?) ?? 'Event';
      final venue = (data['venue'] as String?) ?? 'TBA';

      final startFireAt = starts.subtract(_leadTime);
      if (!startFireAt.isBefore(now)) {
        await _schedule(
          id: doc.id.hashCode & 0x7fffffff,
          fireAt: startFireAt,
          title: 'Starts in 10 minutes',
          body: '$title · $venue',
          payload: '{"kind":"event","eventId":"${doc.id}"}',
        );
      }

      if (isPresident && data['lastArchivedAt'] == null) {
        final duration =
            (data['durationMinutes'] as num?)?.toInt() ?? 120;
        final archiveFireAt =
            starts.add(Duration(minutes: duration)).add(_archiveDelay);
        if (!archiveFireAt.isBefore(now)) {
          await _schedule(
            id: 'archive-${doc.id}'.hashCode & 0x7fffffff,
            fireAt: archiveFireAt,
            title: 'Archive to Drive',
            body: 'Back up "$title" wallet docs to your Drive.',
            payload: '{"kind":"archive","eventId":"${doc.id}"}',
          );
        }
      }
    }
  }

  static Future<void> _schedule({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(fireAt, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[reminders] schedule failed: $e');
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
