/// Request body for `PATCH /payment-records/:id`.
///
/// All fields are optional — only the fields the user changed are sent.
class UpdatePaymentRecordRequest {
  const UpdatePaymentRecordRequest({
    this.amount,
    this.paymentMedium,
    this.transactionType,
    this.recipientName,
    this.recipientIdentifier,
    this.note,
    this.category,
    this.updateBankBalance,
  });

  final double? amount;
  final String? paymentMedium;
  final String? transactionType;
  final String? recipientName;
  final String? recipientIdentifier;
  final String? note;
  final String? category;
  final bool? updateBankBalance;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (amount != null) 'amount': amount,
      if (paymentMedium != null && paymentMedium!.isNotEmpty) 'paymentMedium': paymentMedium,
      if (transactionType != null && transactionType!.isNotEmpty) 'transactionType': transactionType,
      if (recipientName != null && recipientName!.isNotEmpty) 'recipientName': recipientName,
      if (recipientIdentifier != null && recipientIdentifier!.isNotEmpty) 'recipientIdentifier': recipientIdentifier,
      if (note != null && note!.isNotEmpty) 'note': note,
      if (category != null && category!.isNotEmpty) 'category': category,
      if (updateBankBalance != null) 'updateBankBalance': updateBankBalance,
    };
  }
}
