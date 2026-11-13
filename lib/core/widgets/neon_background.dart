import 'package:material_ui/material_ui.dart';
import 'package:_50cents/core/theme/app_colors.dart';

/// A reusable background with dim neon blue vertical and horizontal lines
/// forming a subtle grid. All lines are dim — no bright ones.
///
/// Usage:
///   NeonBackground(child: Scaffold(...))
class NeonBackground extends StatelessWidget {
  final Widget child;
  const NeonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.15,
          colors: [
            Color(0xFF0E0E16), // very subtle center glow
            AppColors.background, // 0xFF0A0A0A edges
          ],
        ),
      ),
      child: CustomPaint(painter: const NeonGridPainter(), size: Size.infinite, willChange: false, child: child),
    );
  }
}

/// Paints dim neon blue vertical and horizontal lines forming squares.
/// All lines are dim — no bright ones.
class NeonGridPainter extends CustomPainter {
  const NeonGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 56.0;

    // Vertical lines — all dim
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = AppColors.neonBlue.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Horizontal lines — all dim
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = AppColors.neonBlue.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Soft center glow — very dim
    final centerGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [AppColors.neonBlue.withValues(alpha: 0.05), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, centerGlow);
  }

  @override
  bool shouldRepaint(covariant NeonGridPainter oldDelegate) => false;
}
