import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_button.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';

enum _Step { identifier, reset }

/// Password reset screen — request an OTP for a username/email, then verify it
/// and set a new password via POST /auth/forgot-password/request and
/// POST /auth/forgot-password/verify.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _focusNodes = <FocusNode>[];

  _Step _step = _Step.identifier;
  String _pendingIdentifier = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      _focusNodes.add(FocusNode());
    }
    // Clear a stale error when entering this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearServerError() {
    final auth = ref.read(authProvider);
    if (auth.error != null || auth.fieldErrors.isNotEmpty) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    _clearServerError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final identifier = _identifierController.text.trim();
    final success = await ref.read(authProvider.notifier).requestPasswordReset(identifier);
    if (!mounted || !success) return;

    setState(() {
      _pendingIdentifier = identifier;
      _step = _Step.reset;
      _otpController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('We sent a 6-digit code to the email for $identifier'),
          backgroundColor: AppColors.income,
        ),
      );
  }

  Future<void> _resendCode() async {
    if (_pendingIdentifier.isEmpty) return;

    _clearServerError();
    final success = await ref.read(authProvider.notifier).requestPasswordReset(_pendingIdentifier);
    if (!mounted || !success) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('A new code was sent to the email for $_pendingIdentifier'),
          backgroundColor: AppColors.income,
        ),
      );
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    _clearServerError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(authProvider.notifier)
        .verifyPasswordReset(
          identifier: _pendingIdentifier,
          otp: _otpController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted || !success) return;

    // The API returns no token: sign in again with the new password.
    context.go('/login?identifier=${Uri.encodeQueryComponent(_pendingIdentifier)}');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Password updated. Please log in.'),
          backgroundColor: AppColors.income,
          duration: Duration(seconds: 3),
        ),
      );
  }

  void _backToIdentifier() {
    _clearServerError();
    setState(() {
      _step = _Step.identifier;
      _otpController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isRequesting = authState.isRequestingPasswordReset;
    final isResetting = authState.isResettingPassword;
    final isBusy = isRequesting || isResetting;
    final fieldErrors = authState.fieldErrors;

    // "Validation failed" alone says nothing useful — point at the fields when
    // the API gives us per-field messages.
    final bannerMessage = authState.error == null
        ? null
        : (authState.error == 'Validation failed' && fieldErrors.isNotEmpty
              ? 'Please check the highlighted fields.'
              : authState.error);

    return AuthShell(
      title: _step == _Step.identifier ? 'Forgot password?' : 'Set a new password',
      subtitle: _step == _Step.identifier
          ? 'We will email you a code to reset it.'
          : 'Enter the code and choose a new password.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Remember your password?', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          TextButton(
            onPressed: isBusy
                ? null
                : () {
                    ref.read(authProvider.notifier).clearError();
                    context.go('/login');
                  },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neonBlue,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('Log in'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == _Step.identifier)
              ..._buildIdentifierStep(
                isBusy: isBusy,
                isRequesting: isRequesting,
                fieldErrors: fieldErrors,
                banner: bannerMessage,
              )
            else
              ..._buildResetStep(
                isBusy: isBusy,
                isResetting: isResetting,
                fieldErrors: fieldErrors,
                banner: bannerMessage,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildIdentifierStep({
    required bool isBusy,
    required bool isRequesting,
    required Map<String, String> fieldErrors,
    required String? banner,
  }) {
    return [
      TextFormField(
        focusNode: _focusNodes[0],
        controller: _identifierController,
        enabled: !isBusy,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: appInputDecoration(
          'Username or email',
          Icons.person_outline_rounded,
          hint: 'you@example.com',
        ).copyWith(errorText: fieldErrors['identifier']),
        onChanged: (_) => _clearServerError(),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your username or email';
          }
          return null;
        },
        onFieldSubmitted: (_) => _requestCode(),
      ),
      if (banner != null) ...[const SizedBox(height: 18), AuthErrorBanner(message: banner)],
      const SizedBox(height: 24),
      NeonButton(label: 'Send reset code', loading: isRequesting, onPressed: isBusy ? null : _requestCode),
    ];
  }

  List<Widget> _buildResetStep({
    required bool isBusy,
    required bool isResetting,
    required Map<String, String> fieldErrors,
    required String? banner,
  }) {
    return [
      Text(
        'Enter the 6-digit code sent to the email for $_pendingIdentifier, then choose a new password.',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45),
      ),
      if (banner != null) ...[const SizedBox(height: 14), AuthErrorBanner(message: banner)],
      const SizedBox(height: 16),
      TextFormField(
        focusNode: _focusNodes[1],
        controller: _otpController,
        enabled: !isBusy,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 6,
        textAlign: TextAlign.center,
        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
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
        onChanged: (_) => _clearServerError(),
        validator: (value) {
          final otp = value?.trim() ?? '';
          if (otp.isEmpty) return 'Please enter the code';
          if (!RegExp(r'^\d{6}$').hasMatch(otp)) return 'Enter the 6-digit code';
          return null;
        },
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[2]),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Didn't get the code?", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          TextButton(
            onPressed: isBusy ? null : _resendCode,
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
      TextFormField(
        focusNode: _focusNodes[2],
        controller: _passwordController,
        enabled: !isBusy,
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        maxLength: 72,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: appInputDecoration(
          'New password',
          Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ).copyWith(counterText: '', errorText: fieldErrors['password']),
        onChanged: (_) => _clearServerError(),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter a new password';
          if (value.length < 8) return 'Password must be at least 8 characters';
          if (value.length > 72) return 'Password must be at most 72 characters';
          return null;
        },
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[3]),
      ),
      const SizedBox(height: 16),
      TextFormField(
        focusNode: _focusNodes[3],
        controller: _confirmPasswordController,
        enabled: !isBusy,
        obscureText: _obscureConfirmPassword,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: appInputDecoration(
          'Confirm new password',
          Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ),
        onChanged: (_) => _clearServerError(),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please confirm your new password';
          if (value != _passwordController.text) return 'Passwords do not match';
          return null;
        },
        onFieldSubmitted: (_) => _resetPassword(),
      ),
      const SizedBox(height: 24),
      NeonButton(label: 'Reset password', loading: isResetting, onPressed: isBusy ? null : _resetPassword),
      const SizedBox(height: 8),
      TextButton(
        onPressed: isBusy ? null : _backToIdentifier,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: const Text('Use a different account'),
      ),
    ];
  }
}
