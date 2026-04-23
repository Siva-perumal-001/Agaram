import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/event_service.dart';
import '../../core/theme.dart';
import '../../models/event.dart';
import '../../widgets/stream_error_view.dart';
import 'wallet_event_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: EventService.events
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (_, snap) {
            if (snap.hasError) {
              return const StreamErrorView(
                message: "Couldn't load the wallet.",
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = (snap.data?.docs ?? [])
                .map(AgaramEvent.fromFirestore)
                .toList();
            final walletRaw = snap.data?.docs ?? [];
            int totalDocs = 0;
            final contributors = <String>{};
            for (final d in walletRaw) {
              final counts =
                  (d.data()['walletCounts'] as Map<String, dynamic>?) ?? const {};
              totalDocs += (counts['pdfs'] as num?)?.toInt() ?? 0;
              totalDocs += (counts['images'] as num?)?.toInt() ?? 0;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _intro(),
                const SizedBox(height: 16),
                _summary(totalDocs, events.length, contributors.length),
                const SizedBox(height: 20),
                if (events.isEmpty)
                  const _EmptyState()
                else
                  for (final e in events) ...[
                    _EventRow(
                      event: e,
                      raw: walletRaw.firstWhere((d) => d.id == e.id).data(),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AgaramColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AgaramColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Event Archive',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AgaramColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Share minutes, reports, and certificates seamlessly with the club community.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AgaramColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(int docs, int events, int contributors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill(
          '$docs ${docs == 1 ? 'doc' : 'docs'}',
          Icons.description_rounded,
        ),
        _pill(
          '$events ${events == 1 ? 'event' : 'events'}',
          Icons.calendar_today_rounded,
        ),
        _pill(
          '$contributors contributors',
          Icons.people_alt_rounded,
        ),
      ],
    );
  }

  Widget _pill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AgaramColors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AgaramColors.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AgaramColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final AgaramEvent event;
  final Map<String, dynamic> raw;
  const _EventRow({required this.event, required this.raw});

  @override
  Widget build(BuildContext context) {
    final counts = (raw['walletCounts'] as Map<String, dynamic>?) ?? const {};
    final pdfs = (counts['pdfs'] as num?)?.toInt() ?? 0;
    final images = (counts['images'] as num?)?.toInt() ?? 0;
    final last = (raw['walletLastUploadAt'] as Timestamp?)?.toDate();

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WalletEventScreen(event: event),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AgaramColors.primary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 64,
                width: 64,
                child: event.bannerUrl != null && event.bannerUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: event.bannerUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AgaramColors.surfaceContainer,
                        ),
                        errorWidget: (_, _, _) => _fallbackBanner(),
                      )
                    : _fallbackBanner(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AgaramColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMMM d, yyyy').format(event.date),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AgaramColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip('$pdfs PDFs'),
                      _chip('$images images'),
                      Text(
                        last == null
                            ? 'No uploads yet'
                            : 'Updated ${_ago(last)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AgaramColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AgaramColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AgaramColors.primary,
        ),
      ),
    );
  }

  Widget _fallbackBanner() {
    return Container(
      color: AgaramColors.surfaceContainer,
      child: const Center(
        child: Icon(Icons.menu_book_rounded, color: AgaramColors.primary),
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
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
              Icons.folder_copy_rounded,
              size: 64,
              color: AgaramColors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No documents yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Head to an event and upload the first document.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
