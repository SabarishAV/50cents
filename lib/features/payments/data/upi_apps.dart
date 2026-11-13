import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'upi_payment.dart';

/// An installed app that can handle a UPI payment intent.
///
/// On Android these are discovered from the package manager (real label and
/// icon). On iOS the OS does not allow listing apps, so a curated set of known
/// UPI apps is probed by scheme and [icon] is always null.
class UpiApp {
  const UpiApp({required this.id, required this.name, this.icon, this.scheme});

  /// Android package name, or the URL scheme on iOS. Stable identifier.
  final String id;

  /// Display label, e.g. `PhonePe` or `Google Pay`.
  final String name;

  /// Real launcher icon as PNG bytes (Android only).
  final Uint8List? icon;

  /// Deep-link scheme used to detect this app on iOS, when applicable.
  final String? scheme;

  @override
  bool operator ==(Object other) => other is UpiApp && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Lists the UPI apps installed on this device.
///
/// Android performs a real package-manager query; iOS probes a known catalog;
/// any other platform (or a failure) yields an empty list so the caller can
/// fall back to the system chooser.
Future<List<UpiApp>> listUpiApps() async {
  if (Platform.isAndroid) return _listAndroidUpiApps();
  if (Platform.isIOS) return _listIosUpiApps();
  return const <UpiApp>[];
}

/// Opens [uri] in the specific [app] when possible.
///
/// On Android the intent is forced to the chosen package so no system chooser
/// appears and we know exactly which app was used. On iOS we cannot target a
/// specific app, so the standard `upi://` intent is opened and the OS routes
/// it; the caller records the app the user selected.
Future<bool> launchUpiWithApp(Uri uri, UpiApp app) async {
  if (Platform.isAndroid) {
    try {
      final launched = await _channel.invokeMethod<bool>('launchUpi', <String, dynamic>{
        'url': uri.toString(),
        'packageName': app.id,
      });
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  return launchUpiApp(uri);
}

const MethodChannel _channel = MethodChannel('com.app.u_50cents/upi_apps');

Future<List<UpiApp>> _listAndroidUpiApps() async {
  try {
    final raw = await _channel.invokeListMethod<dynamic>('listUpiApps');
    if (raw == null) return const <UpiApp>[];

    final apps = <UpiApp>[];
    for (final entry in raw) {
      if (entry is! Map) continue;

      final id = entry['packageName']?.toString();
      if (id == null || id.isEmpty) continue;

      final label = entry['label']?.toString().trim();
      apps.add(UpiApp(id: id, name: (label == null || label.isEmpty) ? id : label, icon: _decodeIcon(entry['icon'])));
    }
    return apps;
  } catch (_) {
    // MissingPluginException on unsupported platforms, or a native failure.
    return const <UpiApp>[];
  }
}

Uint8List? _decodeIcon(Object? value) {
  final encoded = value?.toString();
  if (encoded == null || encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}

/// Known UPI apps on iOS, matched by their URL scheme. Order matters: the first
/// installed scheme for a given display name wins (e.g. Google Pay via `tez`).
const List<({String scheme, String name})> _iosUpiCatalog = <({String scheme, String name})>[
  (scheme: 'phonepe', name: 'PhonePe'),
  (scheme: 'tez', name: 'Google Pay'),
  (scheme: 'gpay', name: 'Google Pay'),
  (scheme: 'paytmmp', name: 'Paytm'),
  (scheme: 'paytm', name: 'Paytm'),
  (scheme: 'bhim', name: 'BHIM'),
  (scheme: 'amazonpay', name: 'Amazon Pay'),
  (scheme: 'cred', name: 'CRED'),
  (scheme: 'navi', name: 'Navi'),
  (scheme: 'slice', name: 'Slice'),
  (scheme: 'mobikwik', name: 'MobiKwik'),
  (scheme: 'freecharge', name: 'Freecharge'),
  (scheme: 'supermoney', name: 'SuperMoney'),
  (scheme: 'jupiter', name: 'Jupiter'),
  (scheme: 'indmoney', name: 'INDmoney'),
];

Future<List<UpiApp>> _listIosUpiApps() async {
  final found = <UpiApp>[];
  final seenNames = <String>{};

  for (final entry in _iosUpiCatalog) {
    if (seenNames.contains(entry.name)) continue;

    bool canOpen;
    try {
      canOpen = await canLaunchUrl(Uri.parse('${entry.scheme}://'));
    } catch (_) {
      canOpen = false;
    }

    if (canOpen) {
      seenNames.add(entry.name);
      found.add(UpiApp(id: entry.scheme, name: entry.name, scheme: entry.scheme));
    }
  }

  return found;
}

/// Installed UPI apps, cached for the session so opening the pay sheet is fast.
final upiAppsProvider = FutureProvider<List<UpiApp>>((ref) => listUpiApps());

/// Remembers the app the user paid with last, so the picker can preselect it.
class UpiAppPreference {
  UpiAppPreference(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'last_upi_app_id';

  Future<String?> readId() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveId(String id) async {
    try {
      await _storage.write(key: _key, value: id);
    } catch (_) {
      // Remembering the choice is a convenience; ignore storage failures.
    }
  }
}

final upiAppPreferenceProvider = Provider<UpiAppPreference>((ref) => UpiAppPreference(const FlutterSecureStorage()));
