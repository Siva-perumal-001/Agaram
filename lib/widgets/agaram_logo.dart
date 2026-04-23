import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

class AgaramWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;
  const AgaramWordmark({super.key, this.fontSize = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AgaramColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'அ',
          style: GoogleFonts.notoSerifTamil(
            fontSize: fontSize * 1.4,
            fontWeight: FontWeight.w700,
            color: c,
            height: 1,
          ),
        ),
        SizedBox(width: fontSize * 0.4),
        Text(
          'AGARAM',
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: c,
            letterSpacing: fontSize * 0.08,
            height: 1,
          ),
        ),
      ],
    );
  }
}
