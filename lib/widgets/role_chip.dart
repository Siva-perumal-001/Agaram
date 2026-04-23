import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../models/app_user.dart';

class RoleChip extends StatelessWidget {
  final AppUser user;
  const RoleChip({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.isPresident) {
      return _chip(
        label: 'President',
        trailing: ' 👑',
        bg: AgaramColors.primaryContainer,
        fg: Colors.white,
        border: null,
      );
    }
    if (user.isAdmin) {
      return _chip(
        label: 'Admin',
        bg: AgaramColors.secondaryContainer,
        fg: AgaramColors.secondary,
        border: null,
      );
    }
    return _chip(
      label: 'Member',
      bg: Colors.transparent,
      fg: AgaramColors.primary,
      border: Border.all(color: AgaramColors.primary, width: 1.2),
    );
  }

  Widget _chip({
    required String label,
    String trailing = '',
    required Color bg,
    required Color fg,
    required BoxBorder? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border,
      ),
      child: Text(
        '$label$trailing',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
