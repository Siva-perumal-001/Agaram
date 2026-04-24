import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/kural_service.dart';
import '../../core/notifications_service.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/kural.dart';
import '../../widgets/agaram_logo.dart';
import '../../widgets/event_preview_card.dart';
import '../../widgets/kural_card.dart';
import '../../widgets/star_card.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../notifications/notifications_inbox_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  late final Future<Kural> _kuralFuture;

  @override
  void initState() {
    super.initState();
    _kuralFuture = KuralService.todaysKural();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _greeting(user),
              const SizedBox(height: 18),
              _StarStreamCard(uid: user.uid),
              const SizedBox(height: 18),
              FutureBuilder<Kural>(
                future: _kuralFuture,
                builder: (_, snap) {
                  if (!snap.hasData) return const _SkeletonCard(height: 220);
                  return KuralCard(kural: snap.data!);
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upcoming Events',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () {}, // Wired in Phase 3 via bottom-nav
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _UpcomingEventsStrip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greeting(AppUser user) {
    final firstName = user.name.split(' ').first;
    final greetingStyle = GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AgaramColors.primary,
      height: 1.2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: greetingStyle,
            children: [
              TextSpan(
                text: 'Vanakkam, ${firstName.isEmpty ? 'friend' : firstName}',
              ),
              const TextSpan(text: '  '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  Icons.waving_hand_rounded,
                  size: 26,
                  color: AgaramColors.secondary,
                ),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'Welcome back to your club',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AgaramColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;
    return AppBar(
      backgroundColor: AgaramColors.surface,
      titleSpacing: 20,
      title: const AgaramWordmark(fontSize: 20),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _NotificationBell(uid: uid),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final String? uid;
  const _NotificationBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: uid == null
          ? const Stream.empty()
          : NotificationsService.unreadCount(uid!, isAdmin: false),
      builder: (_, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: AgaramColors.primary,
                size: 26,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsInboxScreen(),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: AgaramColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AgaramColors.surface, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StarStreamCard extends StatelessWidget {
  final String uid;
  const _StarStreamCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        final stars = (snap.data?.data()?['stars'] as num?)?.toInt() ?? 0;
        return StarCard(
          stars: stars,
          rank: null,
          onViewLeaderboard: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          ),
        );
      },
    );
  }
}

class _UpcomingEventsStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('events')
        .where('status', whereIn: ['upcoming', 'ongoing'])
        .orderBy('date')
        .limit(5)
        .snapshots();
    return SizedBox(
      height: 250,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _SkeletonCard(height: 250);
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const _EmptyEventsStrip();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final ts = d['date'];
              final date = ts is Timestamp ? ts.toDate() : DateTime.now();
              return EventPreviewCard(
                width: 280,
                title: (d['title'] as String?) ?? 'Untitled event',
                venue: (d['venue'] as String?) ?? 'TBA',
                date: date,
                tasksCount: (d['tasksCount'] as num?)?.toInt() ?? 0,
                bannerUrl: d['bannerUrl'] as String?,
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyEventsStrip extends StatelessWidget {
  const _EmptyEventsStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_note_rounded,
            color: AgaramColors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No upcoming events yet. Your admin will add some soon.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AgaramColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
