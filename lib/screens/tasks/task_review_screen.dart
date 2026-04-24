import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/auth_service.dart';
import '../../core/event_service.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../widgets/proof_preview.dart';

class TaskReviewScreen extends StatefulWidget {
  final AgaramTask task;
  const TaskReviewScreen({super.key, required this.task});

  @override
  State<TaskReviewScreen> createState() => _TaskReviewScreenState();
}

class _TaskReviewScreenState extends State<TaskReviewScreen> {
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final reviewer = context.read<AuthService>().currentUser;
    if (reviewer == null) return;
    setState(() => _busy = true);
    try {
      await EventService.approveTask(
        eventId: widget.task.eventId,
        taskId: widget.task.id,
        reviewerUid: reviewer.uid,
        memberUid: widget.task.assignedTo,
        reviewNote:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approved. +${AppConfig.starsPerApprovedTask} stars to ${widget.task.assignedToName}.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t approve: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a note so the member knows what to fix.'),
        ),
      );
      return;
    }
    final reviewer = context.read<AuthService>().currentUser;
    if (reviewer == null) return;
    setState(() => _busy = true);
    try {
      await EventService.rejectTask(
        eventId: widget.task.eventId,
        taskId: widget.task.id,
        reviewerUid: reviewer.uid,
        reviewNote: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejected. Member will be asked to resubmit.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t reject: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveExtension(int days) async {
    final reviewer = context.read<AuthService>().currentUser;
    if (reviewer == null) return;
    setState(() => _busy = true);
    try {
      await EventService.approveExtension(
        eventId: widget.task.eventId,
        taskId: widget.task.id,
        reviewerUid: reviewer.uid,
        grantedDays: days,
        reviewNote:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extension approved · +$days day(s).')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t approve extension: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _denyExtension() async {
    if (_noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a note explaining why you’re denying.'),
        ),
      );
      return;
    }
    final reviewer = context.read<AuthService>().currentUser;
    if (reviewer == null) return;
    setState(() => _busy = true);
    try {
      await EventService.denyExtension(
        eventId: widget.task.eventId,
        taskId: widget.task.id,
        reviewerUid: reviewer.uid,
        reviewNote: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extension denied.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t deny extension: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adminExtend(int days) async {
    final reviewer = context.read<AuthService>().currentUser;
    if (reviewer == null) return;
    setState(() => _busy = true);
    try {
      await EventService.adminExtendTask(
        eventId: widget.task.eventId,
        taskId: widget.task.id,
        reviewerUid: reviewer.uid,
        grantedDays: days,
        reviewNote:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task extended · +$days day(s).')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t extend: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final showExtensionReview = task.hasPendingExtension;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Task'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.schedule_rounded),
            tooltip: 'Extend due date',
            onSelected: _busy ? null : _adminExtend,
            itemBuilder: (_) => [
              for (final d in [1, 2, 3, 4])
                PopupMenuItem(
                  value: d,
                  child: Text('Extend +$d day${d == 1 ? '' : 's'}'),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _memberBlock(task),
              const SizedBox(height: 20),
              _taskContext(task),
              const SizedBox(height: 20),
              if (showExtensionReview) ...[
                _extensionReviewSection(task),
                const SizedBox(height: 20),
              ],
              _proof(task),
              const SizedBox(height: 12),
              _metadataRow(task),
              if (task.memberNote != null && task.memberNote!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _memberNote(task),
              ],
              const SizedBox(height: 24),
              Text(
                'NOTE TO MEMBER (OPTIONAL)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Provide feedback or encouragement…',
                  fillColor: AgaramColors.surfaceContainerLowest,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          showExtensionReview ? _extensionActionBar(task) : _actionBar(),
    );
  }

  Widget _extensionReviewSection(AgaramTask task) {
    final days = task.extensionRequestedDays ?? 1;
    final reason = (task.extensionReason ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgaramColors.warningContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_send_rounded,
                  color: AgaramColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Extension request · +$days day(s)',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AgaramColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reason.isEmpty ? '(no reason given)' : '"$reason"',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AgaramColors.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Member paid: −${task.extensionStarCost} star(s) to request. '
            'Denying will not refund.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _extensionActionBar(AgaramTask task) {
    final defaultDays = task.extensionRequestedDays ?? 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: OutlinedButton(
                onPressed: _busy ? null : _denyExtension,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AgaramColors.error,
                  side: const BorderSide(
                    color: AgaramColors.error,
                    width: 1.2,
                  ),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Deny'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: PopupMenuButton<int>(
                enabled: !_busy,
                onSelected: _approveExtension,
                itemBuilder: (_) => [
                  for (final d in [1, 2, 3, 4])
                    PopupMenuItem(
                      value: d,
                      child: Text(
                        'Approve +$d day${d == 1 ? '' : 's'}'
                        '${d == defaultDays ? ' (requested)' : ''}',
                      ),
                    ),
                ],
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AgaramColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: AgaramColors.onPrimary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Approve +$defaultDays day(s) ▾',
                          style: GoogleFonts.inter(
                            color: AgaramColors.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberBlock(AgaramTask task) {
    final initial = task.assignedToName.isEmpty
        ? 'A'
        : task.assignedToName[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AgaramColors.primaryContainer,
          child: Text(
            initial,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.assignedToName.isEmpty ? 'Member' : task.assignedToName,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AgaramColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AgaramColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Member',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AgaramColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskContext(AgaramTask task) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AgaramColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                task.eventTitle.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AgaramColors.primary,
              height: 1.3,
            ),
          ),
          if (task.effectiveDueDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: AgaramColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Due ${DateFormat('MMM d').format(task.effectiveDueDate!)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AgaramColors.onSurfaceVariant,
                  ),
                ),
                if (task.extensionGrantedDays != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AgaramColors.successContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Extended +${task.extensionGrantedDays}d'
                      '${task.extensionAdminInitiated ? ' (admin)' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AgaramColors.success,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _proof(AgaramTask task) {
    if (task.proofUrl == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No proof submitted yet.'),
      );
    }
    return ProofPreview(
      url: task.proofUrl!,
      type: task.proofType ?? ProofType.image,
    );
  }

  Widget _metadataRow(AgaramTask task) {
    final submittedLabel = task.submittedAt == null
        ? 'Recently'
        : DateFormat('MMM d · h:mm a').format(task.submittedAt!);
    final typeLabel = task.proofType == ProofType.pdf ? 'PDF' : 'Image';
    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 14,
          color: AgaramColors.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          'Submitted $submittedLabel',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AgaramColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        const Icon(
          Icons.insert_drive_file_rounded,
          size: 14,
          color: AgaramColors.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          'File type: $typeLabel',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AgaramColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _memberNote(AgaramTask task) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: AgaramColors.secondaryContainer,
            width: 3,
          ),
        ),
      ),
      child: Text(
        '"${task.memberNote}"',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: AgaramColors.onSurface,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _actionBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: OutlinedButton(
                onPressed: _busy ? null : _reject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AgaramColors.error,
                  side: const BorderSide(
                    color: AgaramColors.error,
                    width: 1.2,
                  ),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: FilledButton.icon(
                onPressed: _busy ? null : _approve,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: AgaramColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  'Approve · +${AppConfig.starsPerApprovedTask} ⭐',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
