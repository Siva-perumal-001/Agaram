// One-off admin query: lists every doc in the `users` collection and prints
// uid, name, email, role, position, isPresident, active. Uses the bundled
// service account JSON. Run with: dart run tool/list_users.dart
//
// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final saPath = '${Directory.current.path}/assets/fcm-service-account.json';
  final raw = File(saPath).readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is Map && decoded['_placeholder'] == true) {
    print('Service account is the placeholder — fill in the real key first.');
    exit(1);
  }
  final creds = ServiceAccountCredentials.fromJson(decoded);
  final projectId = (decoded as Map)['project_id'] as String;

  final client = await clientViaServiceAccount(creds, const [
    'https://www.googleapis.com/auth/datastore',
  ]);
  try {
    final url =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users?pageSize=200';
    final resp = await client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      print('Firestore returned ${resp.statusCode}: ${resp.body}');
      exit(1);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List?) ?? const [];
    if (docs.isEmpty) {
      print('No users found in Firestore.');
      return;
    }
    print('Found ${docs.length} user${docs.length == 1 ? '' : 's'}:\n');
    for (final d in docs) {
      final doc = d as Map<String, dynamic>;
      final name = (doc['name'] as String?)?.split('/').last ?? '?';
      final fields = (doc['fields'] as Map<String, dynamic>?) ?? {};
      String? str(String key) =>
          (fields[key] as Map<String, dynamic>?)?['stringValue'] as String?;
      bool? boolv(String key) =>
          (fields[key] as Map<String, dynamic>?)?['booleanValue'] as bool?;

      print('UID:        $name');
      print('  name:       ${str('name') ?? '—'}');
      print('  email:      ${str('email') ?? '—'}');
      print('  role:       ${str('role') ?? '—'}');
      print('  position:   ${str('position') ?? '—'}');
      print('  isPresident:${boolv('isPresident') ?? false}');
      print('  active:     ${boolv('active') ?? true}');
      print('');
    }
  } on http.ClientException catch (e) {
    print('Network error: $e');
    exit(1);
  } finally {
    client.close();
  }
}
