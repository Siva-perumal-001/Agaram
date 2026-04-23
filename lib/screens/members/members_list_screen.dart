import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/members_service.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../widgets/role_chip.dart';
import '../../widgets/stream_error_view.dart';
import 'add_member_sheet.dart';

class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showInactive = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().currentUser;
    final stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('name')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search members by name or email…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (_, snap) {
                  if (snap.hasError) {
                    return const StreamErrorView(
                      message: "Couldn't load members.",
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = (snap.data?.docs ?? [])
                      .map(AppUser.fromFirestore)
                      .toList();
                  final visible = users.where((u) {
                    if (!_showInactive && !u.active) return false;
                    if (_query.isEmpty) return true;
                    return u.name.toLowerCase().contains(_query) ||
                        u.email.toLowerCase().contains(_query);
                  }).toList();
                  final totals = _totals(users);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    children: [
                      _summary(totals),
                      const SizedBox(height: 16),
                      _filterRow(totals.inactive),
                      const SizedBox(height: 12),
                      for (final u in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MemberCard(
                            user: u,
                            viewerIsPresident: me?.isPresident ?? false,
                          ),
                        ),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'No members match.',
                              style: GoogleFonts.inter(
                                color: AgaramColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AgaramColors.secondary,
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AgaramColors.surface,
            showDragHandle: true,
            builder: (_) => const AddMemberSheet(),
          );
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Member'),
      ),
    );
  }

  ({int members, int admins, int presidents, int inactive}) _totals(
      List<AppUser> users) {
    var admins = 0;
    var presidents = 0;
    var inactive = 0;
    for (final u in users) {
      if (!u.active) inactive++;
      if (u.isPresident) {
        presidents++;
        admins++;
      } else if (u.isAdmin) {
        admins++;
      }
    }
    return (
      members: users.length - inactive,
      admins: admins,
      presidents: presidents,
      inactive: inactive,
    );
  }

  Widget _summary(
    ({int members, int admins, int presidents, int inactive}) totals,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill('${totals.members} active', Icons.people_alt_rounded,
            AgaramColors.secondaryContainer, AgaramColors.secondary),
        _pill('${totals.admins} admins', Icons.shield_rounded,
            AgaramColors.primaryContainer.withValues(alpha: 0.18),
            AgaramColors.primary),
        _pill('${totals.presidents} president',
            Icons.workspace_premium_rounded,
            AgaramColors.surfaceContainerLow, AgaramColors.primary),
      ],
    );
  }

  Widget _filterRow(int inactiveCount) {
    if (inactiveCount == 0 && !_showInactive) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: FilterChip(
        label: Text(
          _showInactive
              ? 'Showing inactive ($inactiveCount)'
              : 'Show inactive ($inactiveCount)',
        ),
        selected: _showInactive,
        onSelected: (v) => setState(() => _showInactive = v),
        backgroundColor: AgaramColors.surfaceContainerLow,
        selectedColor: AgaramColors.secondaryContainer,
        checkmarkColor: AgaramColors.secondary,
      ),
    );
  }

  Widget _pill(String label, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final AppUser user;
  final bool viewerIsPresident;
  const _MemberCard({required this.user, required this.viewerIsPresident});

  @override
  Widget build(BuildContext context) {
    final dim = !user.active;
    return Opacity(
      opacity: dim ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: user.isPresident
              ? const Border(
                  left: BorderSide(color: AgaramColors.secondary, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AgaramColors.primaryContainer,
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                      user.name.isEmpty ? 'A' : user.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name.isEmpty ? 'Member' : user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AgaramColors.onSurface,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AgaramColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.stars.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AgaramColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AgaramColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoleChip(user: user, compact: true),
                      if (dim) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AgaramColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Inactive',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AgaramColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!user.isPresident)
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AgaramColors.onSurfaceVariant,
                ),
                onSelected: (value) => _handle(context, value),
                itemBuilder: (_) => [
                  if (user.isAdmin && viewerIsPresident)
                    const PopupMenuItem(
                      value: 'demote',
                      child: Text('Demote to member'),
                    ),
                  if (!user.isAdmin)
                    const PopupMenuItem(
                      value: 'promote',
                      child: Text('Promote to admin'),
                    ),
                  const PopupMenuItem(
                    value: 'position',
                    child: Text('Change position'),
                  ),
                  if (user.active)
                    const PopupMenuItem(
                      value: 'deactivate',
                      child: Text('Deactivate account'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Text('Reactivate account'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, String value) async {
    try {
      if (value == 'promote') {
        await MembersService.setRole(user.uid, role: 'admin');
        if (!context.mounted) return;
        _toast(context, '${user.name} is now an admin.');
      } else if (value == 'demote') {
        await MembersService.setRole(user.uid, role: 'member');
        if (!context.mounted) return;
        _toast(context, '${user.name} is now a member.');
      } else if (value == 'position') {
        final picked = await _pickPosition(context);
        if (picked == null || picked.cancelled) return;
        await MembersService.setPosition(user.uid, position: picked.value);
        if (!context.mounted) return;
        _toast(
          context,
          '${user.name} is now ${picked.value == null ? 'unassigned' : AppPosition.label(picked.value!)}.',
        );
      } else if (value == 'deactivate') {
        final confirm = await _confirm(
          context,
          'Deactivate ${user.name}?',
          'They will be signed out and blocked from signing back in. All their history stays. You can reactivate later.',
          destructive: true,
        );
        if (confirm != true) return;
        await MembersService.deactivate(user.uid);
        if (!context.mounted) return;
        _toast(context, '${user.name} has been deactivated.');
      } else if (value == 'reactivate') {
        await MembersService.reactivate(user.uid);
        if (!context.mounted) return;
        _toast(context, '${user.name} can sign in again.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, 'Couldn’t update: $e');
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<_PositionPick?> _pickPosition(BuildContext context) async {
    return showDialog<_PositionPick>(
      context: context,
      builder: (ctx) {
        String? selection = user.position;
        return StatefulBuilder(
          builder: (_, setState) => AlertDialog(
            title: const Text('Change position'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _positionTile(null, 'None', selection,
                      (v) => setState(() => selection = v)),
                  for (final p in AppPosition.all)
                    _positionTile(
                      p,
                      AppPosition.label(p),
                      selection,
                      (v) => setState(() => selection = v),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(
                  const _PositionPick.cancel(),
                ),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(
                  _PositionPick(value: selection),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionTile(
    String? value,
    String label,
    String? selection,
    ValueChanged<String?> onSelect,
  ) {
    return InkWell(
      onTap: () => onSelect(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selection == value
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selection == value
                  ? AgaramColors.primary
                  : AgaramColors.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context,
    String title,
    String body, {
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AgaramColors.error)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(destructive ? 'Deactivate' : 'OK'),
          ),
        ],
      ),
    );
  }
}

class _PositionPick {
  final String? value;
  final bool cancelled;
  const _PositionPick({this.value}) : cancelled = false;
  const _PositionPick.cancel()
      : value = null,
        cancelled = true;
}
