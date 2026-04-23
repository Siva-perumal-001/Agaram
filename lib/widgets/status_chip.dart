import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../models/task.dart';

class StatusChip extends StatelessWidget {
  final TaskStatus status;
  final double fontSize;

  const StatusChip({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _styles();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize,
        vertical: fontSize * 0.4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }

  (String, Color, Color) _styles() {
    switch (status) {
      case TaskStatus.pending:
        return ('Pending', AgaramColors.neutralContainer, AgaramColors.onSurfaceVariant);
      case TaskStatus.submitted:
        return ('Submitted', AgaramColors.warningContainer, AgaramColors.warning);
      case TaskStatus.approved:
        return ('Approved', AgaramColors.successContainer, AgaramColors.success);
      case TaskStatus.rejected:
        return ('Needs rework', AgaramColors.errorContainer, AgaramColors.error);
    }
  }
}
