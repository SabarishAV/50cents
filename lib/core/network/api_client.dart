import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final tokenStorage = ref.read(tokenStorageProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Skip auth header for public auth endpoints (register, login, google,
        // password reset) but include it for protected auth endpoints.
        final isPublicAuthEndpoint =
            options.path == '/auth/register' ||
            options.path == '/auth/login' ||
            options.path == '/auth/google' ||
            options.path == '/auth/forgot-password/request' ||
            options.path == '/auth/forgot-password/verify';

        if (!isPublicAuthEndpoint) {
          final token = await tokenStorage.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (DioException e, handler) {
        // Pass the DioException through; callers convert to ApiException.
        handler.next(e);
      },
    ),
  );

  return dio;
});
