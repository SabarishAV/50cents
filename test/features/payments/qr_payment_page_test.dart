import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:_50cents/core/theme/app_theme.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/auth/data/models/user.dart';
import 'package:_50cents/features/auth/data/user_repository.dart';
import 'package:_50cents/features/payments/presentation/pages/qr_payment_page.dart';
import 'package:_50cents/features/payments/presentation/widgets/qr_share_image.dart';

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository(this.user);

  User user;

  @override
  Future<User> getUser() async => user;

  @override
  Future<User> updateUpi({required String upiId}) async {
    user = User(id: user.id, name: user.name, email: user.email, upi: upiId);
    return user;
  }
}

Future<_FakeUserRepository> _openPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repository = _FakeUserRepository(
    const User(id: 'u1', name: 'Test User', email: 'test@example.com', upi: 'test@okhdfcbank'),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [userRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: AppTheme.dark, home: const QrPaymentPage()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('updating the payment ID keeps the QR visible', (tester) async {
    await _openPage(tester);

    expect(find.text('test@okhdfcbank'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.widgetWithText(NeonButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('test@okhdfcbank'), findsNothing);
    expect(find.text('Share QR'), findsOneWidget);
  });

  testWidgets('invalid payment ID shows a validation message', (tester) async {
    await _openPage(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-a-upi');
    await tester.tap(find.widgetWithText(NeonButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Use a UPI ID like name@bank or a 10-digit mobile number'), findsOneWidget);
  });

  testWidgets('request amount is mandatory and note is optional', (tester) async {
    await _openPage(tester);

    await tester.tap(find.widgetWithText(NeonButton, 'Request amount'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NeonButton, 'Generate QR & link'));
    await tester.pumpAndSettle();
    expect(find.text('Amount is required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250.50');
    await tester.tap(find.widgetWithText(NeonButton, 'Generate QR & link'));
    await tester.pumpAndSettle();

    expect(find.text('₹250.50'), findsOneWidget);
    expect(find.text('Share request QR'), findsOneWidget);
  });

  testWidgets('renders a shareable PNG for a QR', (tester) async {
    final bytes = await QrShareImage.build(
      data: 'upi://pay?pa=test@okhdfcbank&pn=Test%20User&am=250.50',
      payeeName: 'Test User',
      paymentId: 'test@okhdfcbank',
      amount: '250.50',
      note: 'Dinner',
    );

    expect(bytes.length, greaterThan(1000));
    // PNG magic number.
    expect(bytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
  });
}
