import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        type == ProofType.image ? _imageCard(context) : _pdfCard(context),
        const SizedBox(height: 10),
        _actionsRow(context),
      ],
    );
  }

  Widget _imageCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImageViewerScreen(url: url),
          fullscreenDialog: true,
        ),
      ),
      child: Hero(
        tag: 'proof-$url',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 11,
            child: Stack(
              children: [
                Positioned.fill(
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
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to zoom',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pdfCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openExternal(context),
      child: Container(
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
      ),
    );
  }

  Widget _actionsRow(BuildContext context) {
    return Row(
      children: [
        if (type == ProofType.pdf)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openExternal(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (type == ProofType.pdf) const SizedBox(width: 10),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _download(context),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openExternal(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open this file.')),
      );
    }
  }

  Future<void> _download(BuildContext context) async {
    // Cloudinary's `fl_attachment` flag rewrites Content-Disposition so the
    // browser treats the URL as a download instead of rendering it inline.
    // Works for both image/upload and raw/upload URLs — we insert the flag
    // right after `/upload/`. Non-Cloudinary URLs fall back to a plain
    // launch (browser will open the file and the user can save from there).
    final downloadUri = Uri.parse(
      url.contains('/upload/')
          ? url.replaceFirst('/upload/', '/upload/fl_attachment/')
          : url,
    );
    final ok = await launchUrl(
      downloadUri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t start the download.')),
      );
    }
  }
}

class _ImageViewerScreen extends StatelessWidget {
  final String url;
  const _ImageViewerScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download',
            onPressed: () => _download(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: 'proof-$url',
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    final downloadUri = Uri.parse(
      url.contains('/upload/')
          ? url.replaceFirst('/upload/', '/upload/fl_attachment/')
          : url,
    );
    HapticFeedback.selectionClick();
    final ok = await launchUrl(
      downloadUri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t start the download.')),
      );
    }
  }
}
