import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/utils/payment_link.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/auth/data/user_repository.dart';
import 'package:_50cents/features/payments/data/upi_payment.dart';
import 'package:_50cents/features/payments/presentation/widgets/pay_sheet.dart';
import 'package:_50cents/features/payments/presentation/widgets/payment_ui.dart';

/// Camera screen that reads a UPI payment QR, then hands the payee to the
/// user's installed UPI app.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  late final MobileScannerController _controller;
  final ImagePicker _imagePicker = ImagePicker();

  /// QR payload for the small "My QR" thumbnail in the header.
  String? _myQrData;

  bool _handled = false;
  bool _torchOn = false;
  bool _readingImage = false;
  String? _message;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
    _loadMyQr();
  }

  /// Loads the signed-in user's payment ID so the thumbnail shows their real
  /// QR. If the profile cannot be loaded the thumbnail falls back to an icon.
  Future<void> _loadMyQr() async {
    try {
      final user = await ref.read(userRepositoryProvider).getUser();
      if (!mounted || user.paymentId.isEmpty) return;
      setState(() {
        _myQrData = generateUpiUri(pa: user.paymentId, pn: user.displayName);
      });
    } catch (_) {
      // The thumbnail still navigates to My QR even without a preview.
    }
  }

  /// Pauses the camera while the full "My QR" page is open, then resumes it.
  Future<void> _openMyQr() async {
    try {
      await _controller.stop();
    } catch (_) {
      // The camera may already be stopped.
    }
    if (!mounted) return;
    await context.push('/qr-payment');
    if (!mounted) return;
    await _restartScanner();
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

    final payment = _paymentFromCapture(capture);
    if (payment == null) {
      if (_message == null) {
        _showMessage('That QR is not a UPI payment code. Try another one.');
      }
      return;
    }

    await _completeScan(payment);
  }

  /// Picks the first UPI payment encoded in a capture, if any.
  UpiPayment? _paymentFromCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final payment = UpiPayment.tryParse(raw);
      if (payment != null) return payment;
    }
    return null;
  }

  /// Opens the pay sheet for [payment], then leaves the page or resumes the
  /// camera depending on what the user did.
  Future<void> _completeScan(UpiPayment payment) async {
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

  /// Reads a UPI QR from a photo or screenshot picked from the gallery.
  Future<void> _scanFromGallery() async {
    if (_handled || _readingImage) return;

    setState(() => _readingImage = true);

    try {
      final XFile? picked;
      try {
        picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      } catch (_) {
        if (mounted) _showMessage('Could not open your photos. Try again.');
        return;
      }

      if (picked == null || !mounted) return;

      UpiPayment? payment;
      try {
        final capture = await _controller.analyzeImage(picked.path, formats: const [BarcodeFormat.qrCode]);
        if (capture != null) payment = _paymentFromCapture(capture);
      } on UnsupportedError {
        if (mounted) _showMessage('Reading photos is not supported on this device. Use the camera instead.');
        return;
      } catch (_) {
        if (mounted) _showMessage('Could not read that image. Try another photo.');
        return;
      }

      if (!mounted) return;

      if (payment == null) {
        _showMessage('No UPI QR code found in that image. Try another photo.');
        return;
      }

      setState(() => _readingImage = false);
      await _completeScan(payment);
    } finally {
      if (mounted && _readingImage) setState(() => _readingImage = false);
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
              return Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [Color(0xFF0E1018), AppColors.background],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PaymentIconBadge(
                          icon: denied ? Icons.no_photography_outlined : Icons.camera_alt_outlined,
                          size: 68,
                          radius: 22,
                          color: denied ? AppColors.expense : AppColors.neonBlue,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          denied ? 'Camera access is off' : 'Could not start the camera',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          denied
                              ? 'Allow camera access in your device settings to scan UPI QR codes.'
                              : 'Something blocked the camera. Close other camera apps and try again.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: 172,
                          child: NeonButton(
                            label: 'Try again',
                            icon: Icons.refresh_rounded,
                            onPressed: _restartScanner,
                            height: 48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Dims everything outside the scan window.
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: const _ScanOverlayPainter())),
          ),

          // A soft vignette keeps the header and footer readable over the camera.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.0, 0.22, 0.66, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      _GlassIconButton(icon: Icons.close_rounded, tooltip: 'Close', onPressed: () => context.pop()),
                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Scan to pay',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Point at any UPI QR',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MyQrButton(data: _myQrData, onTap: _openMyQr),
                          const SizedBox(width: 8),
                          _GlassIconButton(
                            icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            tooltip: 'Flash',
                            active: _torchOn,
                            onPressed: _toggleTorch,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _message == null
                      ? const SizedBox(key: ValueKey<String>('no-message'), height: 0)
                      : Container(
                          key: ValueKey<String>(_message!),
                          margin: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.neonBlue, size: 18),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _message!,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _GalleryScanTile(onTap: _scanFromGallery),
                ),
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _PulsingDot(),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Looking for a UPI code',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          PaymentPill(label: 'Live', icon: Icons.bolt_rounded, color: AppColors.income, fontSize: 9.5),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 12),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'You finish the payment securely inside your own UPI app.',
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.9),
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Blocks the camera preview while a picked photo is being decoded.
          if (_readingImage)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.neonBlueBright),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Reading photo…',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small QR preview that opens the full "My QR" page.
