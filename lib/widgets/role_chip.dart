import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../models/app_user.dart';

class RoleChip extends StatelessWidget {
  final AppUser user;
  final bool compact;

  const RoleChip({super.key, required this.user, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, border, icon) = _styles();
    final padH = compact ? 10.0 : 16.0;
    final padV = compact ? 4.0 : 8.0;
    final fontSize = compact ? 11.0 : 13.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            SizedBox(width: padH * 0.4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, Color, BoxBorder?, IconData?) _styles() {
    final pos = user.position;
    final effectivePresident = user.isPresident || pos == AppPosition.president;

    if (effectivePresident) {
      return (
        'President',
        AgaramColors.primaryContainer,
        Colors.white,
        null,
        Icons.workspace_premium_rounded,
      );
    }
    if (pos == AppPosition.vicePresident) {
      return (
        'Vice President',
        AgaramColors.primary,
        Colors.white,
        null,
        Icons.star_rounded,
      );
    }
    if (pos == AppPosition.secretary) {
      return (
        'Secretary',
        AgaramColors.secondaryContainer,
        AgaramColors.secondary,
        null,
        Icons.edit_note_rounded,
      );
    }
    if (pos == AppPosition.jointSecretary) {
      return (
        'Joint Secretary',
        AgaramColors.secondaryContainer.withValues(alpha: 0.6),
        AgaramColors.secondary,
        null,
        Icons.edit_note_rounded,
      );
    }
    if (pos == AppPosition.treasurer) {
      return (
        'Treasurer',
        AgaramColors.successContainer,
        AgaramColors.success,
        null,
        Icons.account_balance_wallet_rounded,
      );
    }
    if (pos == AppPosition.jointTreasurer) {
      return (
        'Joint Treasurer',
        AgaramColors.successContainer.withValues(alpha: 0.65),
        AgaramColors.success,
        null,
        Icons.account_balance_wallet_rounded,
      );
    }
    if (user.isAdmin) {
      return (
        'Admin',
        AgaramColors.secondaryContainer,
        AgaramColors.secondary,
        null,
        Icons.shield_rounded,
      );
    }
    return (
      'Member',
      Colors.transparent,
      AgaramColors.primary,
      Border.all(color: AgaramColors.primary, width: 1.2),
      null,
    );
  }
}
