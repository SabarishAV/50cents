import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:_50cents/core/theme/app_colors.dart';

/// Renders the branded PNG that is shared or saved when the user taps
/// "Share QR" / "Save QR".
///
/// The image is drawn on a canvas (instead of screenshotting a widget) so it
/// works from dialogs and bottom sheets too, and always comes out at a crisp
/// 1080px width regardless of the device's screen density.
class QrShareImage {
  QrShareImage._();

  static const double _width = 1080;
  static const double _cardTop = 280;
  static const double _cardSize = 800;
  static const double _qrPadding = 56;
  static const Color _ink = Color(0xFF0A1420);

  static ui.Image? _logo;

  static Future<ui.Image?> _loadLogo() async {
    final cached = _logo;
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load('assets/icon/app_icon_v1.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _logo = frame.image;
      return frame.image;
    } catch (_) {
      // A missing asset should never stop the user from sharing the QR.
      return null;
    }
  }

  static Future<Uint8List> build({
    required String data,
    required String payeeName,
    required String paymentId,
    String? amount,
    String? note,
  }) async {
    final logo = await _loadLogo();
    final amountText = amount?.trim() ?? '';
    final noteText = note?.trim() ?? '';
    final hasAmount = amountText.isNotEmpty;
    final hasNote = noteText.isNotEmpty;

    // Lay the text out first so the canvas is exactly the right height.
    var cursor = _cardTop + _cardSize + 46;
    final nameTop = cursor;
    cursor += 58;
    final idTop = cursor;
    cursor += 50;
    double? amountTop;
    if (hasAmount) {
      amountTop = cursor + 6;
      cursor += 98;
    }
    double? noteTop;
    if (hasNote) {
      noteTop = cursor + 2;
      cursor += 46;
    }
    final footerTop = cursor + 34;
    final height = footerTop + 98;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final background = Rect.fromLTWH(0, 0, _width, height);
    canvas.drawRect(
      background,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, height), const [
          Color(0xFF07090C),
          Color(0xFF0C1926),
        ]),
    );
    canvas.drawRect(
      background,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(_width / 2, 30), _width * 0.85, [
          AppColors.neonBlue.withValues(alpha: 0.20),
          AppColors.neonBlue.withValues(alpha: 0),
        ]),
    );

    // Brand mark.
    if (logo != null) {
      final logoRect = Rect.fromLTWH(_width / 2 - 44, 54, 88, 88);
      canvas.drawCircle(
        logoRect.center,
        80,
        Paint()
          ..color = AppColors.neonBlue.withValues(alpha: 0.24)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 28),
      );
      _drawImageRounded(canvas, logo, logoRect, 24);
    }
    _drawText(
      canvas,
      '50cents',
      style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: 2.5),
      centerX: _width / 2,
      top: 158,
    );
    _drawText(
      canvas,
      'UPI payments, simplified',
      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 22, letterSpacing: 0.6),
      centerX: _width / 2,
      top: 208,
    );

    // White QR card.
    final cardRect = Rect.fromLTWH((_width - _cardSize) / 2, _cardTop, _cardSize, _cardSize);
    final cardRRect = RRect.fromRectAndRadius(cardRect, const Radius.circular(56));
    canvas.drawShadow(Path()..addRRect(cardRRect), Colors.black, 30, true);
    canvas.drawRRect(cardRRect, Paint()..color = Colors.white);

    final qrRect = cardRect.deflate(_qrPadding);
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _ink),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _ink),
    );
    canvas.save();
    canvas.translate(qrRect.left, qrRect.top);
    qrPainter.paint(canvas, Size.square(qrRect.width));
    canvas.restore();

    // Small brand mark in the centre. Error correction H keeps the code
    // readable even with the overlay.
    if (logo != null) {
      final center = cardRect.center;
      canvas.drawCircle(center, 64, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        64,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE2E8F0),
      );
      _drawImageRounded(canvas, logo, Rect.fromCenter(center: center, width: 88, height: 88), 24);
    }

    // Payee details below the card.
    _drawText(
      canvas,
      payeeName,
      style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      centerX: _width / 2,
      top: nameTop,
      maxWidth: 900,
    );
    _drawText(
      canvas,
      paymentId,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: 0.4),
      centerX: _width / 2,
      top: idTop,
      maxWidth: 900,
    );

    if (hasAmount) {
      final amountPainter = _painter(
        '₹$amountText',
        const TextStyle(color: Colors.black, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 0.2),
      );
      final pillWidth = math.max(240.0, amountPainter.width + 92);
      final pillRect = Rect.fromCenter(center: Offset(_width / 2, amountTop! + 36), width: pillWidth, height: 76);
      final pillRRect = RRect.fromRectAndRadius(pillRect, const Radius.circular(38));
      canvas.drawRRect(
        pillRRect,
        Paint()
          ..color = AppColors.neonBlue.withValues(alpha: 0.35)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 22),
      );
      canvas.drawRRect(
        pillRRect,
        Paint()
          ..shader = ui.Gradient.linear(pillRect.topLeft, pillRect.topRight, [
            AppColors.neonBlueBright,
            AppColors.neonBlue,
          ]),
      );
      amountPainter.paint(
        canvas,
        Offset(_width / 2 - amountPainter.width / 2, pillRect.center.dy - amountPainter.height / 2),
      );
      amountPainter.dispose();
    }

    if (hasNote) {
      _drawText(
        canvas,
        noteText,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 28, height: 1.3),
        centerX: _width / 2,
        top: noteTop!,
        maxWidth: 860,
      );
    }

    canvas.drawLine(
      Offset(_width / 2 - 36, footerTop),
      Offset(_width / 2 + 36, footerTop),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 2,
    );
    _drawText(
      canvas,
      'Scan with any UPI app',
      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 26, letterSpacing: 0.6),
      centerX: _width / 2,
      top: footerTop + 28,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();

    if (bytes == null) {
      throw StateError('Could not render the QR image.');
    }
    return bytes.buffer.asUint8List();
  }

  static TextPainter _painter(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout();
  }

  static void _drawText(
    Canvas canvas,
    String text, {
    required TextStyle style,
    required double centerX,
    required double top,
    double maxWidth = _width - 144,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(centerX - painter.width / 2, top));
    painter.dispose();
  }

  static void _drawImageRounded(Canvas canvas, ui.Image image, Rect rect, double radius) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }
}