class _MyQrButton extends StatelessWidget {
  const _MyQrButton({required this.data, required this.onTap});

  final String? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'My QR',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.55)),
            ),
            child: data == null
                ? const Icon(Icons.qr_code_2_rounded, color: AppColors.neonBlue, size: 20)
                : QrImageView(
                    data: data!,
                    version: QrVersions.auto,
                    size: 32,
                    padding: EdgeInsets.zero,
                    gapless: true,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0A1420),
                    ),
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0A1420)),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onPressed, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.neonBlue.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.42),
      shape: CircleBorder(
        side: BorderSide(
          color: active ? AppColors.neonBlue.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: active ? AppColors.neonBlueBright : AppColors.textPrimary, size: 21),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = 0.25 + _controller.value * 0.5;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.income,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.income.withValues(alpha: glow), blurRadius: 10, spreadRadius: 1)],
          ),
        );
      },
    );
  }
}

class _GalleryScanTile extends StatelessWidget {
  const _GalleryScanTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neonBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              const PaymentIconBadge(icon: Icons.photo_library_outlined, size: 36, radius: 11),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan from photo',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Use a screenshot or saved QR from your gallery',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter();

  static const double _cornerRadius = 26;
  static const double _bracketArm = 30;

  @override
  void paint(Canvas canvas, Size size) {
    // Keep the window square but never taller than the camera preview allows.
    final maxSize = (size.height * 0.4).clamp(160.0, 300.0).toDouble();
    final windowSize = size.width < maxSize ? size.width : maxSize;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.43),
      width: windowSize,
      height: windowSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_cornerRadius));

    // Dim everything outside the scan window.
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.58);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    canvas.save();
    canvas.clipRRect(rrect);

    // Soft glow so the window feels lit from within.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.neonBlue.withValues(alpha: 0.18), Colors.transparent],
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

    const radius = Radius.circular(_cornerRadius);
    const arm = _bracketArm;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + _cornerRadius + arm)
        ..lineTo(rect.left, rect.top + _cornerRadius)
        ..arcToPoint(Offset(rect.left + _cornerRadius, rect.top), radius: radius, clockwise: true)
        ..lineTo(rect.left + _cornerRadius + arm, rect.top),
      accent,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.top + _cornerRadius + arm)
        ..lineTo(rect.right, rect.top + _cornerRadius)
        ..arcToPoint(Offset(rect.right - _cornerRadius, rect.top), radius: radius, clockwise: false)
        ..lineTo(rect.right - _cornerRadius - arm, rect.top),
      accent,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.bottom - _cornerRadius - arm)
        ..lineTo(rect.right, rect.bottom - _cornerRadius)
        ..arcToPoint(Offset(rect.right - _cornerRadius, rect.bottom), radius: radius, clockwise: true)
        ..lineTo(rect.right - _cornerRadius - arm, rect.bottom),
      accent,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - _cornerRadius - arm)
        ..lineTo(rect.left, rect.bottom - _cornerRadius)
        ..arcToPoint(Offset(rect.left + _cornerRadius, rect.bottom), radius: radius, clockwise: false)
        ..lineTo(rect.left + _cornerRadius + arm, rect.bottom),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => false;
}
