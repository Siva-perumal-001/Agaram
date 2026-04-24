// One-off admin cleanup: wipes every event plus its `tasks`, `attendance`,
// `wallet`, and `gallery` subcollections from Firestore. Uses the bundled
// service account JSON. Cloudinary assets are NOT touched — delete the
// `agaram/` folder from the Cloudinary dashboard separately.
//
// Dry run (shows counts, deletes nothing):
//   dart run tool/reset_event_data.dart
// Actually delete:
//   dart run tool/reset_event_data.dart --confirm
//
// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

const _subcollections = ['tasks', 'attendance', 'wallet', 'gallery'];

Future<void> main(List<String> args) async {
  final confirm = args.contains('--confirm');

  final saPath = '${Directory.current.path}/assets/fcm-service-account.json';
  final raw = File(saPath).readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is Map && decoded['_placeholder'] == true) {
    print('Service account is the placeholder — fill in the real key first.');
    exit(1);
  }
  final creds = ServiceAccountCredentials.fromJson(decoded);
  final projectId = (decoded as Map)['project_id'] as String;
  final base =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  final client = await clientViaServiceAccount(creds, const [
    'https://www.googleapis.com/auth/datastore',
  ]);
  try {
    print(confirm
        ? 'Running DELETE against project $projectId'
        : 'DRY RUN against project $projectId (pass --confirm to actually delete)\n');

    final events = await _listDocs(client, '$base/events');
    if (events.isEmpty) {
      print('No events found. Nothing to do.');
      return;
    }
    print('Found ${events.length} event${events.length == 1 ? '' : 's'}.\n');

    var subTotal = 0;
    for (final ev in events) {
      final name = ev['name'] as String; // projects/.../documents/events/{id}
      final id = name.split('/').last;
      print('• event $id');

      for (final sub in _subcollections) {
        final subDocs =
            await _listDocs(client, '$base/events/$id/$sub');
        print('    $sub: ${subDocs.length}');
        subTotal += subDocs.length;
        if (confirm) {
          for (final d in subDocs) {
            await _delete(client, d['name'] as String);
          }
        }
      }

      if (confirm) {
        await _delete(client, name);
      }
    }

    print('\nSummary:');
    print('  events:        ${events.length}');
    print('  subcol docs:   $subTotal');
    if (!confirm) {
      print('\nDry run — re-run with --confirm to delete.');
    } else {
      print('\nDone. Cloudinary assets under `agaram/` are untouched —'
          ' delete that folder from the Cloudinary dashboard.');
    }
  } on http.ClientException catch (e) {
    print('Network error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<List<Map<String, dynamic>>> _listDocs(
    http.Client client, String url) async {
  final out = <Map<String, dynamic>>[];
  String? pageToken;
  do {
    final uri = Uri.parse(url).replace(queryParameters: {
      'pageSize': '300',
      if (pageToken != null) 'pageToken': pageToken,
    });
    final resp = await client.get(uri);
    if (resp.statusCode == 404) return out; // collection doesn't exist
    if (resp.statusCode != 200) {
      throw StateError('List failed ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List?) ?? const [];
    for (final d in docs) {
      out.add(d as Map<String, dynamic>);
    }
    pageToken = body['nextPageToken'] as String?;
  } while (pageToken != null);
  return out;
}

Future<void> _delete(http.Client client, String docName) async {
  final uri = Uri.parse('https://firestore.googleapis.com/v1/$docName');
  final resp = await client.delete(uri);
  if (resp.statusCode != 200 && resp.statusCode != 204) {
    throw StateError('Delete failed for $docName — ${resp.statusCode}: ${resp.body}');
  }
}
