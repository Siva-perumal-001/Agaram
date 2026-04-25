// One-off diagnostic: lists every approved task and attendance doc from
// the start of the current month, so we can see who earned the
// "club this month +N" stars on the admin dashboard.
//
// Run with: dart run tool/find_month_stars.dart
//
// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

Future<void> main() async {
  final saPath = '${Directory.current.path}/assets/fcm-service-account.json';
  final raw = File(saPath).readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final creds = ServiceAccountCredentials.fromJson(decoded);
  final projectId = decoded['project_id'] as String;

  final client = await clientViaServiceAccount(creds, const [
    'https://www.googleapis.com/auth/datastore',
  ]);

  try {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthStartIso = monthStart.toUtc().toIso8601String();
    print('Window: $monthStartIso to now (${now.toIso8601String()})\n');

    // Tasks (collectionGroup, approved this month)
    final tasksQuery = {
      'structuredQuery': {
        'from': [
          {'collectionId': 'tasks', 'allDescendants': true}
        ],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'status'},
                  'op': 'EQUAL',
                  'value': {'stringValue': 'approved'}
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'reviewedAt'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'timestampValue': monthStartIso}
                }
              }
            ]
          }
        }
      }
    };

    final attendanceQuery = {
      'structuredQuery': {
        'from': [
          {'collectionId': 'attendance', 'allDescendants': true}
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'checkedInAt'},
            'op': 'GREATER_THAN_OR_EQUAL',
            'value': {'timestampValue': monthStartIso}
          }
        }
      }
    };

    final url =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery';

    Future<List<Map<String, dynamic>>> run(Map<String, dynamic> body) async {
      final resp = await client.post(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode != 200) {
        print('runQuery failed (${resp.statusCode}): ${resp.body}');
        return [];
      }
      final list = jsonDecode(resp.body) as List;
      final docs = <Map<String, dynamic>>[];
      for (final entry in list) {
        if (entry is! Map<String, dynamic>) continue;
        final doc = entry['document'];
        if (doc is Map<String, dynamic>) docs.add(doc);
      }
      return docs;
    }

    String? sv(Map fields, String k) =>
        (fields[k] as Map?)?['stringValue'] as String?;
    String? tsv(Map fields, String k) =>
        (fields[k] as Map?)?['timestampValue'] as String?;

    print('--- Approved tasks this month ---');
    final tasks = await run(tasksQuery);
    if (tasks.isEmpty) print('(none)');
    for (final t in tasks) {
      final fields = (t['fields'] as Map?) ?? {};
      final pathParts = (t['name'] as String).split('/');
      final eventId = pathParts[pathParts.length - 3];
      final taskId = pathParts.last;
      print('  Task   : $taskId');
      print('    eventId    : $eventId');
      print('    title      : ${sv(fields, 'title') ?? '—'}');
      print('    assignedTo : ${sv(fields, 'assignedTo') ?? '—'}');
      print('    reviewedAt : ${tsv(fields, 'reviewedAt') ?? '—'}');
      print('    starsAwarded: ${(fields['starsAwarded'] as Map?)?['integerValue']}');
      print('');
    }

    print('--- Attendance this month ---');
    final atts = await run(attendanceQuery);
    if (atts.isEmpty) print('(none)');
    for (final a in atts) {
      final fields = (a['fields'] as Map?) ?? {};
      final pathParts = (a['name'] as String).split('/');
      final eventId = pathParts[pathParts.length - 3];
      print('  Attendance: ${pathParts.last}');
      print('    eventId    : $eventId');
      print('    userId     : ${sv(fields, 'userId') ?? '—'}');
      print('    userName   : ${sv(fields, 'userName') ?? '—'}');
      print('    checkedInAt: ${tsv(fields, 'checkedInAt') ?? '—'}');
      print('    method     : ${sv(fields, 'method') ?? '—'}');
      print('    starsAwarded: ${(fields['starsAwarded'] as Map?)?['integerValue']}');
      print('');
    }

    final taskStars = tasks.length; // 1 each
    final attStars = atts.length * 2; // 2 each
    print('Total club stars this month: ${taskStars + attStars}');
    print('  (${tasks.length} approved task × 1 + ${atts.length} attendance × 2)');
  } finally {
    client.close();
  }
}
