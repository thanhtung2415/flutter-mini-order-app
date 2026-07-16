import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mini_order_app/main.dart';
import 'package:mini_order_app/repositories/mock_order_repository.dart';
import 'package:mini_order_app/state/app_state.dart';

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
}
