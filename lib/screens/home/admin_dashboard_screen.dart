import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../widgets/activity_item.dart';
import '../../widgets/agaram_logo.dart';
import '../../widgets/quick_action_card.dart';
import '../../widgets/stat_tile.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _greeting(user),
              const SizedBox(height: 18),
              const _StatsGrid(),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: QuickActionCard(
                      icon: Icons.add_rounded,
                      label: 'Create Event',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Create Event comes in Phase 3'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: _ReviewTasksAction()),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('View All')),
                ],
              ),
              const SizedBox(height: 4),
              _RecentActivityCard(),
              const SizedBox(height: 24),
              _quoteBlock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greeting(AppUser user) {
    final name = user.isPresident
        ? 'President'
        : (user.name.isEmpty ? 'Admin' : user.name.split(' ').first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Vanakkam, $name',
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AgaramColors.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            const Text('👑', style: TextStyle(fontSize: 28)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AgaramColors.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            user.isPresident ? 'President' : 'Admin',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AgaramColors.secondary,
            ),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AgaramColors.surface,
      titleSpacing: 20,
      title: const AgaramWordmark(fontSize: 20),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 20),
          child: Icon(
            Icons.notifications_none_rounded,
            color: AgaramColors.primary,
            size: 26,
          ),
        ),
      ],
    );
  }

  Widget _quoteBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AgaramColors.secondaryContainer, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"யாதும் ஊரே யாவரும் கேளிர்"',
            style: GoogleFonts.notoSerifTamil(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: AgaramColors.onSurface,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '— கணியன் பூங்குன்றனார்',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _liveCount(
          stream: firestore.collection('users').snapshots(),
          builder: (total) => StatTile(
            icon: Icons.people_alt_rounded,
            iconColor: AgaramColors.primary,
            label: 'Members',
            value: total.toString(),
          ),
        ),
        _liveCount(
          stream: firestore.collection('events').snapshots(),
          builder: (total) => StatTile(
            icon: Icons.event_rounded,
            iconColor: AgaramColors.secondary,
            label: 'Events',
            value: total.toString(),
            goldValue: true,
          ),
        ),
        _liveCount(
          stream: firestore
              .collectionGroup('tasks')
              .where('status', isEqualTo: 'submitted')
              .snapshots(),
          builder: (total) => StatTile(
            icon: Icons.fact_check_rounded,
            iconColor: AgaramColors.primary,
            label: 'Pending',
            value: total.toString(),
            showDot: total > 0,
          ),
        ),
        StatTile(
          icon: Icons.star_rounded,
          iconColor: AgaramColors.secondary,
          label: 'This month',
          value: '+0',
          goldValue: true,
        ),
      ],
    );
  }

  Widget _liveCount({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required Widget Function(int total) builder,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) => builder(snap.data?.docs.length ?? 0),
    );
  }
}

class _ReviewTasksAction extends StatelessWidget {
  const _ReviewTasksAction();

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collectionGroup('tasks')
        .where('status', isEqualTo: 'submitted')
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return QuickActionCard(
          icon: Icons.check_circle_outline_rounded,
          label: 'Review Tasks',
          filled: false,
          badge: count > 0 ? '$count pending' : null,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Review queue comes in Phase 3'),
              ),
            );
          },
        );
      },
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const ActivityItem(
            icon: Icons.auto_stories_rounded,
            iconBg: AgaramColors.secondaryContainer,
            iconColor: AgaramColors.secondary,
            actorName: 'No activity yet',
            actionText: '— member submissions and joins will appear here.',
            timeAgo: 'Phase 3 onwards',
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
