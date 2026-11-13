/// Totals returned by `GET /payment-records/summary`.
class PaymentSummary {
  const PaymentSummary({required this.totalCredit, required this.totalDebit, required this.net});

  /// Money received in the selected period.
  final double totalCredit;

  /// Money sent in the selected period.
  final double totalDebit;

  /// `totalCredit - totalDebit`, kept as returned by the server.
  final double net;

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      totalCredit: (json['totalCredit'] as num?)?.toDouble() ?? 0,
      totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
    );
  }
}
