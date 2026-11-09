import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:_50cents/core/network/api_exception.dart';
import 'package:_50cents/core/storage/token_storage.dart';

import '../../data/auth_repository.dart';
import '../../data/models/register_request.dart';

class AuthState {
  final bool isRegistering;
  final bool isLoggingIn;
  final bool isGoogleSigningIn;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.isRegistering = false,
    this.isLoggingIn = false,
    this.isGoogleSigningIn = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isRegistering,
    bool? isLoggingIn,
    bool? isGoogleSigningIn,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isRegistering: isRegistering ?? this.isRegistering,
      isLoggingIn: isLoggingIn ?? this.isLoggingIn,
      isGoogleSigningIn: isGoogleSigningIn ?? this.isGoogleSigningIn,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStorage get _tokenStorage => ref.read(tokenStorageProvider);

  @override
  AuthState build() => const AuthState();

  /// Register a new account via POST /auth/register.
  /// Response: { success: true, message: "string" }
  Future<void> register(RegisterRequest request) async {
    state = state.copyWith(isRegistering: true, isLoggingIn: false, isGoogleSigningIn: false, error: null);
    try {
      final response = await _repository.register(request);
      if (response.success) {
        state = state.copyWith(isRegistering: false, error: null);
      } else {
        state = state.copyWith(isRegistering: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isRegistering: false, error: _formatError(e));
    }
  }

  /// Sign up / log in with Google via POST /auth/google.
  /// Response: { success: true, token: "string" }
  Future<void> googleLogin(String idToken) async {
    state = state.copyWith(isGoogleSigningIn: true, isRegistering: false, isLoggingIn: false, error: null);
    try {
      final response = await _repository.googleLogin(idToken);
      if (response.success && response.token != null) {
        await _tokenStorage.save(response.token!);
        state = const AuthState(
          isGoogleSigningIn: false,
          isRegistering: false,
          isLoggingIn: false,
          error: null,
          isAuthenticated: true,
        );
      } else {
        state = state.copyWith(isGoogleSigningIn: false, error: response.message ?? 'Google sign-in failed');
      }
    } catch (e) {
      state = state.copyWith(isGoogleSigningIn: false, error: _formatError(e));
    }
  }

  /// Login via POST /auth/login.
  /// Response: { success: true, token: "string" }
  Future<void> login(String identifier, String password) async {
    state = state.copyWith(isLoggingIn: true, isRegistering: false, isGoogleSigningIn: false, error: null);
    try {
      final response = await _repository.login(identifier, password);
      if (response.success && response.token != null) {
        await _tokenStorage.save(response.token!);
        state = const AuthState(
          isGoogleSigningIn: false,
          isRegistering: false,
          isLoggingIn: false,
          error: null,
          isAuthenticated: true,
        );
      } else {
        state = state.copyWith(isLoggingIn: false, error: response.message ?? 'Login failed');
      }
    } catch (e) {
      state = state.copyWith(isLoggingIn: false, error: _formatError(e));
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    state = const AuthState(
      isGoogleSigningIn: false,
      isRegistering: false,
      isLoggingIn: false,
      error: null,
      isAuthenticated: false,
    );
  }

  String _formatError(dynamic e) {
    // ApiException already has a clean message
    if (e is ApiException) {
      return e.message;
    }
    // DioException: extract the error message from the response
    if (e is DioException) {
      final apiErr = ApiException.from(e);
      return apiErr.message;
    }
    final message = e.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }
}
