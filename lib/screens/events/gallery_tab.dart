import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/gallery_service.dart';
import '../../core/theme.dart';
import '../../models/gallery_photo.dart';
import '../gallery/photo_lightbox_screen.dart';

class GalleryTab extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  const GalleryTab({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: GalleryService.gallery(eventId)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        final photos =
            (snap.data?.docs ?? []).map(GalleryPhoto.fromFirestore).toList();
        final contributors =
            photos.map((p) => p.uploadedBy).toSet().length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summary(photos.length, contributors),
            const SizedBox(height: 14),
            if (photos.isEmpty)
              const _EmptyGallery()
            else
              _grid(context, photos),
            const SizedBox(height: 16),
            if (user != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AgaramColors.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                  ),
                  onPressed: () => _pickAndUpload(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add photo'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _summary(int photoCount, int contributors) {
    return Row(
      children: [
        const Icon(
          Icons.photo_library_rounded,
          color: AgaramColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          '$photoCount photos · $contributors ${contributors == 1 ? 'contributor' : 'contributors'}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AgaramColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, List<GalleryPhoto> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final p = photos[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PhotoLightboxScreen(
                eventId: eventId,
                photos: photos,
                initialIndex: i,
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: p.url,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: AgaramColors.surfaceContainer,
              ),
              errorWidget: (_, _, _) => Container(
                color: AgaramColors.surfaceContainer,
                child: const Icon(Icons.broken_image_rounded),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 2000,
      imageQuality: 82,
    );
    if (picked.isEmpty) return;
    if (!context.mounted) return;

    final captionCtrl = TextEditingController();
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AgaramColors.surface,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (picked.length == 1)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(picked.first.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                _MultiPickedPreview(picked: picked),
              const SizedBox(height: 14),
              if (picked.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${picked.length} photos selected',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AgaramColors.primary,
                    ),
                  ),
                ),
              TextField(
                controller: captionCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: picked.length > 1
                      ? 'Shared caption (optional)'
                      : 'Caption (optional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: Text(
                  picked.length > 1 ? 'Upload ${picked.length}' : 'Upload',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final caption = captionCtrl.text.trim().isEmpty
        ? null
        : captionCtrl.text.trim();
    final uploaderName = user.name.isEmpty ? user.email : user.name;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          picked.length == 1
              ? 'Uploading photo…'
              : 'Uploading ${picked.length} photos…',
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    var succeeded = 0;
    final failed = <String>[];
    for (final p in picked) {
      try {
        await GalleryService.addPhoto(
          eventId: eventId,
          eventTitle: eventTitle,
          file: File(p.path),
          uploadedBy: user.uid,
          uploadedByName: uploaderName,
          caption: caption,
        );
        succeeded++;
      } catch (_) {
        failed.add(p.name);
      }
    }
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    if (failed.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            succeeded == 1
                ? 'Added to gallery ✓'
                : '$succeeded photos added to gallery ✓',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            succeeded == 0
                ? 'Upload failed for all ${failed.length} photos.'
                : '$succeeded uploaded · ${failed.length} failed',
          ),
        ),
      );
    }
  }
}

class _MultiPickedPreview extends StatelessWidget {
  final List<XFile> picked;
  const _MultiPickedPreview({required this.picked});

  @override
  Widget build(BuildContext context) {
    final shown = picked.take(4).toList();
    final extra = picked.length - shown.length;
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(shown[i].path), fit: BoxFit.cover),
                    if (i == shown.length - 1 && extra > 0)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Text(
                          '+$extra',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (i != shown.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_camera_rounded,
            size: 40,
            color: AgaramColors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No photos yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to share a moment from this event.',
            textAlign: TextAlign.center,
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
