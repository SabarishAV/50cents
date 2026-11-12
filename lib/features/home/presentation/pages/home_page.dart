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
import 'package:_50cents/features/payments/presentation/widgets/contact_picker_sheet.dart';
import 'package:_50cents/features/payments/presentation/widgets/pay_sheet.dart';

/// UPI-style home screen. 50cents does not process payments — each option opens
/// the user's installed UPI app with a ready-to-pay intent.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

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
                        _TopBar(session: session),
                        const SizedBox(height: 26),
                        _Greeting(session: session),
                        const SizedBox(height: 22),
                        _SearchPill(
                          onTap: () async {
                            final phone = await showContactPicker(context);
                            if (phone == null || !context.mounted) return;
                            await showPaySheet(context, target: PayTarget.phone, phone: phone);
                          },
                        ),
                        const SizedBox(height: 18),
                        _ScanHeroCard(onTap: () => context.push('/scan')),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.phone_android_rounded,
                                title: 'To phone number',
                                subtitle: 'Send using mobile',
                                onTap: () => showPaySheet(context, target: PayTarget.phone),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.alternate_email_rounded,
                                title: 'To UPI ID',
                                subtitle: 'Pay any VPA',
                                onTap: () => showPaySheet(context, target: PayTarget.upi),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _HistoryTile(onTap: () => context.push('/payment-records')),
                        const SizedBox(height: 14),
                        const _RedirectNote(),
                        const SizedBox(height: 18),
                        const _HowItWorks(),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: const AppBottomNav(current: AppTab.home),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogo(size: 38, radius: 11),
        const SizedBox(width: 10),
        const Text(
          '50cents',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0.6),
        ),
        const Spacer(),
        UserAvatar(session: session, size: 40, onTap: () => context.go('/profile')),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.session});

  final AuthSession session;

  String get _firstName {
    final name = session.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name.split(RegExp(r'\s+')).first;
    }
    final email = session.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $_firstName',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        const Text('What would you like to pay today?', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ],
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textMuted, size: 21),
              SizedBox(width: 12),
              Expanded(
                child: Text('Pay by name or phone number', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanHeroCard extends StatelessWidget {
  const _ScanHeroCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neonBlue, AppColors.neonBlueDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withValues(alpha: 0.35),
            blurRadius: 26,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  bottom: -28,
                  child: Icon(Icons.qr_code_2_rounded, size: 150, color: Colors.black.withValues(alpha: 0.12)),
                ),
                Positioned(
                  right: 38,
                  top: -44,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.09)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'SCAN & PAY',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Scan any UPI QR',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Point, review the payee and finish in your UPI app.',
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.68), fontSize: 13, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(13)),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.neonBlue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Open scanner',
                            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
                ),
                child: Icon(icon, color: AppColors.neonBlue, size: 21),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
                ),
                child: Icon(Icons.receipt_long_rounded, color: AppColors.neonBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment history',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Your past payments and bank updates',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RedirectNote extends StatelessWidget {
  const _RedirectNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            child: const Icon(Icons.verified_user_outlined, color: AppColors.income, size: 17),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safe UPI redirect',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  '50cents only opens your installed UPI app. Your money and bank details never pass through us.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Step(number: '01', icon: Icons.qr_code_scanner_rounded, label: 'Scan or choose'),
              ),
              _StepConnector(),
              Expanded(
                child: _Step(number: '02', icon: Icons.currency_rupee_rounded, label: 'Enter amount'),
              ),
              _StepConnector(),
              Expanded(
                child: _Step(number: '03', icon: Icons.open_in_new_rounded, label: 'Pay in UPI app'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.icon, required this.label});

  final String number;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: AppColors.neonBlue, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          number,
          style: TextStyle(
            color: AppColors.neonBlue.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.3),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 18, height: 1, margin: const EdgeInsets.only(bottom: 30), color: AppColors.border);
  }
}
