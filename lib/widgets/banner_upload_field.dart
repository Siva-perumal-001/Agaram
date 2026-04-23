import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';

class BannerUploadField extends StatelessWidget {
  final File? localFile;
  final String? remoteUrl;
  final bool uploading;
  final ValueChanged<File> onPicked;
  final VoidCallback onClear;

  const BannerUploadField({
    super.key,
    required this.localFile,
    required this.remoteUrl,
    required this.uploading,
    required this.onPicked,
    required this.onClear,
  });

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) onPicked(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = localFile != null || (remoteUrl != null && remoteUrl!.isNotEmpty);
    return GestureDetector(
      onTap: uploading ? null : _pick,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AgaramColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: hasContent
                    ? null
                    : Border.all(
                        color: AgaramColors.outlineVariant,
                        width: 1.2,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
              ),
              clipBehavior: Clip.hardEdge,
              child: _content(),
            ),
          ),
          if (hasContent && !uploading)
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    if (localFile != null) {
      return Image.file(localFile!, fit: BoxFit.cover);
    }
    if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: remoteUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(hint: 'Loading…'),
        errorWidget: (_, _, _) => _placeholder(hint: 'Couldn’t load banner'),
      );
    }
    return _placeholder(hint: 'Tap to upload event banner');
  }

  Widget _placeholder({required String hint}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_camera_rounded,
            size: 36,
            color: AgaramColors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
