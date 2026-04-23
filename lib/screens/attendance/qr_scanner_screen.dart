import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/attendance_service.dart';
import '../../core/auth_service.dart';
import '../../core/theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

enum _ScanState { scanning, success, error }

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  _ScanState _state = _ScanState.scanning;
  String _errorMsg = '';
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _state != _ScanState.scanning) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    final payload = AttendanceQrPayload.tryDecode(raw);
    if (payload == null) {
      setState(() {
        _state = _ScanState.error;
        _errorMsg = 'That doesn’t look like an Agaram attendance QR.';
      });
      return;
    }

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _processing = true);
    try {
      await AttendanceService.checkInWithQr(
        payload: payload,
        memberUid: user.uid,
        memberName: user.name.isEmpty ? user.email : user.name,
      );
      if (!mounted) return;
      setState(() {
        _state = _ScanState.success;
        _processing = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMsg = e.message;
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMsg = 'Something went wrong: $e';
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151010),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Scan to Check In',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, state, _) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  color: Colors.white,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _scannerOverlay(),
          if (_state == _ScanState.success) _SuccessOverlay(onDone: _close),
          if (_state == _ScanState.error)
            _ErrorOverlay(
              message: _errorMsg,
              onRetry: () {
                setState(() => _state = _ScanState.scanning);
              },
              onClose: _close,
            ),
        ],
      ),
    );
  }

  void _close() => Navigator.of(context).pop(_state == _ScanState.success);

  Widget _scannerOverlay() {
    return SafeArea(
      child: Column(
        children: [
          const Expanded(flex: 2, child: SizedBox.shrink()),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AgaramColors.secondaryContainer,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  "Point at the QR your admin is showing.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Stay within the frame · Good lighting helps',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(flex: 2, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessOverlay({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 110,
                width: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                "You're marked present",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AgaramColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AgaramColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${AppConfig.starsPerAttendance} stars',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AgaramColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Your attendance has been recorded. Have fun at the session!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onDone,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 110,
                width: 110,
                decoration: BoxDecoration(
                  color: AgaramColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AgaramColors.error, width: 2),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 52,
                  color: AgaramColors.error,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Can’t check you in',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onClose,
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
