import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/notifications_service.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../widgets/notification_card.dart';
import '../../widgets/stream_error_view.dart';
import 'compose_notification_screen.dart';

enum _Filter { all, events, tasks, announcements }

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isAdmin = context.watch<AuthService>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => NotificationsService.markAllRead(user.uid),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  _chip('All', _Filter.all),
                  _chip('Events', _Filter.events),
                  _chip('Tasks', _Filter.tasks),
                  _chip('Announcements', _Filter.announcements),
                ],
              ),
            ),
            Expanded(
              child: _list(user?.uid, isAdmin),
            ),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AgaramColors.secondary,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ComposeNotificationScreen(),
                ),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Compose'),
            )
          : null,
    );
  }

  Widget _chip(String label, _Filter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AgaramColors.secondaryContainer
                : AgaramColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AgaramColors.secondary
                  : AgaramColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(String? uid, bool isAdmin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationsService.stream(),
      builder: (_, snap) {
        if (snap.hasError) {
          return StreamErrorView(
            message: "Couldn't load notifications.",
            error: snap.error,
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var items = (snap.data?.docs ?? [])
            .map(AppNotification.fromFirestore)
            .where((n) => isNotificationForViewer(n, uid, isAdmin))
            .toList();
        items = items.where(_matches).toList();

        if (items.isEmpty) return const _EmptyState();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uid == null
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
          builder: (_, userSnap) {
            final lastRead = (userSnap.data?.data()?['lastReadNotificationsAt']
                    as Timestamp?)
                ?.toDate();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = items[i];
                final unread = lastRead == null ||
                    (n.sentAt != null && n.sentAt!.isAfter(lastRead));
                return NotificationCard(notif: n, unread: unread);
              },
            );
          },
        );
      },
    );
  }

  bool _matches(AppNotification n) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.events:
        return n.kind == AppNotificationKind.event;
      case _Filter.tasks:
        return n.kind == AppNotificationKind.task;
      case _Filter.announcements:
        return n.kind == AppNotificationKind.announcement;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: AgaramColors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              "You're all caught up",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Nothing new right now. Announcements from your admin appear here.',
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
