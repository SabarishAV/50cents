import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_button.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';
import '../widgets/google_sign_in_button.dart';

/// Login screen — username/email + password plus Google sign-in.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _focusNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _focusNodes.add(FocusNode());
    _focusNodes.add(FocusNode());
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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final success = await ref
        .read(authProvider.notifier)
        .login(_identifierController.text.trim(), _passwordController.text.trim());

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Welcome back!'),
            backgroundColor: AppColors.income,
            duration: Duration(seconds: 2),
          ),
        );
      // The router guard also redirects on auth changes; this keeps the
      // behaviour explicit and instant.
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isBusy = authState.isLoggingIn || authState.isGoogleSigningIn;

    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to keep tracking every cent.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Don't have an account?", style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).clearError();
              context.go('/register');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neonBlue,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('Create account'),
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
              controller: _identifierController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: appInputDecoration(
                'Username or email',
                Icons.person_outline_rounded,
                hint: 'you@example.com',
              ),
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your username or email';
                }
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[1]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              focusNode: _focusNodes[1],
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
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
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            if (authState.error != null) ...[const SizedBox(height: 18), AuthErrorBanner(message: authState.error!)],
            const SizedBox(height: 24),
            NeonButton(label: 'Log in', loading: authState.isLoggingIn, onPressed: isBusy ? null : _handleLogin),
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
