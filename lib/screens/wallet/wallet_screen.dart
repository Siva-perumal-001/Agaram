import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

/// Phase 7 work-in-progress — the full Wallet screen is built after the
/// remaining Phase 7 services land. This placeholder keeps the 5th bottom-nav
/// slot wired so [HomeShell] compiles while we're still iterating.
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.folder_copy_rounded,
                  size: 72,
                  color: AgaramColors.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Event Archive',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Document archive lands in the next build. Come back soon.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AgaramColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
