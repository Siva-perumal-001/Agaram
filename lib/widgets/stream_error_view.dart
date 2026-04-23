import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

/// Inline error panel for `StreamBuilder` / `FutureBuilder` screens when the
/// Firestore query fails (offline, rules denial, bad index). Optional
/// [onRetry] callback rebuilds the stream via `setState` in the caller.
/// Pass [error] to surface the underlying error message (helpful for
/// distinguishing rules denials / missing indexes from network failures).
class StreamErrorView extends StatelessWidget {
  final String message;
  final Object? error;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  const StreamErrorView({
    super.key,
    this.message = "Couldn't load this right now.",
    this.error,
    this.onRetry,
    this.padding = const EdgeInsets.all(24),
  });

  String? get _detail {
    if (error == null) return null;
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('permission-denied') ||
        lower.contains('permission_denied')) {
      return 'Firestore rules are blocking this query. Deploy the latest rules: firebase deploy --only firestore:rules';
    }
    if (lower.contains('failed-precondition') ||
        lower.contains('requires an index')) {
      return 'Missing Firestore index. Open the link from the debug console to create it, or deploy firestore.indexes.json.';
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return 'Firestore is unreachable. Check the device connection.';
    }
    return raw.length > 160 ? '${raw.substring(0, 160)}…' : raw;
  }

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
              _detail ?? 'Check your connection and try again.',
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
