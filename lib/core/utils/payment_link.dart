import 'dart:convert';

import 'package:_50cents/core/config/env.dart';

String generatePaymentRedirectUrl({required String pa, required String pn, required String am, required String tn}) {
  final expiresAt = DateTime.now().millisecondsSinceEpoch + Env.redirectExpiryMinutes * 60 * 1000;
  final payload = <String, dynamic>{'pa': pa, 'pn': pn, 'am': am, 'tn': tn, 'expiresAt': expiresAt};
  final encoded = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '${Env.redirectPageUrl}$encoded';
}

/// Builds a UPI payment URI for QR codes and deep links.
///
/// [am] and [tn] are included only when non-empty.
String generateUpiUri({required String pa, required String pn, String? am, String? tn}) {
  final params = <String, String>{'pa': pa, 'pn': pn, 'cu': 'INR'};
  if (am != null && am.trim().isNotEmpty) {
    params['am'] = am.trim();
  }
  if (tn != null && tn.trim().isNotEmpty) {
    params['tn'] = tn.trim();
  }
  return Uri(scheme: 'upi', host: 'pay', queryParameters: params).toString();
}
