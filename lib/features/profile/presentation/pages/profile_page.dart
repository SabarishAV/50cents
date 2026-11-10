import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/app_logo.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/features/auth/data/models/auth_session.dart';
import 'package:_50cents/features/auth/presentation/providers/auth_provider.dart';
import 'package:_50cents/features/auth/presentation/widgets/user_avatar.dart';
import 'package:_50cents/features/home/presentation/widgets/app_bottom_nav.dart';

/// Profile screen — account details, decoded token claims and logout.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Log out?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'You will need to sign in again to access your account.',
          style: TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).session;

    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: session == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2))
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      children: [
                        Row(
                          children: [
                            const AppLogo(size: 38, radius: 11),
                            const SizedBox(width: 10),
                            const Text(
                              'Profile',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Log out',
                              onPressed: () => _logout(context, ref),
                              icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _ProfileHeader(session: session),
                        const SizedBox(height: 22),
                        _SessionStatusCard(session: session),
                        const SizedBox(height: 16),
                        _AccountCard(session: session),
                        const SizedBox(height: 16),
                        if (session.claims.isNotEmpty) ...[_ClaimsCard(session: session), const SizedBox(height: 16)],
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () => _logout(context, ref),
                            icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.expense),
                            label: const Text('Log out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.expense,
                              side: BorderSide(color: AppColors.expense.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: const AppBottomNav(current: AppTab.profile),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neonBlue.withValues(alpha: 0.16), AppColors.surface, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.07), blurRadius: 30, spreadRadius: 1)],
      ),
      child: Row(
        children: [
          UserAvatar(session: session, size: 68),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                if (session.email != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    session.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.income.withValues(alpha: 0.28)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.income, size: 12),
                      SizedBox(width: 5),
                      Text(
                        'Signed in',
                        style: TextStyle(color: AppColors.income, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final expiry = session.expiresAt?.toLocal();
    final subtitle = expiry == null
        ? 'Your token is stored securely on this device.'
        : 'Token valid until ${_formatDate(expiry)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.income.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.verified_user_outlined, color: AppColors.income, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Authenticated session active',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Account',
      icon: Icons.person_outline_rounded,
      children: [
        _InfoRow(label: 'Name', value: session.name ?? session.displayName),
        if (session.email != null) _InfoRow(label: 'Email', value: session.email!),
        if (session.userId != null) _InfoRow(label: 'User ID', value: session.userId!, monospace: true),
      ],
    );
  }
}

class _ClaimsCard extends StatelessWidget {
  const _ClaimsCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(session.claims);

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.neonBlue,
          collapsedIconColor: AppColors.textMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: const Icon(Icons.data_object_rounded, color: AppColors.textMuted, size: 20),
          title: const Text(
            'Decoded token claims',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Stored locally and ready for later use',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  pretty,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.monospace = false});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: monospace ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final month = months[date.month - 1];
  final minute = date.minute.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  return '$month ${date.day}, ${date.year} at $hour:$minute';
}
