import 'package:flutter/material.dart';

import 'package:_50cents/core/theme/app_colors.dart';
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
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.neonBlue.withValues(alpha: 0.95), AppColors.neonBlue.withValues(alpha: 0.5)],
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 2),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  '50¢',
                  style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
              ),
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
