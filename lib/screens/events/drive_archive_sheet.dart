import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/drive_service.dart';
import '../../core/theme.dart';
import '../../core/wallet_service.dart';
import '../../models/event.dart';

class DriveArchiveSheet extends StatefulWidget {
  final AgaramEvent event;
  const DriveArchiveSheet({super.key, required this.event});

  @override
  State<DriveArchiveSheet> createState() => _DriveArchiveSheetState();
}

enum _Phase { counting, ready, uploading, done, error }

class _DriveArchiveSheetState extends State<DriveArchiveSheet> {
  _Phase _phase = _Phase.counting;
  int _docCount = 0;
  DriveArchiveProgress? _progress;
  DriveArchiveResult? _result;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final snap = await WalletService.collection(widget.event.id).get();
      if (!mounted) return;
      setState(() {
        _docCount = snap.docs.length;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMsg = 'Couldn’t read wallet docs: $e';
      });
    }
  }

  Future<void> _startUpload() async {
    setState(() {
      _phase = _Phase.uploading;
      _progress = DriveArchiveProgress(
          done: 0, total: _docCount, failed: 0, currentFileName: null);
    });
    try {
      final result = await DriveService.archiveWalletDocs(
        eventId: widget.event.id,
        eventName: widget.event.title,
        eventDate: widget.event.date,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _result = result;
      });
    } on DriveSignInCancelled {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _openFolder() async {
    final url = _result?.folderUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String get _targetPath =>
      'Agaram / ${widget.event.date.year} / ${widget.event.title}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 20),
            _body(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AgaramColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.drive_folder_upload_rounded,
            color: AgaramColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Archive to Google Drive',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AgaramColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _targetPath,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _phase == _Phase.uploading
              ? null
              : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.counting:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      case _Phase.ready:
        return _readyBody();
      case _Phase.uploading:
        return _uploadingBody();
      case _Phase.done:
        return _doneBody();
      case _Phase.error:
        return _errorBody();
    }
  }

  Widget _readyBody() {
    final empty = _docCount == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AgaramColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                empty
                    ? Icons.info_outline_rounded
                    : Icons.folder_zip_rounded,
                color: empty
                    ? AgaramColors.onSurfaceVariant
                    : AgaramColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  empty
                      ? 'No wallet docs on this event yet — nothing to archive.'
                      : '$_docCount wallet ${_docCount == 1 ? 'doc' : 'docs'} will be uploaded to your Drive.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AgaramColors.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'On first use, Google will ask you to sign in and grant access to files this app creates in your Drive.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AgaramColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: empty ? null : _startUpload,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('Upload to Drive'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _uploadingBody() {
    final p = _progress;
    final ratio = (p == null || p.total == 0) ? 0.0 : p.done / p.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio == 0 ? null : ratio,
            minHeight: 8,
            backgroundColor: AgaramColors.surfaceContainerLow,
            valueColor: const AlwaysStoppedAnimation(AgaramColors.primary),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          p == null
              ? 'Preparing…'
              : p.currentFileName == null
                  ? '${p.done}/${p.total} uploaded'
                  : '${p.done}/${p.total} · ${p.currentFileName}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AgaramColors.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'Keep this screen open until we finish.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AgaramColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _doneBody() {
    final r = _result!;
    final hadFailures = r.failed > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hadFailures
                ? AgaramColors.surfaceContainerLow
                : AgaramColors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hadFailures
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: hadFailures
                    ? AgaramColors.onSurfaceVariant
                    : AgaramColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hadFailures
                          ? '${r.uploaded}/${r.uploaded + r.failed} uploaded, ${r.failed} failed'
                          : '${r.uploaded} ${r.uploaded == 1 ? 'file' : 'files'} uploaded',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AgaramColors.onSurface,
                      ),
                    ),
                    if (hadFailures) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Failed: ${r.failedNames.join(', ')}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AgaramColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _openFolder,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open in Drive'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _errorBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AgaramColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AgaramColors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMsg ?? 'Something went wrong.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AgaramColors.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
