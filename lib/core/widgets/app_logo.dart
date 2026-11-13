import 'package:material_ui/material_ui.dart';

import 'package:_50cents/core/theme/app_colors.dart';

/// The real app icon, shown with the same neon glow used throughout the UI.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.radius = 16});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withValues(alpha: 0.28),
            blurRadius: size * 0.42,
            spreadRadius: size * 0.02,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Image.asset(
          'assets/icon/app_icon_v1.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
