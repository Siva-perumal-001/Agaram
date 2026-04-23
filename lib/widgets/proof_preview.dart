import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../models/task.dart';

class ProofPreview extends StatelessWidget {
  final String url;
  final ProofType type;
  final String? fileLabel;

  const ProofPreview({
    super.key,
    required this.url,
    required this.type,
    this.fileLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (type == ProofType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 11,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: AgaramColors.surfaceContainerLow,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, _, _) => Container(
              color: AgaramColors.surfaceContainerLow,
              child: const Center(
                child: Icon(Icons.broken_image_rounded, size: 40),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AgaramColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AgaramColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileLabel ?? 'proof.pdf',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AgaramColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PDF · tap to open',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AgaramColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.open_in_new_rounded,
            color: AgaramColors.primary,
          ),
        ],
      ),
    );
  }
}
