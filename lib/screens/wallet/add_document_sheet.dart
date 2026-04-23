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
  File? _file;
  String? _fileName;
  int? _fileBytes;
  bool _uploading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final f = File(result.files.single.path!);
    final size = await f.length();
    if (size > AppConfig.maxProofFileSizeMb * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF is ${(size / (1024 * 1024)).toStringAsFixed(1)} MB — keep it under ${AppConfig.maxProofFileSizeMb} MB.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _type = WalletDocType.pdf;
      _file = f;
      _fileName = result.files.single.name;
      _fileBytes = size;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 82,
    );
    if (picked == null) return;
    final f = File(picked.path);
    final size = await f.length();
    setState(() {
      _type = WalletDocType.image;
      _file = f;
      _fileName = picked.name;
      _fileBytes = size;
    });
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null) return;
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      await WalletService.addDoc(
        eventId: widget.event.id,
        eventTitle: widget.event.title,
        file: _file!,
        title: _titleCtrl.text.trim(),
        type: _type,
        uploadedBy: user.uid,
        uploadedByName: user.name.isEmpty ? user.email : user.name,
        caption: _captionCtrl.text.trim().isEmpty
            ? null
            : _captionCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to wallet ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final ready = _file != null && _titleCtrl.text.trim().isNotEmpty;

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
              _sectionLabel('Title (required)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Meeting minutes - April',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
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
              ElevatedButton(
                onPressed: !ready || _uploading ? null : _upload,
                child: _uploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AgaramColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Upload to Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
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
          _file = null;
          _fileName = null;
          _fileBytes = null;
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
    return GestureDetector(
      onTap: _uploading
          ? null
          : (_type == WalletDocType.pdf ? _pickPdf : _pickImage),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AgaramColors.secondaryContainer,
            width: 1.5,
            style: BorderStyle.solid,
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
              child: const Icon(
                Icons.upload_file_rounded,
                color: AgaramColors.secondary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _file == null ? 'Tap to choose file' : (_fileName ?? 'Selected'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AgaramColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _file == null
                  ? 'Max size ${AppConfig.maxProofFileSizeMb}MB (PDF, PNG, JPG)'
                  : '${((_fileBytes ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB · Ready',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
            if (_file != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _file = null;
                  _fileName = null;
                  _fileBytes = null;
                }),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Remove file'),
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
