import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:_50cents/core/network/api_client.dart';

import 'models/auth_response.dart';
import 'models/google_login_request.dart';
import 'models/register_request.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AuthRepository(dio);
});

/// Data layer for auth API calls. Mirrors a Spring repository/DTO layer.
class AuthRepository {
  final Dio _dio;
  AuthRepository(this._dio);

  /// POST /auth/register — Response: { success: true, message: "string" }
  Future<RegisterResponse> register(RegisterRequest request) async {
    final response = await _dio.post('/auth/register', data: request.toJson());
    return RegisterResponse.fromJson(response.data);
  }

  /// POST /auth/login — Response: { success: true, token: "string" }
  Future<AuthResponse> login(String identifier, String password) async {
    final response = await _dio.post('/auth/login', data: {'usernameOrEmail': identifier, 'password': password});
    return AuthResponse.fromJson(response.data);
  }

  /// POST /auth/google — Response: { success: true, token: "string" }
  Future<AuthResponse> googleLogin(String idToken) async {
    final response = await _dio.post('/auth/google', data: GoogleLoginRequest(idToken: idToken).toJson());
    return AuthResponse.fromJson(response.data);
  }

  /// PUT /auth/password — Response: { success: true, message: "string" }
  ///
  /// The API binds `ChangePasswordRequest` from **query parameters** (not a JSON
  /// body), so the payload must be sent as `queryParameters`.
  Future<AuthResponse> changePassword({String? currentPassword, required String newPassword}) async {
    final response = await _dio.put(
      '/auth/password',
      queryParameters: <String, dynamic>{
        if (currentPassword != null && currentPassword.isNotEmpty) 'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    return AuthResponse.fromJson(response.data);
  }
}
