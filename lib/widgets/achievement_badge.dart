import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

class AchievementBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool unlocked;

  const AchievementBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final bg = unlocked ? color.withValues(alpha: 0.22) : AgaramColors.surfaceContainer;
    final iconColor =
        unlocked ? _darken(color) : AgaramColors.onSurfaceVariant.withValues(alpha: 0.5);
    final iconToRender = unlocked ? icon : Icons.lock_outline_rounded;
    return Column(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(iconToRender, color: iconColor, size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: unlocked
                ? AgaramColors.onSurface
                : AgaramColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }
}
