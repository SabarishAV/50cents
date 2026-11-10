import 'package:flutter_contacts/flutter_contacts.dart';

/// Looks up a phone number in the device's address book.
///
/// Contact access is optional: if the user denies permission, the number is
/// not saved, or the lookup fails, this returns `null` and the pay sheet keeps
/// using its normal fallback name.
class ContactNameLookup {
  ContactNameLookup._();

  static Map<String, String>? _byPhone;
  static Future<Map<String, String>>? _pending;
  static bool _permissionDenied = false;

  /// Returns the saved contact name for [phone], if one can be found.
  static Future<String?> nameForPhone(String phone) async {
    final key = _lastTenDigits(phone);
    if (key == null) return null;

    final contacts = await _load();
    return contacts[key];
  }

  static Future<Map<String, String>> _load() async {
    final cached = _byPhone;
    if (cached != null) return cached;

    final pending = _pending;
    if (pending != null) return pending;

    final future = _loadUncached();
    _pending = future;
    try {
      return await future;
    } finally {
      _pending = null;
    }
  }

  static Future<Map<String, String>> _loadUncached() async {
    if (_permissionDenied) return const {};

    try {
      var status = await FlutterContacts.permissions.check(PermissionType.read);
      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        status = await FlutterContacts.permissions.request(PermissionType.read);
      }

      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        _permissionDenied = true;
        return const {};
      }

      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.name, ContactProperty.phone});

      final byPhone = <String, String>{};
      for (final contact in contacts) {
        final name = contact.displayName?.trim();
        if (name == null || name.isEmpty) continue;

        for (final phone in contact.phones) {
          final key = _lastTenDigits(phone.normalizedNumber ?? phone.number);
          if (key != null) byPhone.putIfAbsent(key, () => name);
        }
      }

      _byPhone = byPhone;
      return byPhone;
    } catch (_) {
      // Contacts are a convenience; a failure must not block a payment.
      return const {};
    }
  }

  /// Normalizes Indian numbers so `+91 98765 43210`, `098765 43210` and
  /// `9876543210` all map to the same contact.
  static String? _lastTenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }
}
