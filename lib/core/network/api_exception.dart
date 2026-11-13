import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const <String, String>{}});

  final String message;
  final int? statusCode;

  /// Per-field validation messages keyed by the API field name (e.g. `newPassword`).
  final Map<String, String> fieldErrors;

  factory ApiException.from(DioException e) {
    // No response at all: timeout, no internet, server down
    if (e.response == null) {
      return ApiException('Can\'t reach the server. Check your connection and try again.');
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;

    final fieldErrors = <String, String>{};
    String? message;

    // The API sends { success, statusCode, code, message, fields?, path, timestamp }.
    if (data is Map) {
      final rawFields = data['fields'];
      if (rawFields is Map) {
        rawFields.forEach((key, value) {
          if (key is String && value is String && value.trim().isNotEmpty) {
            fieldErrors[key] = value.trim();
          }
        });
      }

      if (data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
        message = (data['message'] as String).trim();
      }
    }

    message ??= switch (status) {
      400 => 'The request was invalid. Please check your details and try again.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You don\'t have permission to do that.',
      404 => 'Not found.',
      _ => 'Something went wrong. Please try again.',
    };

    return ApiException(message, statusCode: status, fieldErrors: fieldErrors);
  }

  @override
  String toString() => message;
}
