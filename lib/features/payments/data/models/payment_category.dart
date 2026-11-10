/// A category returned by `GET /categories`.
class PaymentCategory {
  const PaymentCategory({required this.id, required this.name, required this.code, this.image});

  final String id;
  final String name;
  final String code;
  final String? image;

  factory PaymentCategory.fromJson(Map<String, dynamic> json) {
    return PaymentCategory(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?)?.trim() ?? 'Unnamed category',
      code: (json['code'] as String?)?.trim() ?? '',
      image: (json['image'] as String?)?.trim(),
    );
  }
}
