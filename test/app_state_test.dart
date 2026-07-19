import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mini_order_app/domain/models/app_models.dart';
import 'package:mini_order_app/data/repositories/mock_order_repository.dart';
import 'package:mini_order_app/features/ordering/data/cart_draft_storage_service.dart';
import 'package:mini_order_app/features/ordering/data/firestore_order_transaction_service.dart';
import 'package:mini_order_app/data/storage/local_database_storage_service.dart';
import 'package:mini_order_app/features/reporting/data/report_service.dart';
import 'package:mini_order_app/app/state/app_state.dart';

import 'test_authentication_service.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('AppState business flow', () {
    late AppState state;

    setUp(() {
      state = AppState(
        MockOrderRepository(),
        authenticationService: TestAuthenticationService(),
      );
    });

    test('logs in with demo admin and staff accounts', () async {
      expect(await state.login('admin@miniorder.vn', '123456'), isTrue);
      expect(state.currentUser?.role, UserRole.admin);

      state.logout();

      expect(await state.login('staff@miniorder.vn', '123456'), isTrue);
      expect(state.currentUser?.role, UserRole.staff);
    });

    test('logs in with a provisioned Google account', () async {
      expect(await state.loginWithGoogle(), isTrue);
      expect(state.currentUser?.id, 'u_admin');
      expect(state.currentUser?.role, UserRole.admin);
      expect(state.message, contains('Google'));
    });

    test(
      'queues a new Google account for Admin approval and signs out',
      () async {
        final authentication = NewGoogleAuthenticationService();
        final accessRequests = TestAccessRequestService();
        final pendingState = AppState(
          MockOrderRepository(),
          authenticationService: authentication,
          accessRequestService: accessRequests,
        );

        expect(await pendingState.loginWithGoogle(), isFalse);
        expect(accessRequests.requested, isTrue);
        expect(authentication.signedOut, isTrue);
        expect(pendingState.currentUser, isNull);
        expect(pendingState.error, contains('chờ Admin duyệt'));
      },
    );

    test(
      'refreshes repository when another device changes Firestore data',
      () async {
        final storage = _RealtimeLocalDatabaseStorage();
        final realtimeState = AppState(
          MockOrderRepository(localDatabaseStorage: storage),
          authenticationService: TestAuthenticationService(),
        );
        await realtimeState.login('admin@miniorder.vn', '123456');

        final remoteSnapshot = storage.cloneSnapshot();
        final products = remoteSnapshot['products'] as List<dynamic>;
        final coffee = products.whereType<Map>().firstWhere(
          (item) => item['productId'] == 'P001',
        );
        coffee['tenMon'] = 'Cà phê đồng bộ realtime';
        storage.emitRemote(remoteSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          realtimeState.productById('P001')?.name,
          'Cà phê đồng bộ realtime',
        );
        realtimeState.dispose();
      },
    );

    test('rejects invalid Firebase credentials', () async {
      expect(await state.login('admin@miniorder.vn', 'wrong'), isFalse);
      expect(state.currentUser, isNull);
      expect(state.error, contains('Sai email'));
    });

    test('sends a Firebase password reset email', () async {
      final authentication = TestAuthenticationService();
      final resetState = AppState(
        MockOrderRepository(),
        authenticationService: authentication,
      );

      expect(
        await resetState.requestPasswordReset(' user@example.com '),
        isTrue,
      );
      expect(authentication.passwordResetEmail, 'user@example.com');
      expect(resetState.message, contains('Firebase đã gửi'));
      expect(resetState.error, isNull);
    });

    test('rejects an invalid password reset email', () async {
      final authentication = TestAuthenticationService();
      final resetState = AppState(
        MockOrderRepository(),
        authenticationService: authentication,
      );

      expect(await resetState.requestPasswordReset('invalid-email'), isFalse);
      expect(authentication.passwordResetEmail, isNull);
      expect(resetState.error, contains('email hợp lệ'));
    });

    test('creates order and decreases stock', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');

      final coffee = state.productById('P001')!;
      final originalStock = coffee.stock;

      expect(state.addToCart(coffee), isTrue);
      final order = await state.confirmOrder('Ít sữa');

      expect(order, isNotNull);
      expect(order!.total, 25000);
      expect(state.tableById('t01')?.status, TableStatus.ordering);
      expect(state.productById('P001')?.stock, originalStock - 1);
    });

    test('saves a separate note for each ordered item', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');

      final coffee = state.productById('P001')!;
      final tea = state.productById('P002')!;
      state.addToCart(coffee);
      state.updateCartItemNote(coffee.id, 'Ít sữa');
      state.addToCart(coffee);
      state.addToCart(tea);
      state.updateCartItemNote(tea.id, 'Không đá');

      expect(
        state.cartItems.firstWhere((item) => item.productId == coffee.id).note,
        'Ít sữa',
      );

      final order = await state.confirmOrder('');

      expect(order, isNotNull);
      expect(
        order!.items.firstWhere((item) => item.productId == coffee.id).note,
        'Ít sữa',
      );
      expect(
        order.items.firstWhere((item) => item.productId == tea.id).note,
        'Không đá',
      );
    });

    test('adds items to the active order of an occupied table', () async {
      await state.login('staff@miniorder.vn', '123456');
      final existingOrder = state.orderForTable('t02')!;
      final originalItemCount = existingOrder.items.length;
      final coffee = state.productById('P001')!;
      final originalStock = coffee.stock;

      state.selectTable('t02');
      expect(state.addToCart(coffee), isTrue);
      final updatedOrder = await state.confirmOrder('Thêm ít đường');

      expect(updatedOrder, isNotNull);
      expect(updatedOrder!.id, existingOrder.id);
      expect(updatedOrder.items, hasLength(originalItemCount + 1));
      expect(updatedOrder.status, OrderStatus.pending);
      expect(
        state.ordersForTable('t02').where((o) => o.isActive),
        hasLength(1),
      );
      expect(state.productById('P001')?.stock, originalStock - 1);
      expect(state.message, contains('thêm món'));
    });

    test('next kitchen ticket contains only newly added items', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final firstOrder = (await state.confirmOrder(''))!;

      expect(state.sendToKitchen(firstOrder.id), isTrue);
      final firstBatchOrder = state.orderById(firstOrder.id)!;
      final firstBatchId = firstBatchOrder.items.single.kitchenBatchId;
      expect(firstBatchId, isNotEmpty);
      expect(state.completeOrder(firstOrder.id), isTrue);

      state.selectTable('t01');
      state.addToCart(state.productById('P005')!);
      final orderWithAddedItems = (await state.confirmOrder(''))!;
      expect(
        orderWithAddedItems.currentKitchenItems.map((item) => item.productId),
        ['P005'],
      );

      expect(state.sendToKitchen(firstOrder.id), isTrue);
      final secondBatchOrder = state.orderById(firstOrder.id)!;
      expect(
        secondBatchOrder.currentKitchenItems.map((item) => item.productId),
        ['P005'],
      );
      expect(secondBatchOrder.items.first.kitchenBatchId, firstBatchId);
      expect(secondBatchOrder.items.last.kitchenBatchId, isNot(firstBatchId));

      final receipt = ReportService().buildKitchenReceipt(
        order: secondBatchOrder,
        table: state.tableById('t01'),
      );
      expect(receipt, contains('Mì xào'));
      expect(receipt, isNot(contains('Cà phê sữa')));
    });

    test('locks sold-out products without showing an error', () async {
      await state.login('admin@miniorder.vn', '123456');
      state.selectTable('t01');
      final tea = state.productById('P002')!;

      expect(state.addToCart(tea), isTrue);
      expect(state.adjustStock(tea.id, -tea.stock), isTrue);

      final soldOutTea = state.productById(tea.id)!;
      expect(soldOutTea.stock, 0);
      expect(soldOutTea.canOrder, isFalse);
      expect(
        state.cartItems.where((item) => item.productId == tea.id),
        isEmpty,
      );
      state.consumeMessages();
      expect(state.addToCart(soldOutTea), isFalse);
      expect(state.error, isNull);
    });

    test('cash payment marks order paid and table paid', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = await state.confirmOrder('');

      final payment = await state.createPayment(order!.id, PaymentMethod.cash);

      expect(payment, isNotNull);
      expect(await state.confirmPayment(payment!.id), isTrue);
      expect(state.orderById(order.id)?.status, OrderStatus.paid);
      expect(state.tableById('t01')?.status, TableStatus.paid);
    });

    test('VietQR contains the exact order amount and demo account', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = (await state.confirmOrder(''))!;

      final payment = await state.createPayment(order.id, PaymentMethod.qr);
      final qrUri = Uri.parse(payment!.qrContent);

      expect(qrUri.host, 'img.vietqr.io');
      expect(qrUri.path, contains('MB-0000000000-compact2.png'));
      expect(qrUri.queryParameters['amount'], '${order.total}');
      expect(qrUri.queryParameters['accountName'], 'MINIORDERAPP');
      expect(qrUri.queryParameters['addInfo'], startsWith('MINIORDER '));
    });

    test('confirming VietQR completes payment and marks table paid', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = (await state.confirmOrder(''))!;
      final payment = (await state.createPayment(order.id, PaymentMethod.qr))!;

      expect(await state.confirmPayment(payment.id), isTrue);
      expect(state.paymentById(payment.id)?.status, PaymentStatus.paid);
      expect(state.orderById(order.id)?.status, OrderStatus.paid);
      expect(state.tableById('t01')?.status, TableStatus.paid);
      expect(state.message, isNull);
    });

    test('staff cannot pay order served by another staff member', () async {
      await state.login('admin@miniorder.vn', '123456');
      final now = DateTime.now();
      await state.upsertUser(
        AppUser(
          id: 'u_staff_2',
          employeeCode: 'NV002',
          fullName: 'Nhân viên ca chiều',
          email: 'staff2@miniorder.vn',
          phone: '0901000003',
          username: 'staff2',
          role: UserRole.staff,
          shift: 'Ca chiều',
          status: AccountStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      );
      state.logout();

      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = await state.confirmOrder('');
      state.logout();

      await state.login('staff2@miniorder.vn', '123456');
      expect(await state.createPayment(order!.id, PaymentMethod.cash), isNull);
      expect(state.error, contains('order mình'));

      state.logout();
      await state.login('admin@miniorder.vn', '123456');
      final payment = await state.createPayment(order.id, PaymentMethod.cash);

      expect(payment, isNotNull);
    });

    test('clears paid table back to available', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = await state.confirmOrder('');
      final payment = await state.createPayment(order!.id, PaymentMethod.cash);
      await state.confirmPayment(payment!.id);

      expect(await state.clearTable('t01'), isTrue);
      expect(state.tableById('t01')?.status, TableStatus.available);
      expect(state.tableById('t01')?.currentOrderId, isNull);
    });

    test('keeps paid table when Firestore clear transaction fails', () async {
      final failedState = AppState(
        MockOrderRepository(),
        authenticationService: TestAuthenticationService(),
        orderTransactionService: _FailingClearTransactionService(),
      );
      await failedState.login('admin@miniorder.vn', '123456');

      expect(failedState.tableById('t03')?.status, TableStatus.paid);
      expect(await failedState.clearTable('t03'), isFalse);
      expect(failedState.tableById('t03')?.status, TableStatus.paid);
      expect(failedState.error, contains('Firestore'));
      failedState.dispose();
    });

    test('staff receives a table cleared by admin in realtime', () async {
      final storage = _RealtimeLocalDatabaseStorage(emitChangesOnSave: true);
      final adminState = AppState(
        MockOrderRepository(localDatabaseStorage: storage),
        authenticationService: TestAuthenticationService(),
      );
      final staffState = AppState(
        MockOrderRepository(localDatabaseStorage: storage),
        authenticationService: TestAuthenticationService(),
      );

      await adminState.login('admin@miniorder.vn', '123456');
      await staffState.login('staff@miniorder.vn', '123456');
      expect(staffState.tableById('t03')?.status, TableStatus.paid);

      expect(await adminState.clearTable('t03'), isTrue);
      await _waitUntil(
        () => staffState.tableById('t03')?.status == TableStatus.available,
      );

      expect(staffState.tableById('t03')?.currentOrderId, isNull);
      adminState.dispose();
      staffState.dispose();
      await storage.dispose();
    });

    test('staff cannot update admin-only product data', () async {
      await state.login('staff@miniorder.vn', '123456');

      expect(state.adjustStock('P001', 5), isFalse);
      expect(state.error, contains('Admin'));
    });

    test(
      'only admin can remove item from confirmed order and restore stock',
      () async {
        await state.login('staff@miniorder.vn', '123456');
        state.selectTable('t01');
        state.addToCart(state.productById('P001')!);
        state.addToCart(state.productById('P005')!);
        final order = await state.confirmOrder('');
        final removedItem = order!.items.firstWhere(
          (item) => item.productId == 'P001',
        );

        expect(state.removeOrderItem(order.id, removedItem.id), isFalse);
        expect(state.productById('P001')?.stock, 19);

        state.logout();
        await state.login('admin@miniorder.vn', '123456');

        expect(state.removeOrderItem(order.id, removedItem.id), isTrue);
        final updatedOrder = state.orderById(order.id)!;

        expect(updatedOrder.items, hasLength(1));
        expect(updatedOrder.items.single.productId, 'P005');
        expect(updatedOrder.total, 45000);
        expect(state.productById('P001')?.stock, 20);
      },
    );

    test('transfers active order to an available table', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = await state.confirmOrder('');

      expect(await state.transferOrderToTable(order!.id, 't04'), isTrue);

      final movedOrder = state.orderById(order.id)!;
      expect(movedOrder.tableId, 't04');
      expect(state.tableById('t01')?.status, TableStatus.available);
      expect(state.tableById('t01')?.currentOrderId, isNull);
      expect(state.tableById('t04')?.status, TableStatus.ordering);
      expect(state.tableById('t04')?.currentOrderId, order.id);
      expect(state.ordersForTable('t04').first.id, order.id);
    });

    test('does not transfer order to an occupied table', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = await state.confirmOrder('');

      expect(await state.transferOrderToTable(order!.id, 't02'), isFalse);
      expect(state.orderById(order.id)?.tableId, 't01');
      expect(state.tableById('t01')?.status, TableStatus.ordering);
    });

    test(
      'transfer expires pending payment so user can create payment again',
      () async {
        await state.login('staff@miniorder.vn', '123456');
        state.selectTable('t01');
        state.addToCart(state.productById('P001')!);
        final order = await state.confirmOrder('');
        final oldPayment = await state.createPayment(
          order!.id,
          PaymentMethod.qr,
        );

        expect(oldPayment, isNotNull);
        expect(await state.transferOrderToTable(order.id, 't04'), isTrue);
        expect(
          state.paymentById(oldPayment!.id)?.status,
          PaymentStatus.expired,
        );

        final newPayment = await state.createPayment(
          order.id,
          PaymentMethod.qr,
        );
        expect(newPayment, isNotNull);
        expect(newPayment!.id, isNot(oldPayment.id));
        expect(newPayment.tableId, 't04');
      },
    );

    test('changing confirmed order expires its pending payment', () async {
      await state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      state.addToCart(state.productById('P005')!);
      final order = (await state.confirmOrder(''))!;
      final payment = (await state.createPayment(order.id, PaymentMethod.qr))!;

      state.logout();
      await state.login('admin@miniorder.vn', '123456');
      expect(state.removeOrderItem(order.id, order.items.first.id), isTrue);

      expect(state.paymentById(payment.id)?.status, PaymentStatus.expired);
      expect(await state.confirmPayment(payment.id), isFalse);
    });

    test('completed order is not marked as delayed', () {
      final now = DateTime.now();
      final order = Order(
        id: 'completed',
        tableId: 't01',
        userId: 'u_staff',
        items: const [],
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 30)),
        updatedAt: now,
        sentKitchenAt: now.subtract(const Duration(minutes: 25)),
        completedAt: now.subtract(const Duration(minutes: 5)),
      );

      expect(order.isDelayed, isFalse);
    });

    test('admin validation protects referenced and invalid data', () async {
      await state.login('admin@miniorder.vn', '123456');

      expect(state.deleteTable('t02'), isFalse);
      expect(state.error, contains('lịch sử order'));

      final invalidProduct = state
          .productById('P001')!
          .copyWith(name: '', price: 0);
      expect(state.upsertProduct(invalidProduct), isFalse);
      expect(state.error, contains('giá phải lớn hơn 0'));
    });

    test('admin deletes a user while preserving order history', () async {
      await state.login('admin@miniorder.vn', '123456');
      final staffOrderIds = state.orders
          .where((order) => order.userId == 'u_staff')
          .map((order) => order.id)
          .toSet();

      expect(staffOrderIds, isNotEmpty);
      expect(await state.deleteUser('u_staff'), isTrue);
      expect(state.userById('u_staff'), isNull);
      expect(
        state.orders
            .where((order) => staffOrderIds.contains(order.id))
            .map((order) => order.id)
            .toSet(),
        staffOrderIds,
      );
    });

    test('restores cart draft from local storage', () async {
      final storage = _MemoryCartDraftStorage();
      final firstState = AppState(
        MockOrderRepository(),
        authenticationService: TestAuthenticationService(),
        cartDraftStorage: storage,
      );

      firstState.selectTable('t01');
      firstState.addToCart(firstState.productById('P001')!);

      final restoredState = AppState(
        MockOrderRepository(),
        authenticationService: TestAuthenticationService(),
        cartDraftStorage: storage,
      );
      await restoredState.restoreCartDraft();

      expect(restoredState.selectedTableId, 't01');
      expect(restoredState.cartItems, hasLength(1));
      expect(restoredState.cartItems.single.productId, 'P001');
    });

    test('persists repository snapshot across repository instances', () async {
      final storage = _MemoryLocalDatabaseStorage();
      final firstRepository = MockOrderRepository(
        localDatabaseStorage: storage,
      );
      final firstState = AppState(
        firstRepository,
        authenticationService: TestAuthenticationService(),
      );

      await firstState.login('admin@miniorder.vn', '123456');
      firstState.adjustStock('P001', -3);
      await Future<void>.delayed(Duration.zero);

      final restoredRepository = MockOrderRepository(
        localDatabaseStorage: storage,
      );
      await restoredRepository.restoreSavedData();

      expect(restoredRepository.findProduct('P001')?.stock, 17);
      expect(restoredRepository.exportBackupJson(), contains('"products"'));
    });
  });
}

