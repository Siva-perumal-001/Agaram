import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/gallery_service.dart';
import '../../core/theme.dart';
import '../../models/gallery_photo.dart';

class PhotoLightboxScreen extends StatefulWidget {
  final String eventId;
  final List<GalleryPhoto> photos;
  final int initialIndex;

  const PhotoLightboxScreen({
    super.key,
    required this.eventId,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoLightboxScreen> createState() => _PhotoLightboxScreenState();
}

class _PhotoLightboxScreenState extends State<PhotoLightboxScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;
    final photo = widget.photos[_index];
    final mine = uid != null && photo.uploadedBy == uid;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: photo.url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied')),
              );
            },
          ),
          if (mine)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              onPressed: () => _confirmDelete(photo),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _photoView(widget.photos[i]),
            ),
          ),
          if (widget.photos.length > 1) _pageDots(),
          _footer(photo),
        ],
      ),
    );
  }

  Widget _photoView(GalleryPhoto p) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: p.url,
          fit: BoxFit.contain,
          placeholder: (_, _) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: Colors.white38,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.photos.length > 8 ? 8 : widget.photos.length,
          (i) {
            final active = i == (_index % 8);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: 6,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white24,
                shape: BoxShape.circle,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _footer(GalleryPhoto p) {
    final ts = p.uploadedAt;
    final timeLabel = ts == null
        ? '—'
        : DateFormat('MMM d · h:mm a').format(ts);
    final initial = p.uploadedByName.isEmpty
        ? 'A'
        : p.uploadedByName[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AgaramColors.primaryContainer,
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.uploadedByName.isEmpty ? 'Member' : p.uploadedByName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (p.caption != null && p.caption!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    p.caption!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(GalleryPhoto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This will remove the photo from the gallery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AgaramColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GalleryService.deletePhoto(eventId: widget.eventId, photoId: p.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t delete: $e')),
      );
    }
  }
}
