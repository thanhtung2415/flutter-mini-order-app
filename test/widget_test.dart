import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:mini_order_app/main.dart';
import 'package:mini_order_app/data/repositories/mock_order_repository.dart';
import 'package:mini_order_app/features/administration/presentation/admin_home_screen.dart';
import 'package:mini_order_app/app/state/app_state.dart';

import 'test_authentication_service.dart';

void main() {
  Widget buildTestApp(TestAuthenticationService authenticationService) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        MockOrderRepository(),
        authenticationService: authenticationService,
      ),
      child: const MiniOrderApp(),
    );
  }

  testWidgets('shows login screen', (tester) async {
    await tester.pumpWidget(buildTestApp(TestAuthenticationService()));

    expect(find.text('Flutter Mini Order App'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNWidgets(2));
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
  });

  testWidgets('fits the login flow on a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(TestAuthenticationService()));
    await tester.pumpAndSettle();

    expect(find.text('Flutter Mini Order App'), findsOneWidget);
    expect(find.byIcon(Icons.lock_reset), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff table dashboard fits large system text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final state = AppState(
      MockOrderRepository(),
      authenticationService: TestAuthenticationService(),
    );
    await state.login('staff@miniorder.vn', '123456');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const MiniOrderApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mini Order'), findsOneWidget);
    expect(find.text('Sẵn sàng'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closes forgot-password dialog without lifecycle errors', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(TestAuthenticationService()));

    await tester.tap(find.byIcon(Icons.lock_reset));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forgot-password-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forgot-password-email')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends reset email and closes dialog without lifecycle errors', (
    tester,
  ) async {
    final authenticationService = TestAuthenticationService();
    await tester.pumpWidget(buildTestApp(authenticationService));

    await tester.tap(find.byIcon(Icons.lock_reset));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('forgot-password-email')),
      'user@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot-password-send')));
    await tester.pumpAndSettle();

    expect(authenticationService.passwordResetEmail, 'user@example.com');
    expect(find.byKey(const Key('forgot-password-email')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens invoice details from admin order history', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await initializeDateFormatting('vi_VN');

    final authenticationService = TestAuthenticationService();
    final state = AppState(
      MockOrderRepository(),
      authenticationService: authenticationService,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: AdminHistoryPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-history-o_paid')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-invoice-sheet')), findsOneWidget);
    expect(find.text('Chi tiết hóa đơn'), findsOneWidget);
    expect(find.text('Cà phê sữa'), findsOneWidget);
    expect(find.text('Cơm gà'), findsOneWidget);
    expect(find.text('Tổng cộng'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('order-invoice-sheet')),
        matching: find.text('Tiền mặt'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
