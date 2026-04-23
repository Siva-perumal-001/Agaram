import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/auth_service.dart';
import '../../core/cloudinary_service.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../widgets/achievement_badge.dart';
import '../../widgets/info_row.dart';
import '../../widgets/role_chip.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'signout') {
                await _signOut(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _AvatarPicker(user: user),
              const SizedBox(height: 20),
              Text(
                user.name.isEmpty ? '—' : user.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AgaramColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Center(child: RoleChip(user: user)),
              const SizedBox(height: 28),
              _StarsSummary(user: user),
              const SizedBox(height: 28),
              Text(
                'ACHIEVEMENTS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              _achievementsStrip(user),
              const SizedBox(height: 28),
              _personalInfo(user),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                key: const Key('profile-signout'),
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AgaramColors.primary,
                  side: const BorderSide(
                    color: AgaramColors.primary,
                    width: 1.2,
                  ),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _achievementsStrip(AppUser user) {
    final stars = user.stars;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        AchievementBadge(
          icon: Icons.emoji_events_rounded,
          label: 'First Task',
          color: AgaramColors.secondaryContainer,
          unlocked: stars >= 3,
        ),
        AchievementBadge(
          icon: Icons.event_available_rounded,
          label: '5 Events',
          color: AgaramColors.infoSoft,
          unlocked: stars >= 10,
        ),
        AchievementBadge(
          icon: Icons.edit_note_rounded,
          label: 'Poet',
          color: AgaramColors.accentPeach,
          unlocked: false,
        ),
        AchievementBadge(
          icon: Icons.workspace_premium_rounded,
          label: '10 Stars',
          color: AgaramColors.secondaryContainer,
          unlocked: stars >= 10,
        ),
      ],
    );
  }

  Widget _personalInfo(AppUser user) {
    return Container(
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InfoRow(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: user.phone ?? '—',
          ),
          const Divider(
            height: 1,
            thickness: 0.6,
            color: AgaramColors.outlineVariant,
            indent: 20,
            endIndent: 20,
          ),
          InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Joined Date',
            value: _formatDate(user.joinedAt),
          ),
          const Divider(
            height: 1,
            thickness: 0.6,
            color: AgaramColors.outlineVariant,
            indent: 20,
            endIndent: 20,
          ),
          InfoRow(
            icon: Icons.school_rounded,
            label: 'Role',
            value: user.isPresident
                ? 'Club President'
                : (user.isAdmin ? 'Club Admin' : 'Member'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _signOut(BuildContext context) async {
    await context.read<AuthService>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.login,
      (_) => false,
    );
  }
}

class _AvatarPicker extends StatefulWidget {
  final AppUser user;
  const _AvatarPicker({required this.user});

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await CloudinaryService.uploadAvatar(File(picked.path));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'photoUrl': url});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t update photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Center(
      child: GestureDetector(
        onTap: _pick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 104,
              width: 104,
              decoration: BoxDecoration(
                color: AgaramColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AgaramColors.surface, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AgaramColors.primary.withValues(alpha: 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: user.photoUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user.photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AgaramColors.primaryContainer,
                        ),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        'அ',
                        style: GoogleFonts.notoSerifTamil(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: AgaramColors.secondaryContainer,
                        ),
                      ),
                    ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: AgaramColors.secondaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AgaramColors.surface, width: 2),
                ),
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AgaramColors.secondary,
                        ),
                      )
                    : const Icon(
                        Icons.photo_camera_rounded,
                        size: 16,
                        color: AgaramColors.secondary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarsSummary extends StatelessWidget {
  final AppUser user;
  const _StarsSummary({required this.user});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        final stars = (snap.data?.data()?['stars'] as num?)?.toInt() ?? user.stars;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AgaramColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AgaramColors.primary.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 24,
                    color: AgaramColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$stars Stars Earned',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AgaramColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _LiveCountBreakdown(
                      stream: FirebaseFirestore.instance
                          .collectionGroup('tasks')
                          .where('assignedTo', isEqualTo: user.uid)
                          .where('status', isEqualTo: 'approved')
                          .snapshots(),
                      label: 'Tasks',
                      subLabel: (n) =>
                          'approved (+${n * AppConfig.starsPerApprovedTask})',
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      color: AgaramColors.outlineVariant,
                      thickness: 0.8,
                    ),
                  ),
                  Expanded(
                    child: _LiveCountBreakdown(
                      stream: FirebaseFirestore.instance
                          .collectionGroup('attendance')
                          .where('userId', isEqualTo: user.uid)
                          .snapshots(),
                      label: 'Events',
                      subLabel: (n) =>
                          'attended (+${n * AppConfig.starsPerAttendance})',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

}

class _LiveCountBreakdown extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String label;
  final String Function(int count) subLabel;

  const _LiveCountBreakdown({
    required this.stream,
    required this.label,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count $label',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AgaramColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subLabel(count),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
