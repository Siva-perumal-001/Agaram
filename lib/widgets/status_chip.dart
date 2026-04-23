import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        return ('Pending', const Color(0xFFEFE7E6), const Color(0xFF58413F));
      case TaskStatus.submitted:
        return ('Submitted', const Color(0xFFFEF3D0), const Color(0xFF795900));
      case TaskStatus.approved:
        return ('Approved', const Color(0xFFDDF2E3), const Color(0xFF2E7D32));
      case TaskStatus.rejected:
        return ('Needs rework', const Color(0xFFFCE4E1), const Color(0xFFBA1A1A));
    }
  }
}
