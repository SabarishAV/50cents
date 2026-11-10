import 'package:url_launcher/url_launcher.dart';

/// A parsed UPI payment intent from a QR code or manual entry.
class UpiPayment {
  const UpiPayment({required this.payeeVpa, this.payeeName, this.amount, this.note});

  final String payeeVpa;
  final String? payeeName;
  final String? amount;
  final String? note;

  /// Parses a UPI QR payload such as
  /// `upi://pay?pa=someone@okaxis&pn=Someone&am=120.50&cu=INR`.
  ///
  /// Also accepts a bare VPA (`someone@okaxis`) for convenience.
  static UpiPayment? tryParse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    if (!value.toLowerCase().startsWith('upi://')) {
      if (RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}$').hasMatch(value)) {
        return UpiPayment(payeeVpa: value);
      }
      return null;
    }

    Uri uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      return null;
    }

    final params = uri.queryParameters;
    final payee = _clean(params['pa']);
    if (payee == null) return null;

    return UpiPayment(
      payeeVpa: payee,
      payeeName: _clean(params['pn']),
      amount: _clean(params['am']),
      note: _clean(params['tn']),
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Uri toUri({String? amountOverride, String? noteOverride}) {
    final params = <String, String>{
      'pa': payeeVpa,
      'pn': ?payeeName,
      if (amountOverride != null && amountOverride.isNotEmpty) 'am': amountOverride,
      if (noteOverride != null && noteOverride.isNotEmpty) 'tn': noteOverride,
      'cu': 'INR',
    };
    return Uri(scheme: 'upi', host: 'pay', queryParameters: params);
  }
}

/// Opens the user's installed UPI app with the given intent.
///
/// Returns `false` when no app can handle the intent.
Future<bool> launchUpiApp(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Builds the standard UPI intent for a phone number.
///
/// UPI apps resolve phone numbers through their own bank/PSP mapping, so the
/// conventional `number@upi` handle is used as the payee address.
UpiPayment phonePayment(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return UpiPayment(payeeVpa: '$digits@upi', payeeName: 'Mobile $digits');
}
