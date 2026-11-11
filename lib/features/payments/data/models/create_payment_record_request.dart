/// Request body for `POST /payment-records`.
///
/// `paidAt` is intentionally omitted so the backend stamps the payment time.
class CreatePaymentRecordRequest {
  const CreatePaymentRecordRequest({
    required this.amount,
    required this.paymentMedium,
    required this.transactionType,
    required this.updateBankBalance,
    this.recipientName,
    this.recipientIdentifier,
    this.note,
    this.category,
  });

  final double amount;

  /// Display name of the payee (contact name, QR name or a typed name).
  /// Optional — omitted entirely when the user did not enter one.
  final String? recipientName;

  /// The UPI ID (VPA) or phone number the payment was sent to.
  final String? recipientIdentifier;

  final String? note;
  final String paymentMedium;
  final String transactionType;
  final String? category;
  final bool updateBankBalance;

  Map<String, dynamic> toJson() {
    final trimmedName = recipientName?.trim();
    final trimmedIdentifier = recipientIdentifier?.trim();
    final trimmedNote = note?.trim();
    final trimmedCategory = category?.trim();

    return <String, dynamic>{
      'amount': amount,
      if (trimmedName != null && trimmedName.isNotEmpty) 'recipientName': trimmedName,
      if (trimmedIdentifier != null && trimmedIdentifier.isNotEmpty) 'recipientIdentifier': trimmedIdentifier,
      if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
      'paymentMedium': paymentMedium,
      'transactionType': transactionType,
      if (trimmedCategory != null && trimmedCategory.isNotEmpty) 'category': trimmedCategory,
      'updateBankBalance': updateBankBalance,
    };
  }
}
