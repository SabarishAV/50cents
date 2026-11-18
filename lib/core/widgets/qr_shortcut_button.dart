import 'package:material_ui/material_ui.dart';

import 'package:_50cents/core/theme/app_colors.dart';

/// Compact "My QR" shortcut shared by the home and scanner screens.
class QrShortcutButton extends StatelessWidget {
  const QrShortcutButton({super.key, required this.onTap, this.tooltip = 'My QR'});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: AppColors.neonBlue, size: 20),
          ),
        ),
      ),
    );
  }
}
