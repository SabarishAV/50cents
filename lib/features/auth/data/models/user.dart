class User {
  const User({this.id, this.name, this.username, this.email, this.mobile, this.upi, this.avatarUrl, this.balance});

  final String? id;
  final String? name;
  final String? username;
  final String? email;
  final String? mobile;
  final String? upi;
  final String? avatarUrl;

  /// Current account balance returned by `GET /user`, when provided.
  final double? balance;

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
    // Some responses wrap the profile in `{ success, data: {...} }`. Merge so
    // either shape (or a mix of both) is handled without losing known fields.
    final data = json['data'];
    final payload = data is Map ? <String, dynamic>{...json, ...Map<String, dynamic>.from(data)} : json;

    return User(
      id: _string(payload, 'id'),
      name: _string(payload, 'name') ?? _string(payload, 'fullName'),
      username: _string(payload, 'username'),
      email: _string(payload, 'email'),
      mobile: _string(payload, 'mobile') ?? _string(payload, 'phone') ?? _string(payload, 'phoneNumber'),
      upi: _string(payload, 'upi') ?? _string(payload, 'upiId') ?? _string(payload, 'vpa'),
      avatarUrl: _string(payload, 'avatar') ?? _string(payload, 'avatarUrl') ?? _string(payload, 'picture'),
      balance: _balance(payload),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (mobile != null) 'mobile': mobile,
      if (upi != null) 'upiId': upi,
      if (avatarUrl != null) 'avatar': avatarUrl,
      if (balance != null) 'bankBalance': balance,
    };
  }

  static const List<String> _balanceKeys = <String>[
    'balance',
    'bankBalance',
    'walletBalance',
    'accountBalance',
    'currentBalance',
    'availableBalance',
    'wallet_balance',
    'account_balance',
  ];

  static double? _balance(Map<String, dynamic> json) {
    final direct = _amount(json);
    if (direct != null) return direct;

    final wallet = json['wallet'];
    if (wallet is Map) return _amount(Map<String, dynamic>.from(wallet));
    return null;
  }

  static double? _amount(Map<String, dynamic> json) {
    for (final key in _balanceKeys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.\-]'), ''));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}
