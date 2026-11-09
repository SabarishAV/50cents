/// Shared response for login/google-sign-in endpoints (LoginUserResponse).
class AuthResponse {
  final bool success;
  final String? token;
  final String? message;

  AuthResponse({required this.success, this.token, this.message});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(success: json['success'] ?? false, token: json['token'], message: json['message']);
  }
}

/// Response for the register endpoint (Response schema).
class RegisterResponse {
  final bool success;
  final String message;

  RegisterResponse({required this.success, required this.message});

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(success: json['success'] ?? false, message: json['message'] ?? 'Registration failed');
  }
}
