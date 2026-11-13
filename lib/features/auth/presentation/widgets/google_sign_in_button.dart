import 'package:material_ui/material_ui.dart';
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

      final success = await ref.read(authProvider.notifier).googleLogin(idToken);
      if (!context.mounted) return;

      if (success) {
        onSignedIn?.call();
        return;
      }

      final error = ref.read(authProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.expense));
      }
    } on GoogleSignInException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.description?.isNotEmpty == true ? e.description! : 'Google sign-in failed'),
          backgroundColor: AppColors.expense,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.expense),
      );
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
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Image.asset(
                  'assets/google_logo.png',
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.g_mobiledata, size: 20, color: Colors.black),
                ),
              ),
        label: isLoading ? const Text('Signing in...') : const Text('Continue with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.background.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
