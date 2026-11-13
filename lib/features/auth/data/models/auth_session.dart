import 'package:_50cents/core/utils/jwt.dart';

/// Everything we keep around after a successful login:
/// the raw token plus the claims decoded from it.
///
/// The token is what authenticates API calls; the claims are handy for showing
/// the signed-in user (name, email, avatar...) without another API round-trip.
class AuthSession {
  const AuthSession({required this.token, this.claims = const <String, dynamic>{}});

  final String token;
  final Map<String, dynamic> claims;

  /// Builds a session from a raw token, decoding its JWT payload.
  factory AuthSession.fromToken(String token) {
    return AuthSession(token: token, claims: decodeJwtPayload(token));
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] as String?) ?? '';
    final rawClaims = json['claims'];
    final claims = rawClaims is Map ? Map<String, dynamic>.from(rawClaims) : decodeJwtPayload(token);

    return AuthSession(token: token, claims: claims);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'token': token, 'claims': claims};

  String? _stringClaim(String key) {
    final value = claims[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  /// User identifier from the token (falls back to common alternative names).
  String? get userId => _stringClaim('sub') ?? _stringClaim('userId') ?? _stringClaim('id');

  String? get email => _stringClaim('email');

  String? get username => _stringClaim('username') ?? _stringClaim('preferred_username') ?? _stringClaim('user_name');

  String? get name => _stringClaim('name') ?? _stringClaim('fullName') ?? _stringClaim('username');

  String? get avatarUrl => _stringClaim('picture') ?? _stringClaim('avatar');

  DateTime? get expiresAt {
    final raw = claims['exp'];
    final seconds = switch (raw) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(DateTime.now().toUtc());
  }

  /// Human-friendly name used across the app.
  String get displayName => name ?? email ?? 'there';

  /// First letter(s) used for the avatar bubble.
  String get initials {
    final source = name?.trim();
    if (source == null || source.isEmpty) {
      final mail = email;
      return (mail == null || mail.isEmpty) ? '?' : mail.characters.first.toUpperCase();
    }

    final parts = source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
  }
}

/// Tiny helper so we do not need the `characters` package import everywhere.
extension on String {
  Iterable<String> get characters => split('');
}
