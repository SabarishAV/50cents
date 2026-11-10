import 'dart:convert';

import 'package:_50cents/features/auth/data/models/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth session (token + decoded claims) in secure storage.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'auth_session';
  static const _legacyTokenKey = 'access_token';

  /// Reads the stored session. Falls back to the old token-only entry so
  /// existing installs stay logged in after this update.
  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final session = AuthSession.fromJson(decoded);
          if (session.token.isNotEmpty) return session;
        }
      } catch (_) {
        // Corrupted entry — fall through and try the legacy key.
      }
    }

    final legacyToken = await _storage.read(key: _legacyTokenKey);
    if (legacyToken == null || legacyToken.isEmpty) return null;
    return AuthSession.fromToken(legacyToken);
  }

  /// Saves the full session. The token is also written to the legacy key so
  /// the Dio interceptor keeps working even if it asks for just the token.
  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    await _storage.write(key: _legacyTokenKey, value: session.token);
  }

  Future<String?> read() async => (await readSession())?.token;

  Future<void> save(String token) => saveSession(AuthSession.fromToken(token));

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _legacyTokenKey);
  }
}

// Riverpod provider: how other files get a TokenStorage instance.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage(const FlutterSecureStorage()));
