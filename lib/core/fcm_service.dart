import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/tasks/task_detail_screen.dart';
import 'app_config.dart';
import 'app_secrets.dart';
import 'nav.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _localInitialized = false;
  static const _androidChannel = AndroidNotificationChannel(
    'agaram_default',
    'Agaram Notifications',
    description: 'Announcements, event updates, and task activity.',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> initOnStart() async {
    // Android 13+ needs runtime permission; iOS requests via default APNs prompt.
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (!_localInitialized) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (resp) =>
            handleTapPayload(resp.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
      _localInitialized = true;
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => handleTapPayload(jsonEncode(m.data)),
    );
    // Cold start — if the app was launched from a terminated-state push tap.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      handleTapPayload(jsonEncode(initial.data));
    }
  }

  static String userTopic(String uid) => 'user_$uid';

  static Future<void> subscribeForMember(String uid) async {
    await _messaging.subscribeToTopic(AppConfig.topicAllMembers);
    await _messaging.subscribeToTopic(userTopic(uid));
  }

  static Future<void> subscribeForAdmin(String uid) async {
    await _messaging.subscribeToTopic(AppConfig.topicAllMembers);
    await _messaging.subscribeToTopic(AppConfig.topicAdmins);
    await _messaging.subscribeToTopic(userTopic(uid));
  }

  static Future<void> unsubscribeAll({String? uid}) async {
    await _messaging.unsubscribeFromTopic(AppConfig.topicAllMembers);
    await _messaging.unsubscribeFromTopic(AppConfig.topicAdmins);
    if (uid != null) {
      await _messaging.unsubscribeFromTopic(userTopic(uid));
    }
  }

  static Future<void> sendToUser({
    required String uid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) {
    return sendToTopic(
      topic: userTopic(uid),
      title: title,
      body: body,
      data: data,
    );
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Parse `{kind, eventId, taskId}` from either a local-notification payload
  /// or an FCM data map and push the right screen.
  static Future<void> handleTapPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    final nav = AppNav.navigator;
    if (nav == null) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = decoded.cast<String, dynamic>();
      final eventId = data['eventId'] as String?;
      final taskId = data['taskId'] as String?;
      final kind = data['kind'] as String?;
      if (eventId == null || eventId.isEmpty) return;

      if (kind == 'task' && taskId != null && taskId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('tasks')
            .doc(taskId)
            .get();
        if (snap.exists) {
          final task = AgaramTask.fromFirestore(snap);
          await nav.push(
            MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
          );
          return;
        }
      }
      await nav.push(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: eventId),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] tap routing failed: $e');
    }
  }

  static Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final raw = await rootBundle.loadString(AppConfig.fcmServiceAccountAsset);
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['_placeholder'] == true) {
      throw FcmException(
        'Service account not configured. Replace assets/fcm-service-account.json '
        'with the key from Firebase Console.',
      );
    }
    final creds = ServiceAccountCredentials.fromJson(decoded);
    final client = await clientViaServiceAccount(creds, const [
      'https://www.googleapis.com/auth/firebase.messaging',
    ]);
    try {
      final url =
          'https://fcm.googleapis.com/v1/projects/${AppSecrets.firebaseProjectId}/messages:send';
      final response = await client.post(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': {
            'topic': topic,
            'notification': {'title': title, 'body': body},
            'data': ?data,
            'android': {
              'priority': 'HIGH',
              'notification': {'sound': 'default'},
            },
          },
        }),
      );
      if (response.statusCode != 200) {
        throw FcmException(
          'FCM returned ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw FcmException('Network error sending push: $e');
    } finally {
      client.close();
    }
  }

  static void debugLog(Object? o) {
    if (kDebugMode) debugPrint('[FCM] $o');
  }
}

class FcmException implements Exception {
  final String message;
  FcmException(this.message);
  @override
  String toString() => message;
}