class _MemoryCartDraftStorage implements CartDraftStorage {
  CartDraft? draft;

  @override
  Future<void> clearDraft() {
    draft = null;
    return Future.value();
  }

  @override
  Future<CartDraft?> loadDraft() => Future.value(draft);

  @override
  Future<void> saveDraft(CartDraft draft) {
    this.draft = draft;
    return Future.value();
  }
}

class _MemoryLocalDatabaseStorage implements LocalDatabaseStorage {
  Map<String, dynamic>? snapshot;

  @override
  Future<void> clearSnapshot() {
    snapshot = null;
    return Future.value();
  }

  @override
  Future<Map<String, dynamic>?> loadSnapshot() => Future.value(snapshot);

  @override
  Future<void> saveSnapshot(Map<String, Object?> snapshot) {
    this.snapshot = Map<String, dynamic>.from(snapshot);
    return Future.value();
  }
}

class _RealtimeLocalDatabaseStorage
    implements LocalDatabaseStorage, RealtimeDatabaseStorage {
  _RealtimeLocalDatabaseStorage({this.emitChangesOnSave = false});

  final _changes = StreamController<void>.broadcast();
  final bool emitChangesOnSave;
  Map<String, dynamic>? _snapshot;

  @override
  Future<Map<String, dynamic>?> loadSnapshot() async => _snapshot;

  @override
  Future<void> saveSnapshot(Map<String, Object?> snapshot) async {
    _snapshot = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>,
    );
    if (emitChangesOnSave) {
      scheduleMicrotask(() {
        if (!_changes.isClosed) _changes.add(null);
      });
    }
  }

  @override
  Future<void> clearSnapshot() async {
    _snapshot = null;
  }

  @override
  Stream<void> watchRemoteChanges() => _changes.stream;

  Map<String, dynamic> cloneSnapshot() => Map<String, dynamic>.from(
    jsonDecode(jsonEncode(_snapshot)) as Map<String, dynamic>,
  );

  void emitRemote(Map<String, dynamic> snapshot) {
    _snapshot = snapshot;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

class _FailingClearTransactionService implements OrderTransactionService {
  @override
  Future<void> clearPaidTable(RestaurantTable table) {
    throw const OrderTransactionFailure('Không thể dọn bàn trên Firestore.');
  }

  @override
  Future<void> appendItemsToOrder({
    required Order order,
    required List<OrderItem> items,
    required String note,
  }) async {}

  @override
  Future<void> confirmPayment({
    required Payment payment,
    required String confirmedBy,
  }) async {}

  @override
  Future<void> createOrder(Order order) async {}

  @override
  Future<void> createPayment(Payment payment) async {}

  @override
  Future<void> transferOrder({
    required Order order,
    required RestaurantTable sourceTable,
    required RestaurantTable targetTable,
    required List<Payment> waitingPayments,
  }) async {}
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Dữ liệu realtime không được cập nhật trong thời gian chờ.');
}
