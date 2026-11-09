import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/neon_background.dart';

import '../providers/auth_provider.dart';
import '../widgets/google_sign_in_button.dart';
import '../../data/models/register_request.dart';

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
    // Clear auth error on any interaction
    _nameController.addListener(ref.read(authProvider.notifier).clearError);
    _usernameController.addListener(ref.read(authProvider.notifier).clearError);
    _emailController.addListener(ref.read(authProvider.notifier).clearError);
    _passwordController.addListener(ref.read(authProvider.notifier).clearError);
    _confirmPasswordController.addListener(ref.read(authProvider.notifier).clearError);
    // Clear error when entering this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  void _onNameChanged() {
    if (!_usernameAutoGenerate) return;
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final generated = _generateUsername(name);
      if (_usernameController.text != generated) {
        _usernameController.text = generated;
      }
    } else {
      _usernameController.clear();
    }
  }

  String _generateUsername(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]+'), '');
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
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    await ref
        .read(authProvider.notifier)
        .register(
          RegisterRequest(
            name: _nameController.text.trim(),
            username: _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );

    if (mounted) {
      final state = ref.read(authProvider);
      if (state.error == null && !state.isRegistering) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully. Please log in.'),
            backgroundColor: AppColors.income,
            duration: Duration(seconds: 2),
          ),
        );
        context.pushReplacement('/login');
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.expense),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.expense, width: 1.5),
      ),
      errorStyle: const TextStyle(height: 0.8, fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isRegistering = authState.isRegistering;
    final isGoogleLoading = authState.isGoogleSigningIn;

    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '50cents',
                  style: TextStyle(
                    color: AppColors.neonBlue,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your account',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join and start tracking your finances',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 36),

                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        focusNode: _focusNodes[0],
                        controller: _nameController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration('Full name', Icons.person_outline),
                        onTap: () => ref.read(authProvider.notifier).clearError(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[1]),
                      ),
                      const SizedBox(height: 16),

                      _buildUsernameField(_focusNodes[1]),
                      const SizedBox(height: 16),

                      TextFormField(
                        focusNode: _focusNodes[2],
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration('Email', Icons.email_outlined),
                        onTap: () => ref.read(authProvider.notifier).clearError(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[3]),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        focusNode: _focusNodes[3],
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration(
                          'Password',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        onTap: () => ref.read(authProvider.notifier).clearError(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[4]),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        focusNode: _focusNodes[4],
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration(
                          'Confirm password',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        onTap: () => ref.read(authProvider.notifier).clearError(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleRegister(),
                      ),
                      const SizedBox(height: 28),

                      if (authState.error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.expense.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppColors.expense, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(authState.error!, style: TextStyle(color: AppColors.expense, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (isRegistering || isGoogleLoading) ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonBlue,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: AppColors.neonBlue.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isRegistering
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text(
                                  'Create account',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Or continue with', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 24),

                GoogleSignInButton(onSignedIn: () {}),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(color: AppColors.textMuted)),
                    TextButton(
                      onPressed: () {
                        context.pushReplacement('/login');
                      },
                      style: TextButton.styleFrom(foregroundColor: AppColors.neonBlue),
                      child: const Text('Log in'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField(FocusNode focusNode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                focusNode: focusNode,
                controller: _usernameController,
                enabled: !_usernameAutoGenerate,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Username', Icons.alternate_email),
                onTap: () => ref.read(authProvider.notifier).clearError(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value.trim())) {
                    return 'Username can only contain letters, numbers, dots and underscores';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_focusNodes[2]),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    setState(() {
                      _usernameAutoGenerate = false;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _usernameAutoGenerate ? AppColors.neonBlue.withValues(alpha: 0.6) : AppColors.border,
                  width: 1.5,
                ),
                boxShadow: _usernameAutoGenerate
                    ? [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
              child: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _usernameAutoGenerate,
                  onChanged: (val) {
                    setState(() {
                      _usernameAutoGenerate = val;
                    });
                    if (_usernameAutoGenerate) {
                      _onNameChanged();
                    }
                  },
                  activeThumbColor: AppColors.neonBlue,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.border,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Auto',
              style: TextStyle(
                color: _usernameAutoGenerate ? AppColors.neonBlue : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (!_usernameAutoGenerate)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Manual entry — edit freely.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
