import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:_50cents/core/network/api_exception.dart';
import 'package:_50cents/core/storage/token_storage.dart';

import '../../data/auth_repository.dart';
import '../../data/models/auth_session.dart';
import '../../data/models/register_request.dart';

const _unset = Object();

class AuthState {
  /// `false` until the persisted session has been read from secure storage.
  /// The router shows a splash screen while this is `false`.
  final bool isInitialized;
  final bool isRegistering;
  final bool isLoggingIn;
  final bool isGoogleSigningIn;
  final String? error;

  /// Token + decoded claims for the signed-in user.
  final AuthSession? session;

  const AuthState({
    this.isInitialized = false,
    this.isRegistering = false,
    this.isLoggingIn = false,
    this.isGoogleSigningIn = false,
    this.error,
    this.session,
  });

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    bool? isInitialized,
    bool? isRegistering,
    bool? isLoggingIn,
    bool? isGoogleSigningIn,
    Object? error = _unset,
    Object? session = _unset,
  }) {
    return AuthState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRegistering: isRegistering ?? this.isRegistering,
      isLoggingIn: isLoggingIn ?? this.isLoggingIn,
      isGoogleSigningIn: isGoogleSigningIn ?? this.isGoogleSigningIn,
      error: identical(error, _unset) ? this.error : error as String?,
      session: identical(session, _unset) ? this.session : session as AuthSession?,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStorage get _tokenStorage => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    // Kick off session restoration; the state flips to initialized once done.
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _tokenStorage.readSession();
      if (session == null) {
        state = const AuthState(isInitialized: true);
        return;
      }

      if (session.isExpired) {
        await _tokenStorage.clear();
        state = const AuthState(isInitialized: true);
        return;
      }

      state = AuthState(isInitialized: true, session: session);
    } catch (_) {
      // Secure storage unavailable/corrupted — treat the user as signed out.
      state = const AuthState(isInitialized: true);
    }
  }

  /// Register a new account via POST /auth/register.
  /// Response: { success: true, message: "string" }
  /// Returns `true` when the account was created.
  Future<bool> register(RegisterRequest request) async {
    state = state.copyWith(isRegistering: true, isLoggingIn: false, isGoogleSigningIn: false, error: null);
    try {
      final response = await _repository.register(request);
      state = state.copyWith(
        isRegistering: false,
        error: response.success ? null : (response.message.isEmpty ? 'Registration failed' : response.message),
      );
      return response.success;
    } catch (e) {
      state = state.copyWith(isRegistering: false, error: _formatError(e));
      return false;
    }
  }

  /// Sign up / log in with Google via POST /auth/google.
  /// Response: { success: true, token: "string" }
  /// Returns `true` when the session was stored.
  Future<bool> googleLogin(String idToken) async {
    state = state.copyWith(isGoogleSigningIn: true, isRegistering: false, isLoggingIn: false, error: null);
    try {
      final response = await _repository.googleLogin(idToken);
      return await _completeLogin(
        success: response.success,
        token: response.token,
        fallbackMessage: response.message ?? 'Google sign-in failed',
      );
    } catch (e) {
      state = state.copyWith(isGoogleSigningIn: false, error: _formatError(e));
      return false;
    }
  }

  /// Login via POST /auth/login.
  /// Response: { success: true, token: "string" }
  /// Returns `true` when the session was stored.
  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoggingIn: true, isRegistering: false, isGoogleSigningIn: false, error: null);
    try {
      final response = await _repository.login(identifier, password);
      return await _completeLogin(
        success: response.success,
        token: response.token,
        fallbackMessage: response.message ?? 'Login failed',
      );
    } catch (e) {
      state = state.copyWith(isLoggingIn: false, error: _formatError(e));
      return false;
    }
  }

  /// Persists the token + decoded claims and marks the user as signed in.
  Future<bool> _completeLogin({required bool success, required String? token, required String fallbackMessage}) async {
    if (!success || token == null || token.isEmpty) {
      state = state.copyWith(
        isLoggingIn: false,
        isGoogleSigningIn: false,
        isRegistering: false,
        error: fallbackMessage,
      );
      return false;
    }

    final session = AuthSession.fromToken(token);
    try {
      await _tokenStorage.saveSession(session);
    } catch (_) {
      state = state.copyWith(
        isLoggingIn: false,
        isGoogleSigningIn: false,
        isRegistering: false,
        error: 'Could not store your session securely. Please try again.',
      );
      return false;
    }

    state = AuthState(isInitialized: true, session: session);
    return true;
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  Future<void> logout() async {
    try {
      await _tokenStorage.clear();
    } finally {
      state = const AuthState(isInitialized: true);
    }
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
