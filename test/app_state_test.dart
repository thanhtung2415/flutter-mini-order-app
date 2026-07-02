import 'package:flutter_test/flutter_test.dart';
import 'package:mini_order_app/models/app_models.dart';
import 'package:mini_order_app/repositories/mock_order_repository.dart';
import 'package:mini_order_app/services/cart_draft_storage_service.dart';
import 'package:mini_order_app/services/local_database_storage_service.dart';
import 'package:mini_order_app/state/app_state.dart';

void main() {
  group('AppState business flow', () {
    late AppState state;

    setUp(() {
      state = AppState(MockOrderRepository());
    });

    test('logs in with demo admin and staff accounts', () {
      expect(state.login('admin@miniorder.vn', '123456'), isTrue);
      expect(state.currentUser?.role, UserRole.admin);

      state.logout();

      expect(state.login('staff@miniorder.vn', '123456'), isTrue);
      expect(state.currentUser?.role, UserRole.staff);
    });

    test('creates order and decreases stock', () {
      state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');

      final coffee = state.productById('P001')!;
      final originalStock = coffee.stock;

      expect(state.addToCart(coffee), isTrue);
      final order = state.confirmOrder('Ít sữa');

      expect(order, isNotNull);
      expect(order!.total, 25000);
      expect(state.tableById('t01')?.status, TableStatus.ordering);
      expect(state.productById('P001')?.stock, originalStock - 1);
    });

    test('cash payment marks order paid and table paid', () {
      state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = state.confirmOrder('');

      final payment = state.createPayment(order!.id, PaymentMethod.cash);

      expect(payment, isNotNull);
      expect(state.confirmPayment(payment!.id), isTrue);
      expect(state.orderById(order.id)?.status, OrderStatus.paid);
      expect(state.tableById('t01')?.status, TableStatus.paid);
    });

    test('staff cannot pay order served by another staff member', () {
      state.login('admin@miniorder.vn', '123456');
      final now = DateTime.now();
      state.upsertUser(
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

      state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = state.confirmOrder('');
      state.logout();

      state.login('staff2@miniorder.vn', '123456');
      expect(state.createPayment(order!.id, PaymentMethod.cash), isNull);
      expect(state.error, contains('order mình'));

      state.logout();
      state.login('admin@miniorder.vn', '123456');
      final payment = state.createPayment(order.id, PaymentMethod.cash);

      expect(payment, isNotNull);
    });

    test('clears paid table back to available', () {
      state.login('staff@miniorder.vn', '123456');
      state.selectTable('t01');
      state.addToCart(state.productById('P001')!);
      final order = state.confirmOrder('');
      final payment = state.createPayment(order!.id, PaymentMethod.cash);
      state.confirmPayment(payment!.id);

      expect(state.clearTable('t01'), isTrue);
      expect(state.tableById('t01')?.status, TableStatus.available);
      expect(state.tableById('t01')?.currentOrderId, isNull);
    });

    test('staff cannot update admin-only product data', () {
      state.login('staff@miniorder.vn', '123456');

      expect(state.adjustStock('P001', 5), isFalse);
      expect(state.error, contains('Admin'));
    });

    test(
      'only admin can remove item from confirmed order and restore stock',
      () {
        state.login('staff@miniorder.vn', '123456');
        state.selectTable('t01');
        state.addToCart(state.productById('P001')!);
        state.addToCart(state.productById('P005')!);
        final order = state.confirmOrder('');
        final removedItem = order!.items.firstWhere(
          (item) => item.productId == 'P001',
        );

        expect(state.removeOrderItem(order.id, removedItem.id), isFalse);
        expect(state.productById('P001')?.stock, 19);

        state.logout();
        state.login('admin@miniorder.vn', '123456');

        expect(state.removeOrderItem(order.id, removedItem.id), isTrue);
        final updatedOrder = state.orderById(order.id)!;

        expect(updatedOrder.items, hasLength(1));
        expect(updatedOrder.items.single.productId, 'P005');
        expect(updatedOrder.total, 45000);
        expect(state.productById('P001')?.stock, 20);
      },
    );

    test('restores cart draft from local storage', () async {
      final storage = _MemoryCartDraftStorage();
      final firstState = AppState(
        MockOrderRepository(),
        cartDraftStorage: storage,
      );

      firstState.selectTable('t01');
      firstState.addToCart(firstState.productById('P001')!);

      final restoredState = AppState(
        MockOrderRepository(),
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
      final firstState = AppState(firstRepository);

      firstState.login('admin@miniorder.vn', '123456');
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
