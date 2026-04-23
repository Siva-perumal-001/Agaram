import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/attendance_service.dart';
import '../../core/event_service.dart';
import '../../core/theme.dart';
import '../../models/event.dart';

class QrDisplayScreen extends StatefulWidget {
  final AgaramEvent event;
  const QrDisplayScreen({super.key, required this.event});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen>
    with SingleTickerProviderStateMixin {
  static const _rotateEvery = Duration(minutes: 2);

  String? _secret;
  bool _rotating = true;
  Timer? _timer;
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: _rotateEvery)..forward();
    _rotate();
    _timer = Timer.periodic(_rotateEvery, (_) => _rotate());
  }

  Future<void> _rotate() async {
    try {
      final newSecret = await AttendanceService.rotateQrSecret(widget.event.id);
      if (!mounted) return;
      setState(() {
        _secret = newSecret;
        _rotating = false;
      });
      _ring
        ..reset()
        ..forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _rotating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t refresh QR: $e')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgaramColors.primary,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(
          'Attendance QR',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AgaramColors.primary, AgaramColors.primaryContainer],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.event.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: AgaramColors.secondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _qrCard(),
                  ),
                ),
              ),
              _LiveCount(eventId: widget.event.id),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_rotating || _secret == null)
            const SizedBox(
              height: 280,
              width: 280,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 280,
              width: 280,
              child: QrImageView(
                data: AttendanceQrPayload(
                  eventId: widget.event.id,
                  secret: _secret!,
                ).encode(),
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AgaramColors.primary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AgaramColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: AnimatedBuilder(
                  animation: _ring,
                  builder: (_, _) => CircularProgressIndicator(
                    value: 1 - _ring.value,
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation(
                      AgaramColors.secondary,
                    ),
                    backgroundColor:
                        AgaramColors.secondaryContainer.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Refreshes every 2 min',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveCount extends StatelessWidget {
  final String eventId;
  const _LiveCount({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AttendanceService.attendance(eventId).snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AgaramColors.secondary.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'member' : 'members'} checked in',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AgaramColors.secondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
