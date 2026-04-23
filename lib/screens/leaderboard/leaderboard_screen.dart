import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final meUid = context.watch<AuthService>().currentUser?.uid;
    final stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('stars', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final users =
                (snap.data?.docs ?? []).map(AppUser.fromFirestore).toList();
            if (users.isEmpty) return const _EmptyState();
            final top3 = users.take(3).toList();
            final rest = users.skip(3).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                const SizedBox(height: 8),
                _Podium(top3: top3),
                const SizedBox(height: 24),
                _headerRow(),
                const SizedBox(height: 8),
                for (int i = 0; i < rest.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LeaderRow(
                      user: rest[i],
                      rank: i + 4,
                      isMe: meUid != null && rest[i].uid == meUid,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _headerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              'RANK',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'MEMBER',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: AgaramColors.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            'STARS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<AppUser> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumBar(user: second, place: 2, height: 150)),
          Expanded(child: _PodiumBar(user: first, place: 1, height: 210)),
          Expanded(child: _PodiumBar(user: third, place: 3, height: 120)),
        ],
      ),
    );
  }
}

class _PodiumBar extends StatelessWidget {
  final AppUser? user;
  final int place;
  final double height;

  const _PodiumBar({
    required this.user,
    required this.place,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final accent = place == 1
        ? AgaramColors.secondary
        : place == 2
            ? const Color(0xFFB0B0B0)
            : const Color(0xFFCD7F32);
    final bg = place == 1
        ? AgaramColors.secondaryContainer
        : place == 2
            ? const Color(0xFFEAEAEA)
            : const Color(0xFFF3D6BC);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: place == 1 ? 40 : 30,
              backgroundColor: AgaramColors.primaryContainer,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? Text(
                      user == null || user!.name.isEmpty
                          ? '·'
                          : user!.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: place == 1 ? 24 : 18,
                      ),
                    )
                  : null,
            ),
            if (place == 1)
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Center(
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: AgaramColors.secondary,
                    size: 28,
                  ),
                ),
              ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$place',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: height,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                user?.stars.toString() ?? '—',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AgaramColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'STARS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          user == null
              ? '—'
              : (user!.name.isEmpty ? 'Member' : user!.name.split(' ').first),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AgaramColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final AppUser user;
  final int rank;
  final bool isMe;

  const _LeaderRow({
    required this.user,
    required this.rank,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AgaramColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: AgaramColors.primary, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              rank.toString(),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AgaramColors.primary,
              ),
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: AgaramColors.primaryContainer,
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.name.isEmpty ? '·' : user.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe
                      ? 'You · ${user.name.split(' ').first}'
                      : (user.name.isEmpty ? 'Member' : user.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AgaramColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AgaramColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.stars.toString(),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AgaramColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: AgaramColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: AgaramColors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Leaderboard is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Earn your first star by completing a task or attending an event.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AgaramColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
