import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/stream_error_view.dart';
import '../../widgets/task_card.dart';
import 'task_detail_screen.dart';
import 'task_review_screen.dart';

class TasksTabScreen extends StatelessWidget {
  const TasksTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthService>().isAdmin;
    return isAdmin ? const _AdminReviewQueue() : const _MyTasks();
  }
}

class _MyTasks extends StatelessWidget {
  const _MyTasks();

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;
    final stream = uid == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
            .collectionGroup('tasks')
            .where('assignedTo', isEqualTo: uid)
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (_, snap) {
            if (snap.hasError) {
              return const StreamErrorView(
                message: "Couldn't load your tasks.",
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const _EmptyState(isAdmin: false);

            final tasks = docs.map(AgaramTask.fromFirestore).toList()
              ..sort((a, b) {
                final order = {
                  TaskStatus.pending: 0,
                  TaskStatus.rejected: 1,
                  TaskStatus.submitted: 2,
                  TaskStatus.approved: 3,
                };
                return (order[a.status] ?? 4).compareTo(order[b.status] ?? 4);
              });

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final t = tasks[i];
                return TaskCard(
                  task: t,
                  currentUid: uid,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(task: t),
                    ),
                  ),
                  onUploadProof: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(task: t),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AdminReviewQueue extends StatelessWidget {
  const _AdminReviewQueue();

  @override
  Widget build(BuildContext context) {
    final pendingStream = FirebaseFirestore.instance
        .collectionGroup('tasks')
        .where('status', isEqualTo: 'submitted')
        .snapshots();
    final reviewedStream = FirebaseFirestore.instance
        .collectionGroup('tasks')
        .where('status', whereIn: ['approved', 'rejected'])
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: pendingStream,
          builder: (_, pendingSnap) {
            if (pendingSnap.hasError) {
              return const StreamErrorView(
                message: "Couldn't load the review queue.",
              );
            }
            final pending =
                (pendingSnap.data?.docs ?? []).map(AgaramTask.fromFirestore).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: reviewedStream,
                  builder: (_, revSnap) {
                    final reviewed = revSnap.data?.docs.length ?? 0;
                    return _summary(pending.length, reviewed);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pending Submissions',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AgaramColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      'Newest First',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AgaramColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const _EmptyState(isAdmin: true)
                else
                  ...pending.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReviewQueueCard(
                        task: t,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TaskReviewScreen(task: t),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summary(int pending, int reviewed) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pending tasks pending',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AgaramColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$reviewed reviewed this month',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AgaramColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AgaramColors.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Admin Stats',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AgaramColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewQueueCard extends StatelessWidget {
  final AgaramTask task;
  final VoidCallback onOpen;
  const _ReviewQueueCard({required this.task, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final initial = task.assignedToName.isEmpty
        ? 'A'
        : task.assignedToName[0].toUpperCase();
    final submitted = task.submittedAt == null
        ? 'recently'
        : _timeAgo(task.submittedAt!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AgaramColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AgaramColors.primaryContainer,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AgaramColors.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: task.assignedToName.isEmpty
                                ? 'Member'
                                : task.assignedToName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' submitted '),
                          TextSpan(
                            text: '"${task.title}"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.eventTitle} · $submitted',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AgaramColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: task.status),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Review'),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAdmin;
  const _EmptyState({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAdmin
                  ? Icons.check_circle_outline_rounded
                  : Icons.task_alt_rounded,
              size: 64,
              color: AgaramColors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isAdmin ? 'All caught up!' : 'No tasks yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              isAdmin
                  ? 'Nothing is waiting for your review right now.'
                  : 'Your admin hasn’t assigned tasks to you yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AgaramColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
