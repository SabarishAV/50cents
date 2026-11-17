class User {
  const User({this.id, this.name, this.email, this.mobile, this.upi, this.avatarUrl});

  final String? id;
  final String? name;
  final String? email;
  final String? mobile;
  final String? upi;
  final String? avatarUrl;

  /// Preferred payment identifier — UPI ID when set, otherwise mobile.
  String get paymentId => upi ?? mobile ?? email ?? id ?? '';

  /// Display-friendly label for the identifier shown in the QR header.
  String get paymentLabel {
    if (upi != null) {
      // The API stores a phone-number payment ID in the same `upiId` field.
      return upi!.contains('@') ? 'UPI ID' : 'Mobile';
    }
    return mobile != null ? 'Mobile' : 'Account';
  }

  String get displayName => name ?? email ?? 'there';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _string(json, 'id'),
      name: _string(json, 'name') ?? _string(json, 'fullName') ?? _string(json, 'username'),
      email: _string(json, 'email'),
      mobile: _string(json, 'mobile') ?? _string(json, 'phone') ?? _string(json, 'phoneNumber'),
      upi: _string(json, 'upi') ?? _string(json, 'upiId') ?? _string(json, 'vpa'),
      avatarUrl: _string(json, 'avatar') ?? _string(json, 'avatarUrl') ?? _string(json, 'picture'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (mobile != null) 'mobile': mobile,
      if (upi != null) 'upi': upi,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }

  static String? _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}
