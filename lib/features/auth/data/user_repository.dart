import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:_50cents/core/network/api_client.dart';
import 'package:_50cents/core/network/api_exception.dart';

import 'models/user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dio = ref.read(dioProvider);
  return UserRepository(dio);
});

/// Signed-in user profile from `GET /user`, including the current balance.
final currentUserProvider = FutureProvider<User>((ref) {
  return ref.read(userRepositoryProvider).getUser();
});

/// Data layer for the user profile endpoints (GET /user, PATCH /user).
class UserRepository {
  final Dio _dio;
  UserRepository(this._dio);

  /// GET /user — Returns the signed-in user's profile including `upi`,
  /// `mobile` and the current `balance`. Requires a valid Bearer token
  /// (added by the Dio interceptor).
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

  /// PATCH /user — Updates the user's bank balance.
  ///
  /// The response is a generic envelope, so re-read the profile afterwards.
  Future<User> updateBalance({required double balance}) async {
    await _dio.patch<dynamic>('/user', data: <String, dynamic>{'bankBalance': balance});
    return getUser();
  }

  /// DELETE /user/upi-id — Clears the user's payment identifier.
  Future<User> removeUpiId() async {
    await _dio.delete<dynamic>('/user/upi-id');
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
