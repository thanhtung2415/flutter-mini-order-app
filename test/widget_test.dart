import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mini_order_app/main.dart';
import 'package:mini_order_app/repositories/mock_order_repository.dart';
import 'package:mini_order_app/state/app_state.dart';

void main() {
  testWidgets('shows login screen', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(MockOrderRepository()),
        child: const MiniOrderApp(),
      ),
    );

    expect(find.text('Flutter Mini Order App'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNWidgets(2));
  });
}
