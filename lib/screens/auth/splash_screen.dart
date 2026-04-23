import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _minDurationElapsed = false;
  bool _routed = false;
  AuthService? _auth;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _minDurationElapsed = true;
        _tryRoute();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= context.read<AuthService>()..addListener(_tryRoute);
    _tryRoute();
  }

  void _tryRoute() {
    if (_routed || !mounted) return;
    final auth = _auth;
    if (auth == null) return;
    if (!_minDurationElapsed) return;
    if (auth.status == AuthStatus.unknown) return;

    _routed = true;
    final target = auth.status == AuthStatus.authenticated
        ? Routes.home
        : Routes.login;
    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  void dispose() {
    _auth?.removeListener(_tryRoute);
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgaramColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: _CornerBracket(color: AgaramColors.outlineVariant),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: Transform.rotate(
                angle: 3.14159,
                child: _CornerBracket(color: AgaramColors.outlineVariant),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Image.asset(
                    'assets/icon/agaram_logo.png',
                    width: 280,
                    height: 280,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tamil Ilakiya Mandram',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: AgaramColors.secondary,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        return LinearProgressIndicator(
                          value: _progressController.value,
                          minHeight: 2,
                          backgroundColor:
                              AgaramColors.secondaryContainer.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AgaramColors.secondaryContainer,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 16,
                        color: AgaramColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TRADITION REDEFINED',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                          color: AgaramColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final Color color;
  const _CornerBracket({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(72, 72),
      painter: _BracketPainter(color: color),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  _BracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 16)
      ..arcToPoint(
        Offset(16, 0),
        radius: const Radius.circular(16),
        clockwise: true,
      )
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
