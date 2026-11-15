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

  /// POST /auth/forgot-password/request — Response: { success: true, message: "string" }
  ///
  /// Sends a 6-digit OTP to the account's registered email. The API binds
  /// `ForgotPasswordRequest` from **query parameters** (not a JSON body).
  Future<AuthResponse> requestPasswordReset(String identifier) async {
    final response = await _dio.post(
      '/auth/forgot-password/request',
      queryParameters: <String, dynamic>{'identifier': identifier},
    );
    return AuthResponse.fromJson(response.data);
  }

  /// POST /auth/forgot-password/verify — Response: { success: true, message: "string" }
  ///
  /// Confirms the OTP and sets the new password. The response has no token, so
  /// the user must sign in again afterwards.
  Future<AuthResponse> verifyPasswordReset({
    required String identifier,
    required String otp,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/forgot-password/verify',
      queryParameters: <String, dynamic>{'identifier': identifier, 'otp': otp, 'password': password},
    );
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

  /// POST /user/email/change/request — Response: { success: true, message: "string" }
  ///
  /// Sends an OTP to the new email address. Like the password endpoint, the API
  /// binds `ChangeEmailOtpRequest` from **query parameters**.
  Future<AuthResponse> requestEmailChange(String email) async {
    final response = await _dio.post('/user/email/change/request', queryParameters: <String, dynamic>{'email': email});
    return AuthResponse.fromJson(response.data);
  }

  /// POST /user/email/change/verify — Response: { success: true, message: "string" }
  ///
  /// Confirms the OTP sent to the new email and updates the account email.
  Future<AuthResponse> verifyEmailChange(String otp) async {
    final response = await _dio.post('/user/email/change/verify', queryParameters: <String, dynamic>{'otp': otp});
    return AuthResponse.fromJson(response.data);
  }

  /// POST /user/delete/request — Response: { success: true, message: "string" }
  ///
  /// Sends an OTP to the registered email to confirm the deletion. The password
  /// is optional because accounts created with Google may not have one. Like the
  /// other user endpoints, the API binds the request from **query parameters**.
  Future<AuthResponse> requestAccountDeletion({String? password}) async {
    final response = await _dio.post(
      '/user/delete/request',
      queryParameters: <String, dynamic>{if (password != null && password.isNotEmpty) 'password': password},
    );
    return AuthResponse.fromJson(response.data);
  }

  /// POST /user/delete/verify — Response: { success: true, message: "string" }
  ///
  /// Confirms the OTP sent to the registered email and permanently deletes the
  /// account. The token is invalid afterwards, so the caller must sign out.
  Future<AuthResponse> verifyAccountDeletion(String otp) async {
    final response = await _dio.post('/user/delete/verify', queryParameters: <String, dynamic>{'otp': otp});
    return AuthResponse.fromJson(response.data);
  }
}
