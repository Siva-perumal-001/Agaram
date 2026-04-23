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

  static Future<void> _ensureTimezone() async {
    if (_tzInitialized) return;
    tzdata.initializeTimeZones();
    // Use the device's local timezone offset. We don't need an exact IANA
    // match for inexact alarms; `tz.local` defaults to UTC which is fine
    // because we convert from DateTime via `tz.TZDateTime.from`.
    _tzInitialized = true;
  }

  /// Pull upcoming events, cancel stale reminders, and schedule fresh ones.
  /// Call on auth change, app resume, and when the events stream updates.
  static Future<void> syncUpcoming() async {
    await _ensureTimezone();

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: _lookaheadDays));

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await EventService.events
          .where('date', isGreaterThan: Timestamp.fromDate(now))
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
      final fireAt = starts.subtract(_leadTime);
      if (fireAt.isBefore(now)) continue;

      final id = doc.id.hashCode & 0x7fffffff;
      final title = 'Starts in 10 minutes';
      final body =
          '${data['title'] ?? 'Event'} · ${data['venue'] ?? 'TBA'}';

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
          payload: 'event:${doc.id}',
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[reminders] schedule failed for ${doc.id}: $e');
      }
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
