import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_button.dart';

import '../../data/models/register_request.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';
import '../widgets/google_sign_in_button.dart';

/// Register screen — creates a new account via POST /auth/register
/// and offers Google sign-up via POST /auth/google.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _usernameAutoGenerate = true;
  final _focusNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      _focusNodes.add(FocusNode());
    }
    _nameController.addListener(_onNameChanged);
    // Clear a stale error when entering this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  void _onNameChanged() {
    if (!_usernameAutoGenerate) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _usernameController.clear();
      return;
    }
    final generated = _generateUsername(name);
    if (_usernameController.text != generated) {
      _usernameController.text = generated;
    }
  }

  String _generateUsername(String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]+'), '');
    return slug.isEmpty ? '' : slug;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    for (final node in _focusNodes) {
      node.dispose();
    }
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final success = await ref
        .read(authProvider.notifier)
        .register(
          RegisterRequest(
            name: _nameController.text.trim(),
            username: _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Account created. Please log in.'),
            backgroundColor: AppColors.income,
            duration: Duration(seconds: 3),
          ),
        );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isBusy = authState.isRegistering || authState.isGoogleSigningIn;

    return AuthShell(
      title: 'Create your account',
      subtitle: 'Join 50cents and start tracking your finances.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Already have an account?', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          TextButton(
            onPressed: () {
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
            TextFormField(
              focusNode: _focusNodes[0],
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: appInputDecoration('Full name', Icons.person_outline_rounded, hint: 'Jane Doe'),
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[1]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              focusNode: _focusNodes[1],
              controller: _usernameController,
              enabled: !_usernameAutoGenerate,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              style: TextStyle(color: _usernameAutoGenerate ? AppColors.textMuted : AppColors.textPrimary),
              decoration: appInputDecoration('Username', Icons.alternate_email_rounded, hint: 'jane.doe').copyWith(
                helperText: _usernameAutoGenerate
                    ? 'Generated from your name'
                    : 'Letters, numbers, dots and underscores',
                helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              onChanged: (value) {
                ref.read(authProvider.notifier).clearError();
                if (_usernameAutoGenerate && value.trim() != _generateUsername(_nameController.text.trim())) {
                  setState(() => _usernameAutoGenerate = false);
                }
              },
              validator: (value) {
                final username = value?.trim() ?? '';
                if (username.isEmpty) {
                  return 'Please enter a username';
                }
                if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
                  return 'Only letters, numbers, dots and underscores';
                }
                if (username.length < 3) {
                  return 'At least 3 characters';
                }
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[2]),
            ),
            const SizedBox(height: 4),
            _AutoUsernameToggle(
              value: _usernameAutoGenerate,
              onChanged: (value) {
                setState(() => _usernameAutoGenerate = value);
                if (value) _onNameChanged();
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              focusNode: _focusNodes[2],
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: appInputDecoration('Email', Icons.email_outlined, hint: 'you@example.com'),
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Please enter your email';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[3]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              focusNode: _focusNodes[3],
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: appInputDecoration(
                'Password',
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
              ),
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a password';
                if (value.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[4]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              focusNode: _focusNodes[4],
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: appInputDecoration(
                'Confirm password',
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
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please confirm your password';
                if (value != _passwordController.text) return 'Passwords do not match';
                return null;
              },
              onFieldSubmitted: (_) => _handleRegister(),
            ),
            if (authState.error != null) ...[const SizedBox(height: 18), AuthErrorBanner(message: authState.error!)],
            const SizedBox(height: 24),
            NeonButton(
              label: 'Create account',
              loading: authState.isRegistering,
              onPressed: isBusy ? null : _handleRegister,
            ),
            const SizedBox(height: 24),
            const AuthDivider(),
            const SizedBox(height: 20),
            GoogleSignInButton(onSignedIn: () => context.go('/home')),
          ],
        ),
      ),
    );
  }
}

/// Small inline switch that controls the username auto-generation behaviour.
class _AutoUsernameToggle extends StatelessWidget {
  const _AutoUsernameToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(Icons.auto_awesome_outlined, size: 14, color: value ? AppColors.neonBlue : AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Auto-generate username',
            style: TextStyle(
              color: value ? AppColors.neonBlue : AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 28,
          child: Transform.scale(
            scale: 0.75,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.neonBlue,
              inactiveThumbColor: AppColors.textMuted,
              inactiveTrackColor: AppColors.border,
            ),
          ),
        ),
      ],
    );
  }
}
