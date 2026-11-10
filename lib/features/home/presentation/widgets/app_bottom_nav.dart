import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';

enum AppTab { home, profile }

/// UPI-style bottom bar with Home, a central Scan action and Profile.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});

  final AppTab current;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.98),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: current == AppTab.home,
                  onTap: () => context.go('/home'),
                ),
              ),
              _ScanButton(onTap: () => context.push('/scan')),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: current == AppTab.profile,
                  onTap: () => context.go('/profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.neonBlue : AppColors.textMuted;

    return InkResponse(
      onTap: onTap,
      radius: 42,
      highlightColor: AppColors.neonBlue.withValues(alpha: 0.06),
      splashColor: AppColors.neonBlue.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 16 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: AppColors.neonBlue,
              borderRadius: BorderRadius.circular(3),
              boxShadow: selected ? [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.7), blurRadius: 8)] : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.neonBlue, AppColors.neonBlueDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.42),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black, size: 26),
        ),
      ),
    );
  }
}
