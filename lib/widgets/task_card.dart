import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/task.dart';
import 'status_chip.dart';

class TaskCard extends StatelessWidget {
  final AgaramTask task;
  final bool adminView;
  final String? currentUid;
  final VoidCallback? onTap;
  final VoidCallback? onUploadProof;

  const TaskCard({
    super.key,
    required this.task,
    this.adminView = false,
    this.currentUid,
    this.onTap,
    this.onUploadProof,
  });

  bool get _isMine => currentUid != null && task.assignedTo == currentUid;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AgaramColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(status: task.status),
                const Spacer(),
                Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AgaramColors.onSurface,
                height: 1.3,
              ),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AgaramColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _assigneeRow(),
            const SizedBox(height: 12),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _assigneeRow() {
    final name = task.assignedToName.isEmpty
        ? 'unassigned'
        : task.assignedToName;
    final label = _isMine ? 'Assigned to you' : 'Assigned to $name';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _isMine
            ? AgaramColors.secondaryContainer
            : AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 14,
            color: _isMine
                ? AgaramColors.secondary
                : AgaramColors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isMine
                  ? AgaramColors.secondary
                  : AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (task.status == TaskStatus.approved) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: AgaramColors.success),
          const SizedBox(width: 6),
          Text(
            'Approved +${task.starsAwarded} stars',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AgaramColors.success,
            ),
          ),
          const Spacer(),
          Text(
            'Completed',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    if (task.status == TaskStatus.submitted) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(adminView ? 'Review' : (_isMine ? 'View submission' : 'View'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AgaramColors.primary,
                  )),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AgaramColors.primary,
              ),
            ],
          ),
        ),
      );
    }
    // pending or rejected
    return Row(
      children: [
        if (task.dueDate != null) ...[
          const Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: AgaramColors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'Due ${DateFormat('MMM d').format(task.dueDate!)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        if (!adminView && _isMine && onUploadProof != null)
          TextButton(
            onPressed: onUploadProof,
            child: Text(
              task.status == TaskStatus.rejected
                  ? 'Upload again'
                  : 'Upload proof',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AgaramColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
