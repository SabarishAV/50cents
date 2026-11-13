import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/features/auth/presentation/providers/auth_provider.dart';

enum _Step { confirm, otp }

/// Two-step modal that permanently deletes the signed-in user's account:
/// request an OTP (optionally confirming the password), then verify it.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  /// Shows the dialog and resolves when it is dismissed.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(context: context, builder: (_) => const DeleteAccountDialog());
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  _Step _step = _Step.confirm;
  String? _pendingPassword;
  bool _showPassword = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Never show an error left over from an earlier auth attempt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _clearServerError() {
    final auth = ref.read(authProvider);
    if (auth.error != null || auth.fieldErrors.isNotEmpty) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  Future<void> _requestCode() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    _clearServerError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final password = _passwordController.text;
    setState(() => _busy = true);

    final success = await ref.read(authProvider.notifier).requestAccountDeletion(password: password);
    if (!mounted) return;

    setState(() => _busy = false);
    if (!success) return;

    setState(() {
      _pendingPassword = password;
      _step = _Step.otp;
      _otpController.clear();
    });
  }

  Future<void> _verifyCode() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    _clearServerError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await ref.read(authProvider.notifier).verifyAccountDeletion(_otpController.text.trim());
    if (!mounted) return;

    setState(() => _busy = false);
    if (!success) return;

    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Your account has been deleted'), backgroundColor: AppColors.income));
    router.go('/login');
  }

  Future<void> _resendCode() async {
    if (_busy) return;

    _clearServerError();
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    final success = await ref.read(authProvider.notifier).requestAccountDeletion(password: _pendingPassword);
    if (!mounted) return;

    setState(() => _busy = false);
    if (!success) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('A new code was sent to your registered email'),
          backgroundColor: AppColors.income,
        ),
      );
  }

  void _backToConfirm() {
    if (_busy) return;
    _clearServerError();
    setState(() {
      _step = _Step.confirm;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final fieldErrors = auth.fieldErrors;

    // "Validation failed" alone says nothing useful — point at the fields when
    // the API gives us per-field messages.
    final bannerMessage = auth.error == null
        ? null
        : (auth.error == 'Validation failed' && fieldErrors.isNotEmpty
              ? 'Please check the highlighted fields.'
              : auth.error);

    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewInsets.bottom - 48).clamp(280.0, media.size.height).toDouble();

    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: AppColors.expense.withValues(alpha: 0.10), blurRadius: 32, spreadRadius: 2),
                BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      title: _step == _Step.confirm ? 'Delete account' : 'Confirm deletion',
                      subtitle: _step == _Step.confirm ? 'This cannot be undone' : 'One last step',
                      icon: _step == _Step.confirm ? Icons.delete_forever_rounded : Icons.mark_email_read_outlined,
                      enabled: !_busy,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 14),
                    if (_step == _Step.confirm)
                      _buildConfirmStep(fieldErrors: fieldErrors, banner: bannerMessage)
                    else
                      _buildOtpStep(fieldErrors: fieldErrors, banner: bannerMessage),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmStep({required Map<String, String> fieldErrors, required String? banner}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.expense.withValues(alpha: 0.35)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your account and all of its data will be permanently removed. '
                  'This action cannot be reversed.',
                  style: TextStyle(color: AppColors.expense, fontSize: 12.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        if (banner != null) ...[const SizedBox(height: 14), _ErrorBanner(message: banner)],
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          enabled: !_busy,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          maxLength: 128,
          onChanged: (_) => _clearServerError(),
          onFieldSubmitted: (_) => _requestCode(),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration:
              appInputDecoration(
                'Password',
                Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ).copyWith(
                counterText: '',
                helperText: 'Optional for accounts created with Google',
                helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.2),
                errorText: fieldErrors['password'],
              ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DangerButton(label: 'Send code', onPressed: _requestCode, loading: _busy),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpStep({required Map<String, String> fieldErrors, required String? banner}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the 6-digit code we sent to your registered email to permanently delete your account.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
        ),
        if (banner != null) ...<Widget>[const SizedBox(height: 14), _ErrorBanner(message: banner)],
        const SizedBox(height: 16),
        TextFormField(
          controller: _otpController,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _clearServerError(),
          onFieldSubmitted: (_) => _verifyCode(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          decoration: appInputDecoration(
            'Verification code',
            Icons.password_rounded,
            hint: '123456',
          ).copyWith(counterText: '', errorText: fieldErrors['otp']),
          validator: (value) {
            final otp = value?.trim() ?? '';
            if (otp.isEmpty) return 'Please enter the code';
            if (!RegExp(r'^\d{6}$').hasMatch(otp)) return 'Enter the 6-digit code';
            return null;
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Didn\'t get the code?', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            TextButton(
              onPressed: _busy ? null : _resendCode,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.neonBlue,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Resend'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _backToConfirm,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DangerButton(label: 'Delete account', onPressed: _verifyCode, loading: _busy),
            ),
          ],
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.expense, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: enabled ? onClose : null,
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
        ),
      ],
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed, required this.loading});

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.expense,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.expense.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.expense, fontSize: 12.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
