import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/members_service.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../widgets/role_chip.dart';
import 'add_member_sheet.dart';

class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

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
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = (snap.data?.docs ?? [])
                      .map(AppUser.fromFirestore)
                      .toList();
                  final filtered = _query.isEmpty
                      ? users
                      : users.where((u) =>
                          u.name.toLowerCase().contains(_query) ||
                          u.email.toLowerCase().contains(_query)).toList();
                  final totals = _totals(users);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    children: [
                      _summary(totals),
                      const SizedBox(height: 20),
                      for (final u in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MemberCard(
                            user: u,
                            viewerIsPresident: me?.isPresident ?? false,
                          ),
                        ),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'No members match your search.',
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

  ({int members, int admins, int presidents}) _totals(List<AppUser> users) {
    var admins = 0;
    var presidents = 0;
    for (final u in users) {
      if (u.isPresident) {
        presidents++;
        admins++;
      } else if (u.isAdmin) {
        admins++;
      }
    }
    return (
      members: users.length,
      admins: admins,
      presidents: presidents,
    );
  }

  Widget _summary(
    ({int members, int admins, int presidents}) totals,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill('${totals.members} members', Icons.people_alt_rounded,
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
    return Container(
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
                RoleChip(user: user),
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
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, String value) async {
    try {
      if (value == 'promote') {
        await MembersService.setRole(user.uid, role: 'admin');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} is now an admin.')),
        );
      } else if (value == 'demote') {
        await MembersService.setRole(user.uid, role: 'member');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} is now a member.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t update: $e')),
      );
    }
  }
}
