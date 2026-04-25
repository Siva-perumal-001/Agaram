import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import 'app_config.dart';

/// Single source of truth for stars.
///
/// Display, achievement gates, leaderboard ordering, and extension-request
/// affordability all derive from the same underlying records:
///   earned  = approved tasks * [AppConfig.starsPerApprovedTask]
///           + attendance docs * [AppConfig.starsPerAttendance]
///   spent   = sum, over the member's tasks, of N*(N+1)/2 where N =
///             extensionCount. (Cost ladder in EventService.requestExtension
///             is `prevCount + 1`, so total paid on a task with N requests is
///             1 + 2 + ... + N.)
///   balance = earned - spent
///
/// `users.stars` is no longer read or written by any feature. The field can
/// remain on legacy user docs without effect.
class StarsService {
  static FirebaseFirestore? _override;
  static FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  static set database(FirebaseFirestore db) => _override = db;
  static void resetDatabase() => _override = null;

  static Query<Map<String, dynamic>> approvedTasksQuery(String uid) =>
      _db.collectionGroup('tasks')
          .where('assignedTo', isEqualTo: uid)
          .where('status', isEqualTo: 'approved');

  static Query<Map<String, dynamic>> assignedTasksQuery(String uid) =>
      _db.collectionGroup('tasks').where('assignedTo', isEqualTo: uid);

  static Query<Map<String, dynamic>> attendanceQuery(String uid) =>
      _db.collectionGroup('attendance').where('userId', isEqualTo: uid);

  /// Stars spent on past extension requests on a single task doc.
  /// Mirrors the cost ladder in [requestExtension] (k-th request costs k).
  static int spentOnTaskDoc(Map<String, dynamic> data) {
    final ec = (data['extensionCount'] as num?)?.toInt() ?? 0;
    return ec > 0 ? (ec * (ec + 1)) ~/ 2 : 0;
  }

  static Future<int> earnedFor(String uid) async {
    final results = await Future.wait([
      approvedTasksQuery(uid).get(),
      attendanceQuery(uid).get(),
    ]);
    return results[0].docs.length * AppConfig.starsPerApprovedTask +
        results[1].docs.length * AppConfig.starsPerAttendance;
  }

  /// Live spendable balance: earned minus all extension costs paid.
  /// Used as the affordability check in extension requests.
  static Future<int> balanceFor(String uid) async {
    final tasksSnap = await assignedTasksQuery(uid).get();
    final attSnap = await attendanceQuery(uid).get();
    var earned = 0;
    var spent = 0;
    for (final d in tasksSnap.docs) {
      final data = d.data();
      if (data['status'] == 'approved') {
        earned += AppConfig.starsPerApprovedTask;
      }
      spent += spentOnTaskDoc(data);
    }
    earned += attSnap.docs.length * AppConfig.starsPerAttendance;
    return earned - spent;
  }
}

/// Subscribes to a user's approved tasks and attendance and rebuilds
/// [builder] with the live earned-stars total.
class LiveStarsBuilder extends StatelessWidget {
  final String uid;
  final Widget Function(BuildContext context, int stars) builder;

  const LiveStarsBuilder({
    super.key,
    required this.uid,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: StarsService.approvedTasksQuery(uid).snapshots(),
      builder: (_, taskSnap) {
        final taskCount = taskSnap.data?.docs.length ?? 0;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: StarsService.attendanceQuery(uid).snapshots(),
          builder: (context, attSnap) {
            final attCount = attSnap.data?.docs.length ?? 0;
            final stars = taskCount * AppConfig.starsPerApprovedTask +
                attCount * AppConfig.starsPerAttendance;
            return builder(context, stars);
          },
        );
      },
    );
  }
}

/// Subscribes to a user's tasks and attendance and rebuilds [builder] with
/// the live spendable balance (earned minus extension costs paid).
class LiveBalanceBuilder extends StatelessWidget {
  final String uid;
  final Widget Function(BuildContext context, int balance) builder;

  const LiveBalanceBuilder({
    super.key,
    required this.uid,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: StarsService.assignedTasksQuery(uid).snapshots(),
      builder: (_, taskSnap) {
        var earned = 0;
        var spent = 0;
        for (final d in taskSnap.data?.docs ?? const []) {
          final data = d.data();
          if (data['status'] == 'approved') {
            earned += AppConfig.starsPerApprovedTask;
          }
          spent += StarsService.spentOnTaskDoc(data);
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: StarsService.attendanceQuery(uid).snapshots(),
          builder: (context, attSnap) {
            final attCount = attSnap.data?.docs.length ?? 0;
            final balance =
                earned + attCount * AppConfig.starsPerAttendance - spent;
            return builder(context, balance);
          },
        );
      },
    );
  }
}
