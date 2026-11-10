/// Request body for `POST /payment-records`.
///
/// `paidAt` is intentionally omitted so the backend stamps the payment time.
class CreatePaymentRecordRequest {
  const CreatePaymentRecordRequest({
    required this.amount,
    required this.recipientName,
    required this.paymentMedium,
    required this.transactionType,
    required this.updateBankBalance,
    this.note,
    this.category,
  });

  final double amount;
  final String recipientName;
  final String? note;
  final String paymentMedium;
  final String transactionType;
  final String? category;
  final bool updateBankBalance;

  Map<String, dynamic> toJson() {
    final trimmedNote = note?.trim();
    final trimmedCategory = category?.trim();

    return <String, dynamic>{
      'amount': amount,
      'recipientName': recipientName,
      if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
      'paymentMedium': paymentMedium,
      'transactionType': transactionType,
      if (trimmedCategory != null && trimmedCategory.isNotEmpty) 'category': trimmedCategory,
      'updateBankBalance': updateBankBalance,
    };
  }
}
