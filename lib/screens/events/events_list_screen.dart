import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../widgets/event_preview_card.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

enum _Tab { upcoming, ongoing, past }

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  _Tab _tab = _Tab.upcoming;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthService>().isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.tune_rounded, color: AgaramColors.primary),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _segmented(),
            ),
            Expanded(child: _list()),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AgaramColors.secondary,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EventFormScreen(),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Event'),
            )
          : null,
    );
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _segment('Upcoming', _Tab.upcoming),
          _segment('Ongoing', _Tab.ongoing),
          _segment('Past', _Tab.past),
        ],
      ),
    );
  }

  Widget _segment(String label, _Tab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AgaramColors.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AgaramColors.primary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AgaramColors.primary
                  : AgaramColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final statusFilter = switch (_tab) {
      _Tab.upcoming => ['upcoming'],
      _Tab.ongoing => ['ongoing'],
      _Tab.past => ['done'],
    };
    final stream = FirebaseFirestore.instance
        .collection('events')
        .where('status', whereIn: statusFilter)
        .orderBy('date', descending: _tab == _Tab.past)
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final ts = d['date'];
            final date = ts is Timestamp ? ts.toDate() : DateTime.now();
            final eventId = docs[i].id;
            return EventPreviewCard(
              title: (d['title'] as String?) ?? 'Untitled event',
              venue: (d['venue'] as String?) ?? 'TBA',
              date: date,
              tasksCount: (d['tasksCount'] as num?)?.toInt() ?? 0,
              bannerUrl: d['bannerUrl'] as String?,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(eventId: eventId),
                ),
              ),
            );
          },
        );
      },
    );
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
              Icons.event_available_rounded,
              size: 64,
              color: AgaramColors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No events here yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Events show up here once they’re created.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
