import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.from(DioException e) {
    // No response at all: timeout, no internet, server down
    if (e.response == null) {
      return ApiException('Can\'t reach the server. Check your connection and try again.');
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;

    // Spring usually sends a JSON body with a "message" field
    if (data is Map && data['message'] is String) {
      return ApiException(data['message'] as String, statusCode: status);
    }

    return ApiException('Something went wrong. Please try again.', statusCode: status);
  }

  @override
  String toString() => message;
}
