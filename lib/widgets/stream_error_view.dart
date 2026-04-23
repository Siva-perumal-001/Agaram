import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

/// Inline error panel for `StreamBuilder` / `FutureBuilder` screens when the
/// Firestore query fails (offline, rules denial, bad index). Optional
/// [onRetry] callback rebuilds the stream via `setState` in the caller.
class StreamErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  const StreamErrorView({
    super.key,
    this.message = "Couldn't load this right now.",
    this.onRetry,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AgaramColors.errorContainer,
          borderRadius: BorderRadius.circular(16),
          border: const Border(
            left: BorderSide(color: AgaramColors.error, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: AgaramColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AgaramColors.error,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AgaramColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
