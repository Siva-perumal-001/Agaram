import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/app_config.dart';
import '../../core/cloudinary_service.dart';
import '../../core/event_service.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../widgets/proof_preview.dart';
import '../../widgets/status_chip.dart';

class TaskDetailScreen extends StatefulWidget {
  final AgaramTask task;

  /// When true the viewer is neither the assignee nor an admin (another
  /// member peeking at someone else's task). Hides the upload section and
  /// shows the existing proof (if any) read-only.
  final bool viewOnly;

  const TaskDetailScreen({super.key, required this.task, this.viewOnly = false});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  ProofType _pickedKind = ProofType.image;
  File? _localFile;
  String? _fileName;
  final _noteCtrl = TextEditingController();
  double _uploadProgress = 0;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 80,
    );
    if (picked != null) {
      final f = File(picked.path);
      setState(() {
        _pickedKind = ProofType.image;
        _localFile = f;
        _fileName = picked.name;
      });
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final f = File(result.files.single.path!);
      final sizeMb = (await f.length()) / (1024 * 1024);
      if (sizeMb > AppConfig.maxProofFileSizeMb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF is ${sizeMb.toStringAsFixed(1)} MB — keep it under ${AppConfig.maxProofFileSizeMb} MB.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _pickedKind = ProofType.pdf;
        _localFile = f;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_localFile == null) return;
    setState(() {
      _submitting = true;
      _uploading = true;
      _uploadProgress = 0.2;
    });
    try {
      final kind =
          _pickedKind == ProofType.image ? ProofKind.image : ProofKind.pdf;
      final url = await CloudinaryService.uploadProof(_localFile!, kind: kind);
      if (!mounted) return;
      setState(() => _uploadProgress = 0.85);

      await EventService.submitProof(
        eventId: widget.task.eventId,
        taskId: widget.task.id,
        proofUrl: url,
        proofType: _pickedKind,
        memberNote:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _uploadProgress = 1.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted for review ✓')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final canEdit = !widget.viewOnly &&
        (task.status == TaskStatus.pending ||
            task.status == TaskStatus.rejected);

    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _taskCard(task),
              const SizedBox(height: 20),
              _statusBanner(task),
              if (canEdit) ...[
                const SizedBox(height: 20),
                _uploadSection(),
                const SizedBox(height: 16),
                _noteField(),
                const SizedBox(height: 24),
                _submitButton(canEdit),
              ] else if (task.status == TaskStatus.submitted ||
                  task.status == TaskStatus.approved) ...[
                const SizedBox(height: 20),
                _submittedProof(task),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskCard(AgaramTask task) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AgaramColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AgaramColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  task.eventTitle.isEmpty ? 'Event' : task.eventTitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AgaramColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: AgaramColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+${AppConfig.starsPerApprovedTask} stars',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AgaramColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.title,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AgaramColors.primary,
              height: 1.25,
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AgaramColors.secondaryContainer,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                '"${task.description}"',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AgaramColors.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (task.dueDate != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AgaramColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AgaramColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBanner(AgaramTask task) {
    if (task.status == TaskStatus.pending) return const SizedBox.shrink();
    final (label, bg, fg, icon) = switch (task.status) {
      TaskStatus.submitted => (
          'Submitted · awaiting review',
          const Color(0xFFFEF3D0),
          const Color(0xFF795900),
          Icons.hourglass_bottom_rounded,
        ),
      TaskStatus.approved => (
          'Approved · +${task.starsAwarded} stars added',
          const Color(0xFFDDF2E3),
          const Color(0xFF2E7D32),
          Icons.check_circle_rounded,
        ),
      TaskStatus.rejected => (
          'Needs resubmission',
          const Color(0xFFFCE4E1),
          const Color(0xFFBA1A1A),
          Icons.replay_rounded,
        ),
      TaskStatus.pending => ('', Colors.transparent, Colors.transparent, Icons.circle),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          if (task.reviewNote != null && task.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${task.reviewNote}"',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: fg,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _uploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submit Proof',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AgaramColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _kindToggle('Image', ProofType.image, Icons.image_rounded),
            const SizedBox(width: 10),
            _kindToggle('PDF', ProofType.pdf, Icons.picture_as_pdf_rounded),
          ],
        ),
        const SizedBox(height: 16),
        _uploadArea(),
      ],
    );
  }

  Widget _kindToggle(String label, ProofType kind, IconData icon) {
    final selected = _pickedKind == kind;
    return GestureDetector(
      onTap: _uploading
          ? null
          : () => setState(() {
                _pickedKind = kind;
                _localFile = null;
                _fileName = null;
              }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AgaramColors.primaryContainer
              : AgaramColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: AgaramColors.outlineVariant, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AgaramColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AgaramColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadArea() {
    return GestureDetector(
      onTap: _uploading
          ? null
          : (_pickedKind == ProofType.image ? _pickImage : _pickPdf),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AgaramColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                size: 36,
                color: AgaramColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _localFile == null
                  ? 'Upload photo or PDF'
                  : (_fileName ?? 'File selected'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AgaramColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _localFile == null
                  ? 'Tap to browse · max ${AppConfig.maxProofFileSizeMb} MB'
                  : 'Tap to replace',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
            if (_uploading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: AgaramColors.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation(
                  AgaramColors.secondaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note to reviewer (optional)',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AgaramColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add a note for the reviewer…',
          ),
        ),
      ],
    );
  }

  Widget _submitButton(bool canEdit) {
    final enabled = canEdit && _localFile != null && !_submitting;
    return ElevatedButton(
      onPressed: enabled ? _submit : null,
      child: _submitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: AgaramColors.onPrimary,
                strokeWidth: 2.5,
              ),
            )
          : const Text('Submit for review'),
    );
  }

  Widget _submittedProof(AgaramTask task) {
    if (task.proofUrl == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Your submission',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AgaramColors.primary,
              ),
            ),
            const Spacer(),
            StatusChip(status: task.status),
          ],
        ),
        const SizedBox(height: 12),
        ProofPreview(
          url: task.proofUrl!,
          type: task.proofType ?? ProofType.image,
        ),
        if (task.memberNote != null && task.memberNote!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Your note: "${task.memberNote}"',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
