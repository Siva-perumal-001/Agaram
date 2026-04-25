import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../core/wallet_service.dart';
import '../../models/event.dart';
import '../../models/wallet_doc.dart';

class _PickedFile {
  final File file;
  final String name;
  final int bytes;
  const _PickedFile({
    required this.file,
    required this.name,
    required this.bytes,
  });
}

class AddDocumentSheet extends StatefulWidget {
  final AgaramEvent event;
  const AddDocumentSheet({super.key, required this.event});

  @override
  State<AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<AddDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();

  WalletDocType _type = WalletDocType.pdf;
  final List<_PickedFile> _picked = [];
  bool _uploading = false;
  int _uploadIndex = 0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  bool get _isMulti => _type == WalletDocType.image && _picked.length > 1;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final f = File(result.files.single.path!);
    final size = await f.length();
    if (size > AppConfig.maxWalletFileSizeMb * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF is ${(size / (1024 * 1024)).toStringAsFixed(1)} MB — keep it under ${AppConfig.maxWalletFileSizeMb} MB.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _type = WalletDocType.pdf;
      _picked
        ..clear()
        ..add(_PickedFile(
          file: f,
          name: result.files.single.name,
          bytes: size,
        ));
    });
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 2000,
      imageQuality: 82,
    );
    if (picked.isEmpty) return;
    final maxBytes = AppConfig.maxWalletFileSizeMb * 1024 * 1024;
    final accepted = <_PickedFile>[];
    final tooBig = <String>[];
    for (final p in picked) {
      final f = File(p.path);
      final size = await f.length();
      if (size > maxBytes) {
        tooBig.add(p.name);
      } else {
        accepted.add(_PickedFile(file: f, name: p.name, bytes: size));
      }
    }
    if (!mounted) return;
    setState(() {
      _type = WalletDocType.image;
      _picked
        ..clear()
        ..addAll(accepted);
    });
    if (tooBig.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tooBig.length == 1
                ? '"${tooBig.first}" is over ${AppConfig.maxWalletFileSizeMb} MB and was skipped.'
                : '${tooBig.length} images were over ${AppConfig.maxWalletFileSizeMb} MB and were skipped.',
          ),
        ),
      );
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_picked.isEmpty) return;
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final baseTitle = _titleCtrl.text.trim();
    final caption =
        _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim();
    final uploaderName = user.name.isEmpty ? user.email : user.name;

    setState(() {
      _uploading = true;
      _uploadIndex = 0;
    });

    var succeeded = 0;
    final failed = <String>[];
    for (var i = 0; i < _picked.length; i++) {
      if (mounted) setState(() => _uploadIndex = i + 1);
      final p = _picked[i];
      final docTitle =
          _picked.length > 1 ? '$baseTitle ${i + 1}' : baseTitle;
      try {
        await WalletService.addDoc(
          eventId: widget.event.id,
          eventTitle: widget.event.title,
          file: p.file,
          title: docTitle,
          type: _type,
          uploadedBy: user.uid,
          uploadedByName: uploaderName,
          caption: caption,
        );
        succeeded++;
      } catch (e) {
        failed.add(p.name);
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (failed.isEmpty) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            succeeded == 1
                ? 'Added to wallet ✓'
                : '$succeeded documents added to wallet ✓',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded == 0
              ? 'Upload failed for all ${failed.length} files.'
              : '$succeeded uploaded · ${failed.length} failed (${failed.first}${failed.length > 1 ? '…' : ''})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final ready = _picked.isNotEmpty && _titleCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to Wallet',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AgaramColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AgaramColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AgaramColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AgaramColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Document Type'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _typeChip('📄 PDF', WalletDocType.pdf),
                  const SizedBox(width: 10),
                  _typeChip('🖼️ Image', WalletDocType.image),
                ],
              ),
              const SizedBox(height: 16),
              _uploadArea(),
              const SizedBox(height: 18),
              _sectionLabel(
                  _isMulti ? 'Title (required, shared)' : 'Title (required)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: _isMulti
                      ? 'e.g. Bill April  →  Bill April 1, 2, 3…'
                      : 'e.g. Meeting minutes - April',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              if (_isMulti) ...[
                const SizedBox(height: 6),
                Text(
                  'Each image will be saved as "$_titlePreview".',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AgaramColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _sectionLabel('Caption (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _captionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe the document…',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Will be saved as uploaded by ${user?.name.isEmpty == false ? user!.name : 'you'} · ${DateFormat('MMM d, h:mm a').format(DateTime.now())}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AgaramColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: !ready || _uploading ? null : _upload,
                child: _uploading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: AgaramColors.onPrimary,
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_picked.length > 1
                              ? 'Uploading $_uploadIndex of ${_picked.length}…'
                              : 'Uploading…'),
                        ],
                      )
                    : Text(_picked.length > 1
                        ? 'Upload ${_picked.length} to Wallet'
                        : 'Upload to Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _titlePreview {
    final base = _titleCtrl.text.trim();
    if (base.isEmpty) return '...';
    return '$base 1, $base 2, …';
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AgaramColors.onSurfaceVariant,
        ),
      );

  Widget _typeChip(String label, WalletDocType type) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _picked.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AgaramColors.primaryContainer
                : AgaramColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AgaramColors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadArea() {
    final hasFiles = _picked.isNotEmpty;
    final totalBytes = _picked.fold<int>(0, (sum, p) => sum + p.bytes);
    final hint = !hasFiles
        ? (_type == WalletDocType.pdf
            ? 'Tap to choose PDF'
            : 'Tap to choose images')
        : (_picked.length == 1
            ? _picked.first.name
            : '${_picked.length} images selected');
    final subhint = !hasFiles
        ? 'Max ${AppConfig.maxWalletFileSizeMb}MB each'
            ' (${_type == WalletDocType.pdf ? 'PDF' : 'PNG, JPG'})'
        : '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB · Ready';

    return GestureDetector(
      onTap: _uploading
          ? null
          : (_type == WalletDocType.pdf ? _pickPdf : _pickImages),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AgaramColors.secondaryContainer,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AgaramColors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _type == WalletDocType.pdf
                    ? Icons.upload_file_rounded
                    : Icons.photo_library_rounded,
                color: AgaramColors.secondary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hint,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AgaramColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subhint,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
            if (hasFiles) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _uploading
                    ? null
                    : () => setState(() => _picked.clear()),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text(_picked.length > 1 ? 'Clear all' : 'Remove file'),
                style: TextButton.styleFrom(
                  foregroundColor: AgaramColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
