import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:_50cents/core/network/api_client.dart';
import 'package:_50cents/core/network/api_exception.dart';

import 'models/user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dio = ref.read(dioProvider);
  return UserRepository(dio);
});

/// Data layer for the user profile endpoints (GET /user, PATCH /user).
class UserRepository {
  final Dio _dio;
  UserRepository(this._dio);

  /// GET /user — Returns the signed-in user's profile including `upi` and
  /// `mobile`. Requires a valid Bearer token (added by the Dio interceptor).
  Future<User> getUser() async {
    final response = await _dio.get('/user');
    return User.fromJson(response.data);
  }

  /// PATCH /user — Updates the user's UPI ID.
  ///
  /// The API accepts `{ 'upiId': upiId }` as a JSON body but replies with a
  /// generic `{ success, message }` envelope, so the updated profile is read
  /// back with a follow-up `GET /user`. Parsing the PATCH response as a user
  /// would return an empty profile and wrongly drop the payment ID.
  Future<User> updateUpi({required String upiId}) async {
    await _dio.patch('/user', data: <String, dynamic>{'upiId': upiId});
    return getUser();
  }
}

/// Converts any error thrown by the repository into a clean user-facing message.
String userErrorMessage(dynamic error) {
  if (error is DioException) {
    return ApiException.from(error).message;
  }
  if (error is ApiException) {
    return error.message;
  }
  final message = error.toString();
  return message.startsWith('Exception: ') ? message.substring('Exception: '.length) : message;
}
