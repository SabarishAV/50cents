import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:_50cents/core/theme/app_theme.dart';
import 'package:_50cents/features/auth/presentation/pages/register_page.dart';
import 'package:_50cents/features/auth/presentation/pages/login_page.dart';
import 'package:_50cents/features/auth/presentation/pages/home_page.dart';
import 'package:_50cents/features/auth/presentation/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = auth.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!isAuthenticated && state.matchedLocation == '/home') {
        return '/login';
      }
      if (isAuthenticated && (isLoggingIn || isRegistering)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', name: 'register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/home', name: 'home', builder: (context, state) => const HomePage()),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read router once — do NOT watch, to avoid full app rebuilds on auth changes
    final router = ref.read(routerProvider);
    return MaterialApp.router(
      title: '50cents',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
