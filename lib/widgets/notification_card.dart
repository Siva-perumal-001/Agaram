import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/app_notification.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification notif;
  final bool unread;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.notif,
    required this.unread,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _iconForKind(notif.kind);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread
              ? AgaramColors.surfaceContainerLowest
              : AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: unread
              ? const Border(
                  left: BorderSide(color: AgaramColors.primary, width: 3),
                )
              : null,
          boxShadow: unread
              ? [
                  BoxShadow(
                    color: AgaramColors.primary.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: unread
                                ? AgaramColors.primary
                                : AgaramColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(notif.sentAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AgaramColors.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          height: 8,
                          width: 8,
                          decoration: const BoxDecoration(
                            color: AgaramColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AgaramColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconForKind(AppNotificationKind k) {
    switch (k) {
      case AppNotificationKind.event:
        return (Icons.calendar_today_rounded, AgaramColors.primary);
      case AppNotificationKind.task:
        return (Icons.task_alt_rounded, AgaramColors.secondary);
      case AppNotificationKind.announcement:
        return (Icons.campaign_rounded, const Color(0xFF6C4BB6));
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'JUST NOW';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'NOW';
    if (diff.inHours < 1) return '${diff.inMinutes}M AGO';
    if (diff.inDays < 1) return '${diff.inHours}H AGO';
    if (diff.inDays == 1) return 'YESTERDAY';
    if (diff.inDays < 7) return '${diff.inDays} DAYS AGO';
    return DateFormat('MMM d').format(dt).toUpperCase();
  }
}
