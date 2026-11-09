import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/neon_background.dart';

import '../providers/auth_provider.dart';

/// Home page — only accessible to authenticated users.
/// Shows a greeting and a logout button that deletes the stored token.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Home'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.expense),
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.pushReplacement('/login');
                }
              },
              tooltip: 'Logout',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home, size: 80, color: AppColors.neonBlue.withValues(alpha: 0.6)),
              const SizedBox(height: 24),
              const Text(
                'Home',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Welcome back', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.income, size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'Authenticated session active',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
