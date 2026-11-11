import 'package:flutter_contacts/flutter_contacts.dart';

/// A contact's display name paired with one of their phone numbers.
class ContactEntry {
  const ContactEntry({required this.name, required this.number});

  final String name;
  final String number;

  /// Digits only, with Indian formatting stripped so `+91 98765 43210`,
  /// `098765 43210` and `98765-43210` all become `9876543210`.
  String get digits {
    var digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }
}

/// Loads the device address book and caches it for the session.
///
/// Contact access is optional: if the user denies permission or the lookup
/// fails, [load] returns an empty list instead of throwing.
class ContactDirectory {
  ContactDirectory._();

  static List<ContactEntry>? _entries;
  static Future<List<ContactEntry>>? _pending;
  static bool _permissionDenied = false;

  /// True after the user denied contact access this session.
  static bool get permissionDenied => _permissionDenied;

  /// Returns every contact that has a name and at least one phone number.
  static Future<List<ContactEntry>> load({bool refresh = false}) async {
    if (refresh) {
      _entries = null;
      _permissionDenied = false;
    }

    final cached = _entries;
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

  static Future<List<ContactEntry>> _loadUncached() async {
    if (_permissionDenied) return const [];

    try {
      var status = await FlutterContacts.permissions.check(PermissionType.read);
      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        status = await FlutterContacts.permissions.request(PermissionType.read);
      }

      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        _permissionDenied = true;
        return const [];
      }

      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.name, ContactProperty.phone});

      final entries = <ContactEntry>[];
      for (final contact in contacts) {
        final name = contact.displayName?.trim();
        if (name == null || name.isEmpty) continue;

        for (final phone in contact.phones) {
          final number = phone.number.trim();
          if (number.isEmpty) continue;
          entries.add(ContactEntry(name: name, number: number));
        }
      }

      entries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _entries = List.unmodifiable(entries);
      return _entries!;
    } catch (_) {
      // Contacts are a convenience; a failure must not block a payment.
      return const [];
    }
  }
}
