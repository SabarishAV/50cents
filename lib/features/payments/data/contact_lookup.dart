import 'contact_directory.dart';

/// Looks up a phone number in the device's address book.
///
/// Contact access is optional: if the user denies permission, the number is
/// not saved, or the lookup fails, this returns `null` and the pay sheet keeps
/// using its normal fallback name.
class ContactNameLookup {
  ContactNameLookup._();

  /// Returns the saved contact name for [phone], if one can be found.
  static Future<String?> nameForPhone(String phone) async {
    final key = _lastTenDigits(phone);
    if (key == null) return null;

    final entries = await ContactDirectory.load();
    for (final entry in entries) {
      if (_lastTenDigits(entry.number) == key) return entry.name;
    }
    return null;
  }

  /// Normalizes Indian numbers so `+91 98765 43210`, `098765 43210` and
  /// `9876543210` all map to the same contact.
  static String? _lastTenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }
}
