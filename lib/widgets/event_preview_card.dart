import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

class EventPreviewCard extends StatelessWidget {
  final String title;
  final String venue;
  final DateTime date;
  final int tasksCount;
  final String? bannerUrl;
  final VoidCallback? onTap;
  final double? width;
  final bool isMeeting;

  const EventPreviewCard({
    super.key,
    required this.title,
    required this.venue,
    required this.date,
    required this.tasksCount,
    this.bannerUrl,
    this.onTap,
    this.width,
    this.isMeeting = false,
  });

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final dayText = date.day.toString().padLeft(2, '0');
    final monthText = _months[(date.month - 1).clamp(0, 11)];

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: AgaramColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AgaramColors.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  _banner(),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AgaramColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            dayText,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AgaramColors.primary,
                              height: 1,
                            ),
                          ),
                          Text(
                            monthText,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AgaramColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AgaramColors.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AgaramColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AgaramColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tasksCount > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AgaramColors.secondaryContainer
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$tasksCount ${tasksCount == 1 ? 'task' : 'tasks'} assigned',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AgaramColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner() {
    if (bannerUrl != null && bannerUrl!.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          bannerUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholderBanner(),
        ),
      );
    }
    return _placeholderBanner();
  }

  Widget _placeholderBanner() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AgaramColors.surfaceContainer, AgaramColors.surfaceContainerHigh],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.menu_book_rounded,
            size: 40,
            color: AgaramColors.primary,
          ),
        ),
      ),
    );
  }
}
