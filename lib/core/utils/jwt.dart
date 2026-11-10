import 'dart:convert';

/// Decodes the payload (claims) of a JWT **without verifying the signature**.
///
/// This is only used to surface information already handed to us by our own
/// backend (name, email, id, expiry...). Never trust these values for security
/// decisions — the server remains the source of truth.
///
/// Returns an empty map when [token] is not a well-formed JWT (for example an
/// opaque token), so callers never have to handle decoding errors.
Map<String, dynamic> decodeJwtPayload(String token) {
  final segments = token.split('.');
  if (segments.length != 3) return const <String, dynamic>{};

  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(segments[1])));
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
  } catch (_) {
    return const <String, dynamic>{};
  }
}
