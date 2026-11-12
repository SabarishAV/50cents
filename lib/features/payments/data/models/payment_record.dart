import 'package:_50cents/features/payments/data/models/payment_category.dart';

/// A single payment returned by `GET /payment-records`.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.recipientName,
    required this.recipientIdentifier,
    required this.note,
    required this.paymentMedium,
    required this.transactionType,
    required this.bankUpdated,
    required this.paidAt,
    required this.user,
    required this.category,
  });

  final String id;
  final double amount;

  /// Payee display name when the backend stored one.
  final String recipientName;

  /// UPI ID (VPA) or phone number the money was sent to, when known.
  final String? recipientIdentifier;

  final String? note;
  final String paymentMedium;
  final String transactionType;
  final bool bankUpdated;
  final DateTime paidAt;
  final dynamic user;

  /// Category the payment was bucketed into, when the backend resolved one.
  final PaymentCategory category;

  /// Best-effort payee label for display: stored name first, then identifier.
  String get payeeLabel {
    final name = recipientName.trim();
    if (name.isNotEmpty) return name;

    final identifier = recipientIdentifier?.trim();
    if (identifier != null && identifier.isNotEmpty) return identifier;

    return 'Payment';
  }

  bool get isCredit => transactionType.trim().toUpperCase() == 'CREDIT';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'];
    return PaymentRecord(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      recipientName: json['recipientName']?.toString() ?? '',
      recipientIdentifier: json['recipientIdentifier']?.toString(),
      note: json['note']?.toString(),
      paymentMedium: json['paymentMedium']?.toString().trim() ?? 'UPI',
      transactionType: json['transactionType']?.toString().trim().toUpperCase() ?? 'DEBIT',
      bankUpdated: json['bankUpdated'] == true,
      paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      user: json['user'],
      category: rawCategory is Map
          ? PaymentCategory.fromJson(Map<String, dynamic>.from(rawCategory))
          : const PaymentCategory(id: '', name: 'Uncategorized', code: ''),
    );
  }
}

/// One page of the `GET /payment-records` response.
class PaymentRecordsPage {
  const PaymentRecordsPage({
    required this.data,
    required this.pageNumber,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<PaymentRecord> data;
  final int pageNumber;
  final int pageSize;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  factory PaymentRecordsPage.fromJson(Map<String, dynamic> json, {int fallbackPageNumber = 1}) {
    final rawData = json['data'];
    final List<PaymentRecord> records = rawData is List
        ? rawData
              .whereType<Map>()
              .map((entry) => PaymentRecord.fromJson(Map<String, dynamic>.from(entry)))
              .toList(growable: false)
        : <PaymentRecord>[];

    return PaymentRecordsPage(
      data: records,
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? fallbackPageNumber,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 15,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? records.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: json['hasNext'] == true,
      hasPrevious: json['hasPrevious'] == true,
    );
  }
}
