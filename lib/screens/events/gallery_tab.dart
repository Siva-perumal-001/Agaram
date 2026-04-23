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
  const GalleryTab({super.key, required this.eventId});

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
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 82,
    );
    if (picked == null) return;
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
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(picked.path), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: captionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Caption (optional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: const Text('Upload'),
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading photo…')),
    );
    try {
      await GalleryService.addPhoto(
        eventId: eventId,
        file: File(picked.path),
        uploadedBy: user.uid,
        uploadedByName: user.name.isEmpty ? user.email : user.name,
        caption: captionCtrl.text.trim().isEmpty
            ? null
            : captionCtrl.text.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to gallery ✓')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
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
