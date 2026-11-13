import 'package:material_ui/material_ui.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/app_logo.dart';
import 'package:_50cents/core/widgets/neon_background.dart';

/// Shared chrome for the login / register screens: neon background, brand
/// header, a single elevated card and a footer slot. Keeps both pages visually
/// consistent and centered on tablets/web.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.title, required this.subtitle, required this.child, required this.footer});

  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.04), blurRadius: 48, spreadRadius: 2),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4)),
                          const SizedBox(height: 26),
                          child,
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    footer,
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppLogo(size: 66, radius: 19),
        const SizedBox(height: 16),
        const Text(
          '50cents',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        const Text('Track every cent.', style: TextStyle(color: AppColors.textMuted, fontSize: 13, letterSpacing: 0.4)),
      ],
    );
  }
}

/// "──────  or continue with  ──────" separator.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'Or continue with'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}

/// Inline, dismissible-looking error banner used by both auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.expense, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
