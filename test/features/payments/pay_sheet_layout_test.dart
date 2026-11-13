import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:_50cents/features/payments/data/models/payment_category.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';
import 'package:_50cents/features/payments/data/upi_apps.dart';
import 'package:_50cents/features/payments/data/upi_payment.dart';
import 'package:_50cents/features/payments/presentation/widgets/pay_sheet.dart';
import 'package:_50cents/features/payments/presentation/widgets/upi_app_picker.dart';

/// 1x1 transparent PNG, used to exercise the real-icon code path.
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

final _apps = <UpiApp>[
  UpiApp(id: 'com.phonepe.app', name: 'PhonePe', icon: _tinyPng),
  UpiApp(id: 'net.one97.paytm', name: 'Paytm'),
  UpiApp(id: 'com.google.android.apps.nbu.paisa.user', name: 'Google Pay', icon: _tinyPng),
];

class _FakePreference extends UpiAppPreference {
  _FakePreference() : super(const FlutterSecureStorage());

  @override
  Future<String?> readId() async => null;

  @override
  Future<void> saveId(String id) async {}
}

Future<void> _openPaySheet(
  WidgetTester tester,
  PayTarget target, {
  List<UpiApp> apps = const <UpiApp>[],
  UpiPayment? scanned,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoriesProvider.overrideWith((ref) async => const <PaymentCategory>[]),
        upiAppsProvider.overrideWith((ref) async => apps),
        upiAppPreferenceProvider.overrideWithValue(_FakePreference()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPaySheet(context, target: target, scanned: scanned),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump();
  // Let the app lookup finish and the sheet settle.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();

  // A layout assert (e.g. unbounded RenderFlex) surfaces here.
  expect(tester.takeException(), isNull);
}

void main() {
  group('pay sheet', () {
    testWidgets('lays out with detected UPI apps but does not list them', (tester) async {
      await _openPaySheet(tester, PayTarget.upi, apps: _apps);

      // The picker lives behind the Pay button, not in the form.
      expect(find.text('PAY WITH'), findsNothing);
      expect(find.text('PhonePe'), findsNothing);
      expect(find.text('Other apps'), findsNothing);
      expect(find.text('DETAILS'), findsOneWidget);
    });

    testWidgets('lays out when no UPI apps are detected', (tester) async {
      await _openPaySheet(tester, PayTarget.upi);
      expect(find.text('PAY WITH'), findsNothing);
    });

    testWidgets('lays out in phone mode', (tester) async {
      await _openPaySheet(tester, PayTarget.phone, apps: _apps);
      expect(find.text('DETAILS'), findsOneWidget);
    });

    testWidgets('lays out in scanned mode', (tester) async {
      await _openPaySheet(
        tester,
        PayTarget.upi,
        apps: _apps,
        scanned: const UpiPayment(payeeVpa: 'someone@upi', payeeName: 'Someone'),
      );
      expect(find.text('DETAILS'), findsOneWidget);
    });
  });

  group('UPI app picker', () {
    Future<void> openPicker(WidgetTester tester, void Function(UpiAppChoice?) onResult, {String? preselectId}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    onResult(
                      await showUpiAppPicker(
                        context,
                        apps: _apps,
                        preselectId: preselectId,
                        subtitle: '₹500 to someone@upi',
                      ),
                    );
                  },
                  child: const Text('pick'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('shows every app plus the chooser fallback', (tester) async {
      await openPicker(tester, (_) {});

      expect(find.text('Pay with'), findsOneWidget);
      expect(find.text('₹500 to someone@upi'), findsOneWidget);
      for (final app in _apps) {
        expect(find.text(app.name), findsOneWidget);
      }
      expect(find.text('Other apps'), findsOneWidget);
    });

    testWidgets('preselects the last used app', (tester) async {
      await openPicker(tester, (_) {}, preselectId: 'net.one97.paytm');

      expect(find.text('Continue with Paytm'), findsOneWidget);
    });

    testWidgets('returns the chosen app', (tester) async {
      UpiAppChoice? choice;
      await openPicker(tester, (value) => choice = value);

      await tester.tap(find.text('PhonePe'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with PhonePe'), findsOneWidget);

      await tester.tap(find.text('Continue with PhonePe'));
      await tester.pumpAndSettle();

      expect(choice?.app?.id, 'com.phonepe.app');
    });

    testWidgets('returns the system chooser when "Other apps" is chosen', (tester) async {
      UpiAppChoice? choice;
      await openPicker(tester, (value) => choice = value);

      await tester.tap(find.text('Other apps'));
      await tester.pumpAndSettle();
      expect(find.text('Open app chooser'), findsOneWidget);

      await tester.tap(find.text('Open app chooser'));
      await tester.pumpAndSettle();

      expect(choice, isNotNull);
      expect(choice!.app, isNull);
    });

    testWidgets('returns null when dismissed', (tester) async {
      UpiAppChoice? choice;
      await openPicker(tester, (value) => choice = value);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(choice, isNull);
    });
  });
}
