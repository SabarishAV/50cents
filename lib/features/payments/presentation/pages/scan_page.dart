import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/features/payments/data/upi_payment.dart';
import 'package:_50cents/features/payments/presentation/widgets/pay_sheet.dart';

/// Camera screen that reads a UPI payment QR, then hands the payee to the
/// user's installed UPI app.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final MobileScannerController _controller;
  bool _handled = false;
  bool _torchOn = false;
  String? _message;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    _messageTimer?.cancel();
    setState(() => _message = message);
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _restartScanner() async {
    _handled = false;
    try {
      await _controller.start();
    } catch (_) {
      // The error builder already surfaces camera problems.
    }
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handled) return;

    UpiPayment? payment;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      payment = UpiPayment.tryParse(raw);
      if (payment != null) break;
    }

    if (payment == null) {
      if (_message == null) {
        _showMessage('That QR is not a UPI payment code. Try again.');
      }
      return;
    }

    _handled = true;
    try {
      await _controller.stop();
    } catch (_) {
      // Ignore — the camera may already be paused by the OS.
    }

    if (!mounted) return;

    final launched = await showPaySheet(context, target: PayTarget.upi, scanned: payment);
    if (!mounted) return;

    if (launched) {
      context.pop();
    } else {
      await _restartScanner();
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Torch is optional; ignore failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
            onDetectError: (error, stackTrace) {
              if (mounted) _showMessage('Could not read the QR. Try again.');
            },
            errorBuilder: (context, error) {
              final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
              return ColoredBox(
                color: AppColors.background,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          denied ? Icons.no_photography_outlined : Icons.camera_alt_outlined,
                          color: AppColors.textMuted,
                          size: 46,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          denied
                              ? 'Camera permission is required to scan UPI QR codes.'
                              : 'Could not start the camera.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Allow camera access in your device settings, then try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 22),
                        TextButton(
                          onPressed: _restartScanner,
                          style: TextButton.styleFrom(foregroundColor: AppColors.neonBlue),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Dim the area outside the scan window for focus.
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: const _ScanOverlayPainter())),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      _RoundIconButton(icon: Icons.close_rounded, tooltip: 'Close', onPressed: () => context.pop()),
                      const Expanded(
                        child: Text(
                          'Scan any UPI QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      _RoundIconButton(
                        icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        tooltip: 'Flash',
                        active: _torchOn,
                        onPressed: _toggleTorch,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_message != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.neonBlue, size: 18),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(_message!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                Container(
                  margin: const EdgeInsets.fromLTRB(28, 0, 28, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: AppColors.neonBlue, size: 20),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Point your camera at a UPI payment QR. You can review the payee before paying.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onPressed, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: active ? AppColors.neonBlue : AppColors.textPrimary, size: 22),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter();

  static const _cornerRadius = 24.0;
  static const _bracketArm = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final windowSize = size.width.clamp(220.0, 300.0).toDouble();
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: windowSize,
      height: windowSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_cornerRadius));

    // Dim everything outside the scan window.
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // Soft glow so the window feels lit from within.
    canvas.save();
    canvas.clipRRect(rrect);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.neonBlue.withValues(alpha: 0.16), Colors.transparent],
        stops: const [0.0, 0.9],
      ).createShader(rect);
    canvas.drawRect(rect, glow);
    canvas.restore();

    // Hairline border to define the window edge.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Corner brackets that follow the rounded window corners.
    final accent = Paint()
      ..color = AppColors.neonBlueBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    const r = _cornerRadius;
    const arm = _bracketArm;
    const radius = Radius.circular(r);

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + r + arm)
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(Offset(rect.left + r, rect.top), radius: radius, clockwise: true)
        ..lineTo(rect.left + r + arm, rect.top),
      accent,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.top + r + arm)
        ..lineTo(rect.right, rect.top + r)
        ..arcToPoint(Offset(rect.right - r, rect.top), radius: radius, clockwise: false)
        ..lineTo(rect.right - r - arm, rect.top),
      accent,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.bottom - r - arm)
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: radius, clockwise: true)
        ..lineTo(rect.right - r - arm, rect.bottom),
      accent,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - r - arm)
        ..lineTo(rect.left, rect.bottom - r)
        ..arcToPoint(Offset(rect.left + r, rect.bottom), radius: radius, clockwise: false)
        ..lineTo(rect.left + r + arm, rect.bottom),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => false;
}
