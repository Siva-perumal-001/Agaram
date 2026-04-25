import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../core/wallet_service.dart';
import '../../models/event.dart';
import '../../models/wallet_doc.dart';
import '../gallery/photo_lightbox_screen.dart';
import '../../models/gallery_photo.dart';
import 'add_document_sheet.dart';

enum _WalletFilter { all, pdfs, images, mine }

class WalletEventScreen extends StatefulWidget {
  final AgaramEvent event;
  const WalletEventScreen({super.key, required this.event});

  @override
  State<WalletEventScreen> createState() => _WalletEventScreenState();
}

class _WalletEventScreenState extends State<WalletEventScreen> {
  _WalletFilter _filter = _WalletFilter.all;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().currentUser;
    final isAdmin = context.watch<AuthService>().isAdmin;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _hero(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _summary(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: _filterRow(),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: WalletService.stream(widget.event.id),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final docs = (snap.data?.docs ?? [])
                  .map(WalletDoc.fromFirestore)
                  .where(_matches(me?.uid))
                  .toList();
              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _EmptyState(),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _DocTile(
                    doc: docs[i],
                    canDelete: isAdmin || me?.uid == docs[i].uploadedBy,
                    onDelete: () => _confirmDelete(docs[i]),
                    onOpen: () => _open(docs[i]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AgaramColors.secondary,
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AgaramColors.surface,
          showDragHandle: true,
          builder: (_) => AddDocumentSheet(event: widget.event),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add document'),
      ),
    );
  }

  bool Function(WalletDoc) _matches(String? uid) {
    switch (_filter) {
      case _WalletFilter.all:
        return (_) => true;
      case _WalletFilter.pdfs:
        return (d) => d.type == WalletDocType.pdf;
      case _WalletFilter.images:
        return (d) => d.type == WalletDocType.image;
      case _WalletFilter.mine:
        return (d) => uid != null && d.uploadedBy == uid;
    }
  }

  Widget _hero() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: AgaramColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        widget.event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.event.bannerUrl != null &&
                widget.event.bannerUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.event.bannerUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    Container(color: AgaramColors.primaryContainer),
              )
            else
              Container(color: AgaramColors.primaryContainer),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: WalletService.stream(widget.event.id),
      builder: (_, snap) {
        final total = snap.data?.docs.length ?? 0;
        final contributors = (snap.data?.docs ?? [])
            .map((d) => d.data()['uploadedBy'] as String?)
            .whereType<String>()
            .toSet()
            .length;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AgaramColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AgaramColors.primary.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AgaramColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_shared_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared Resources',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AgaramColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total ${total == 1 ? 'document' : 'documents'} from $contributors ${contributors == 1 ? 'contributor' : 'contributors'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AgaramColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', _WalletFilter.all),
          const SizedBox(width: 8),
          _chip('PDFs', _WalletFilter.pdfs),
          const SizedBox(width: 8),
          _chip('Images', _WalletFilter.images),
          const SizedBox(width: 8),
          _chip('Mine', _WalletFilter.mine),
        ],
      ),
    );
  }

  Widget _chip(String label, _WalletFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AgaramColors.primaryContainer
              : AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AgaramColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _open(WalletDoc doc) async {
    if (doc.type == WalletDocType.image) {
      final photo = GalleryPhoto(
        id: doc.id,
        url: doc.url,
        uploadedBy: doc.uploadedBy,
        uploadedByName: doc.uploadedByName,
        uploadedAt: doc.uploadedAt,
        caption: doc.caption,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoLightboxScreen(
            eventId: widget.event.id,
            photos: [photo],
            initialIndex: 0,
          ),
        ),
      );
      return;
    }
    final uri = Uri.parse(doc.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: doc.url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open — link copied instead.')),
      );
    }
  }

  Future<void> _confirmDelete(WalletDoc doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('"${doc.title}" will be removed from the wallet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AgaramColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WalletService.deleteDoc(eventId: widget.event.id, doc: doc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t delete: $e')),
      );
    }
  }
}

class _DocTile extends StatelessWidget {
  final WalletDoc doc;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _DocTile({
    required this.doc,
    required this.canDelete,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AgaramColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _thumb(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AgaramColors.onSurface,
                    ),
                  ),
                  if (doc.caption != null && doc.caption!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      doc.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AgaramColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (doc.sizeBytes != null)
                        Text(
                          doc.sizeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AgaramColors.primary,
                          ),
                        ),
                      if (doc.sizeBytes != null)
                        const Text(
                          '  ·  ',
                          style: TextStyle(
                              color: AgaramColors.onSurfaceVariant),
                        ),
                      Flexible(
                        child: Text(
                          'Uploaded by ${doc.uploadedByName.isEmpty ? 'Member' : doc.uploadedByName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AgaramColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (doc.uploadedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d · h:mm a').format(doc.uploadedAt!),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AgaramColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AgaramColors.onSurfaceVariant,
                ),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    if (doc.type == WalletDocType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 72,
          width: 72,
          child: CachedNetworkImage(
            imageUrl: doc.url,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: AgaramColors.surfaceContainer,
            ),
            errorWidget: (_, _, _) => Container(
              color: AgaramColors.surfaceContainer,
              child: const Icon(Icons.image_rounded),
            ),
          ),
        ),
      );
    }
    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        color: AgaramColors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.description_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_copy_rounded,
              size: 56,
              color: AgaramColors.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to upload',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Add document" to share minutes, reports, or certificates.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
