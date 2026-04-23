import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/event_service.dart';
import '../../core/theme.dart';
import '../../models/event.dart';
import '../../models/task.dart';
import '../../widgets/task_card.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_review_screen.dart';
import 'add_task_screen.dart';
import 'attendance_tab.dart';
import 'event_form_screen.dart';
import 'gallery_tab.dart';

enum _DetailTab { tasks, attendance, gallery }

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  _DetailTab _tab = _DetailTab.tasks;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthService>().isAdmin;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: EventService.events.doc(widget.eventId).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final event = AgaramEvent.fromFirestore(snap.data!);
          return CustomScrollView(
            slivers: [
              _EventHero(event: event, isAdmin: isAdmin),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EventInfoCard(event: event),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _about(event),
                      ],
                      const SizedBox(height: 20),
                      _tabsRow(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _tabContent(event),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      floatingActionButton: _fab(isAdmin),
    );
  }

  Widget _about(AgaramEvent event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this event',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AgaramColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          event.description,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AgaramColors.onSurface,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _tabsRow() {
    return Row(
      children: [
        _pill('Tasks', _DetailTab.tasks),
        const SizedBox(width: 8),
        _pill('Attendance', _DetailTab.attendance),
        const SizedBox(width: 8),
        _pill('Gallery', _DetailTab.gallery),
      ],
    );
  }

  Widget _pill(String label, _DetailTab target) {
    final selected = _tab == target;
    return GestureDetector(
      onTap: () => setState(() => _tab = target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AgaramColors.primaryContainer
              : AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AgaramColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _tabContent(AgaramEvent event) {
    switch (_tab) {
      case _DetailTab.tasks:
        return _TasksSliver(eventId: widget.eventId, eventTitle: event.title);
      case _DetailTab.attendance:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: AttendanceTab(event: event),
          ),
        );
      case _DetailTab.gallery:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: GalleryTab(eventId: widget.eventId),
          ),
        );
    }
  }

  Widget? _fab(bool isAdmin) {
    if (_tab != _DetailTab.tasks || !isAdmin) return null;
    return FloatingActionButton.extended(
      backgroundColor: AgaramColors.secondary,
      foregroundColor: Colors.white,
      onPressed: () async {
        final snap = await EventService.events.doc(widget.eventId).get();
        if (!snap.exists || !mounted) return;
        final ev = AgaramEvent.fromFirestore(snap);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddTaskScreen(event: ev)),
        );
      },
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Task'),
    );
  }
}

class _EventHero extends StatelessWidget {
  final AgaramEvent event;
  final bool isAdmin;
  const _EventHero({required this.event, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 280,
      backgroundColor: AgaramColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventFormScreen(existing: event),
                ),
              );
            },
          ),
        const IconButton(
          icon: Icon(Icons.share_rounded, color: Colors.white),
          onPressed: null,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: event.bannerUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AgaramColors.primaryContainer),
                errorWidget: (_, _, _) => _fallback(),
              )
            else
              _fallback(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Text(
                event.title,
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AgaramColors.primary, AgaramColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 80, color: Colors.white24),
      ),
    );
  }
}

class _EventInfoCard extends StatelessWidget {
  final AgaramEvent event;
  const _EventInfoCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AgaramColors.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.monthlyTheme != null && event.monthlyTheme!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AgaramColors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_monthLabel(event.monthlyTheme!)} theme',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AgaramColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _row(
            icon: Icons.calendar_today_rounded,
            label: DateFormat('MMMM d, yyyy').format(event.date),
            sub: '${DateFormat('h:mm a').format(event.date)} onwards',
          ),
          const SizedBox(height: 12),
          _row(
            icon: Icons.location_on_rounded,
            label: event.venue,
          ),
        ],
      ),
    );
  }

  Widget _row({required IconData icon, required String label, String? sub}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AgaramColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AgaramColors.onSurface,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AgaramColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _monthLabel(String yearMonth) {
    final parts = yearMonth.split('-');
    if (parts.length != 2) return yearMonth;
    final idx = int.tryParse(parts[1]) ?? 1;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[(idx - 1).clamp(0, 11)];
  }
}

class _TasksSliver extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  const _TasksSliver({required this.eventId, required this.eventTitle});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isAdmin = context.watch<AuthService>().isAdmin;
    final uid = user?.uid;

    Query<Map<String, dynamic>> query = EventService.tasks(eventId);
    if (!isAdmin && uid != null) {
      query = query.where('assignedTo', isEqualTo: uid);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: _EmptyTasks(isAdmin: isAdmin),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final task = AgaramTask.fromFirestore(docs[i]);
              return TaskCard(
                task: task,
                adminView: isAdmin,
                onTap: () => _openTask(context, task, isAdmin),
                onUploadProof: isAdmin
                    ? null
                    : () => _openTask(context, task, false),
              );
            },
          ),
        );
      },
    );
  }

  void _openTask(BuildContext context, AgaramTask task, bool admin) {
    if (admin && task.status == TaskStatus.submitted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskReviewScreen(task: task)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
      );
    }
  }
}

class _EmptyTasks extends StatelessWidget {
  final bool isAdmin;
  const _EmptyTasks({required this.isAdmin});

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
          const Icon(Icons.task_outlined, color: AgaramColors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAdmin
                  ? 'No tasks yet. Tap "Add Task" to assign one.'
                  : 'No tasks assigned to you for this event.',
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
