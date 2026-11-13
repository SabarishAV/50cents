import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/auth/presentation/providers/auth_provider.dart';

/// Modal that lets the signed-in user change their password, or set one for the
/// first time when they signed up with Google.
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  /// Shows the dialog and resolves when it is dismissed.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(context: context, builder: (_) => const ChangePasswordDialog());
  }

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _submitting = false;

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
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _clearServerError() {
    final auth = ref.read(authProvider);
    if (auth.error != null || auth.fieldErrors.isNotEmpty) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();
    _clearServerError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);

    final success = await ref
        .read(authProvider.notifier)
        .changePassword(
          currentPassword: _currentController.text.isEmpty ? null : _currentController.text,
          newPassword: _newController.text,
        );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (!success) return;

    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Password changed successfully'), backgroundColor: AppColors.income));
  }

  Widget _visibilityToggle({required bool show, required VoidCallback onPressed}) {
    return IconButton(
      tooltip: show ? 'Hide password' : 'Show password',
      onPressed: onPressed,
      icon: Icon(
        show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
    );
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
      canPop: !_submitting,
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
                BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.08), blurRadius: 32, spreadRadius: 2),
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
                    _Header(enabled: !_submitting, onClose: () => Navigator.of(context).pop()),
                    const SizedBox(height: 14),
                    const Text(
                      'Enter your current password and choose a new one. If you signed up with Google, '
                      'leave the current password empty to set one for the first time.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
                    ),
                    if (bannerMessage != null) ...[const SizedBox(height: 14), _ErrorBanner(message: bannerMessage)],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentController,
                      obscureText: !_showCurrent,
                      enabled: !_submitting,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.next,
                      maxLength: 128,
                      onChanged: (_) => _clearServerError(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration:
                          appInputDecoration(
                            'Current password',
                            Icons.lock_outline_rounded,
                            suffixIcon: _visibilityToggle(
                              show: _showCurrent,
                              onPressed: () => setState(() => _showCurrent = !_showCurrent),
                            ),
                          ).copyWith(
                            counterText: '',
                            helperText: 'Leave empty only if your account has no password yet',
                            helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.2),
                            errorText: fieldErrors['currentPassword'],
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newController,
                      obscureText: !_showNew,
                      enabled: !_submitting,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      maxLength: 72,
                      onChanged: (_) => _clearServerError(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration:
                          appInputDecoration(
                            'New password',
                            Icons.password_rounded,
                            suffixIcon: _visibilityToggle(
                              show: _showNew,
                              onPressed: () => setState(() => _showNew = !_showNew),
                            ),
                          ).copyWith(
                            counterText: '',
                            helperText: '8–72 characters',
                            helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.2),
                            errorText: fieldErrors['newPassword'],
                          ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) return 'Enter a new password';
                        if (password.length < 8) return 'Use at least 8 characters';
                        if (password.length > 72) return 'Use at most 72 characters';
                        if (password == _currentController.text) {
                          return 'Choose a password different from your current one';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: !_showConfirm,
                      enabled: !_submitting,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _clearServerError(),
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: appInputDecoration(
                        'Confirm new password',
                        Icons.lock_reset_rounded,
                        suffixIcon: _visibilityToggle(
                          show: _showConfirm,
                          onPressed: () => setState(() => _showConfirm = !_showConfirm),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Confirm your new password';
                        if (value != _newController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
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
                          child: NeonButton(
                            label: 'Update password',
                            onPressed: _submit,
                            loading: _submitting,
                            height: 48,
                          ),
                        ),
                      ],
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.enabled, required this.onClose});

  final bool enabled;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.neonBlue.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.lock_reset_rounded, color: AppColors.neonBlue, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change password',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text('Keep your account secure', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
