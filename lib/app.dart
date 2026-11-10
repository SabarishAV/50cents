import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_theme.dart';
import 'package:_50cents/features/auth/presentation/pages/login_page.dart';
import 'package:_50cents/features/auth/presentation/pages/register_page.dart';
import 'package:_50cents/features/auth/presentation/pages/splash_page.dart';
import 'package:_50cents/features/auth/presentation/providers/auth_provider.dart';
import 'package:_50cents/features/home/presentation/pages/home_page.dart';
import 'package:_50cents/features/payments/presentation/pages/scan_page.dart';
import 'package:_50cents/features/profile/presentation/pages/profile_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isAuthRoute = location == '/login' || location == '/register';

      // Still restoring the persisted session.
      if (!auth.isInitialized) {
        return isSplash ? null : '/splash';
      }

      // Session known — splash is no longer needed.
      if (isSplash) {
        return auth.isAuthenticated ? '/home' : '/login';
      }

      // Protected area: everything except login/register requires a session.
      if (!auth.isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      // Already signed in: keep the user out of the auth screens.
      if (isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', name: 'splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', name: 'register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/home', name: 'home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/profile', name: 'profile', builder: (context, state) => const ProfilePage()),
      GoRoute(path: '/scan', name: 'scan', builder: (context, state) => const ScanPage()),
    ],
  );
});

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final GoRouter _router = ref.read(routerProvider);

  @override
  Widget build(BuildContext context) {
    // Re-run the router's redirect guard whenever auth changes (login,
    // logout, restored session). The router instance itself stays stable.
    ref.listen<AuthState>(authProvider, (_, _) => _router.refresh());

    return MaterialApp.router(
      title: '50cents',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
