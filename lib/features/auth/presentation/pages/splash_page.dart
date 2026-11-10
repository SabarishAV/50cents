import 'package:flutter/material.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/app_logo.dart';
import 'package:_50cents/core/widgets/neon_background.dart';

/// Shown while the persisted session is being read from secure storage.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 76, radius: 22),
              const SizedBox(height: 22),
              const Text(
                '50cents',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
