import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:_50cents/core/config/env.dart';
import 'package:_50cents/core/theme/app_colors.dart';

import '../providers/auth_provider.dart';

/// Google sign-in button. Signs in with Google using the server client ID from
/// .env, sends the ID token to POST /auth/google, and saves the returned JWT so
/// the Dio interceptor attaches it as a Bearer token to other API calls.
///
/// On Android, `initialize(serverClientId:)` is required to mint an ID token
/// for your backend audience. Your Google Cloud Console project must have an
/// Android OAuth client (client_type: 1) with your app's SHA-1 fingerprint.
class GoogleSignInButton extends ConsumerWidget {
  final VoidCallback? onSignedIn;
  const GoogleSignInButton({super.key, this.onSignedIn});

  static bool _isInitialized = false;

  Future<void> _handleSignIn(WidgetRef ref, BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      // Initialize once with the server client ID so Google mints an ID token
      // for your backend audience.
      if (!_isInitialized) {
        await googleSignIn.initialize(serverClientId: Env.googleServerClientId);
        _isInitialized = true;
      }

      final account = await googleSignIn.authenticate(scopeHint: const <String>['email', 'profile']);

      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null) {
        throw Exception('No ID token returned from Google');
      }

      await ref.read(authProvider.notifier).googleLogin(idToken);

      final state = ref.read(authProvider);
      if (state.isAuthenticated) {
        onSignedIn?.call();
      } else if (state.error != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: AppColors.expense));
        }
      }
    } on GoogleSignInException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.description?.isNotEmpty == true ? e.description! : 'Google sign-in failed'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider).isGoogleSigningIn;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : () => _handleSignIn(ref, context),
        icon: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Image.asset(
                'assets/google_logo.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.g_mobiledata, size: 20, color: AppColors.textMuted),
              ),
        label: isLoading ? const Text('Signing in with Google...') : const Text('Sign in with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
