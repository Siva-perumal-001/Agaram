import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'app_secrets.dart';

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
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
      _localInitialized = true;
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
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
