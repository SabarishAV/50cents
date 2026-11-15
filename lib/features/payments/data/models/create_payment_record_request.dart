/// Request body for `POST /payment-records`.
///
/// `paidAt` is optional: when omitted the backend stamps the payment time. The
/// manual entry screen sends it explicitly so payments made outside the app
/// keep their real date and time.
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
    this.paidAt,
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

  /// When the payment happened. The API accepts an ISO-8601 instant, so this
  /// is converted to UTC before being sent.
  final DateTime? paidAt;

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
      if (paidAt != null) 'paidAt': paidAt!.toUtc().toIso8601String(),
    };
  }
}
