import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:_50cents/core/network/api_client.dart';
import 'package:_50cents/core/network/api_exception.dart';

import 'models/create_payment_record_request.dart';
import 'models/payment_category.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.read(dioProvider));
});

/// Categories are cached for the session so opening the pay sheet is instant.
final categoriesProvider = FutureProvider<List<PaymentCategory>>((ref) async {
  return ref.watch(paymentRepositoryProvider).listCategories();
});

/// Data layer for payment records and category lookup.
class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  /// GET /categories
  Future<List<PaymentCategory>> listCategories() async {
    final response = await _dio.get<dynamic>('/categories');
    final data = response.data;

    if (data is! List) return const [];

    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => PaymentCategory.fromJson(Map<String, dynamic>.from(item)))
        .where((category) => category.code.isNotEmpty)
        .toList(growable: false);
  }

  /// GET /categories/predict
  ///
  /// The endpoint returns a string map; its key may vary, so every non-empty
  /// value is returned and matched against the category list by the caller.
  Future<List<String>> predictCategory({required String recipient, String? note}) async {
    final trimmedNote = note?.trim();

    final response = await _dio.get<dynamic>(
      '/categories/predict',
      queryParameters: <String, dynamic>{
        'recipient': recipient,
        'transactionType': 'DEBIT',
        if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
      },
    );

    final data = response.data;
    if (data is String) {
      final value = data.trim();
      return value.isEmpty ? const [] : <String>[value];
    }
    if (data is! Map) return const [];

    return data.values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  /// POST /payment-records
  Future<void> createPaymentRecord(CreatePaymentRecordRequest request) async {
    final response = await _dio.post<dynamic>('/payment-records', data: request.toJson());
    final data = response.data;

    if (data is Map && data['success'] == false) {
      final message = data['message'];
      throw ApiException(
        message is String && message.trim().isNotEmpty ? message.trim() : 'Could not save this payment.',
        statusCode: response.statusCode,
      );
    }
  }
}

/// Converts Dio or API errors into a short, user-friendly message.
String apiErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return ApiException.from(error).message;
  return 'Something went wrong. Please try again.';
}
