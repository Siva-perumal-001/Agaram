import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/attendance_service.dart';
import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../models/attendance.dart';
import '../../models/event.dart';
import '../attendance/qr_display_screen.dart';
import '../attendance/qr_scanner_screen.dart';

class AttendanceTab extends StatelessWidget {
  final AgaramEvent event;
  const AttendanceTab({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthService>().isAdmin;
    final uid = context.watch<AuthService>().currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AttendanceService.attendance(event.id).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final entries = docs.map(AttendanceEntry.fromFirestore).toList()
          ..sort((a, b) {
            final ad = a.checkedInAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = b.checkedInAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return ad.compareTo(bd);
          });
        final meChecked = uid != null && entries.any((e) => e.userId == uid);
        final mine = uid == null
            ? null
            : entries.cast<AttendanceEntry?>().firstWhere(
                  (e) => e?.userId == uid,
                  orElse: () => null,
                );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryStrip(entries.length),
            const SizedBox(height: 16),
            if (isAdmin)
              _adminCard(context)
            else if (meChecked && mine != null)
              _memberChecked(context, mine)
            else
              _memberCheckIn(context),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _attendeesHeader(entries.length),
              const SizedBox(height: 12),
              _attendeesList(context, entries),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryStrip(int checkedIn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$checkedIn checked in',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AgaramColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  checkedIn == 0
                      ? 'No one has arrived yet'
                      : 'Session attendance is live',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AgaramColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AgaramColors.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 14),
                const SizedBox(width: 4),
                Text(
                  '+2 stars each',
                  style: GoogleFonts.inter(
                    fontSize: 11,
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

  Widget _memberCheckIn(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AgaramColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AgaramColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              size: 40,
              color: AgaramColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Check in for this event',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AgaramColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Scan your admin's QR code at the venue to mark yourself present and earn +2 stars.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AgaramColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrScannerScreen()),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR to Check In'),
          ),
        ],
      ),
    );
  }

  Widget _memberChecked(BuildContext context, AttendanceEntry entry) {
    final when = entry.checkedInAt;
    final timeLabel = when == null ? 'earlier' : DateFormat('h:mm a').format(when);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF2E3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2E7D32),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're marked present",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Checked in at $timeLabel · +${entry.starsAwarded} stars added',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminCard(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AgaramColors.secondary,
        foregroundColor: Colors.white,
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrDisplayScreen(event: event),
        ),
      ),
      icon: const Icon(Icons.qr_code_rounded),
      label: const Text('Show Event QR'),
    );
  }

  Widget _attendeesHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Attendees ($count)',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AgaramColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _attendeesList(BuildContext context, List<AttendanceEntry> entries) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'No one checked in yet. Once members start scanning, they’ll appear here.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AgaramColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            _tile(entries[i]),
            if (i != entries.length - 1)
              const Divider(
                height: 1,
                color: AgaramColors.outlineVariant,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }

  Widget _tile(AttendanceEntry entry) {
    final initial = entry.userName.isEmpty
        ? '·'
        : entry.userName[0].toUpperCase();
    final when = entry.checkedInAt;
    final timeLabel = when == null ? '—' : DateFormat('h:mm a').format(when);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AgaramColors.primaryContainer,
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.userName.isEmpty ? 'Member' : entry.userName,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AgaramColors.onSurface,
              ),
            ),
          ),
          Text(
            timeLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AgaramColors.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              entry.method == AttendanceMethod.qr ? 'QR' : 'Manual',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AgaramColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
