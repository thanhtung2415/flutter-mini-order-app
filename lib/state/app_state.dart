import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../repositories/order_repository.dart';
import '../services/cart_draft_storage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.repository, {required this.cartDraftStorage});

  final PersistentOrderRepository repository;
  final CartDraftStorage cartDraftStorage;

  AppUser? _currentUser;
  String? _selectedTableId;
  List<OrderItem> _cartItems = [];
  String? _error;
  bool _initialized = false;

  bool get initialized => _initialized;
  AppUser? get currentUser => _currentUser;
  String? get selectedTableId => _selectedTableId;
  List<OrderItem> get cartItems => List.unmodifiable(_cartItems);
  String? get error => _error;

  List<RestaurantTable> get tables => repository.tables;
  List<Product> get products => repository.products;
  List<Order> get orders => repository.orders;
  int get cartTotal => _cartItems.fold(0, (sum, item) => sum + item.total);
  int get cartQuantity =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);

  Future<void> initialize() async {
    await repository.restoreSavedData();
    final draft = await cartDraftStorage.loadDraft();
    if (draft != null) {
      _selectedTableId = draft.tableId;
      _cartItems = draft.items;
    }
    _initialized = true;
    notifyListeners();
  }

  void login(String email, String password) {
    final user = repository.authenticate(email, password);
    if (user == null) {
      _error = 'Email hoac mat khau khong dung';
      notifyListeners();
      return;
    }

    _currentUser = user;
    _error = null;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  void selectTable(String tableId) {
    _selectedTableId = tableId;
    _error = null;
    unawaited(_saveDraft());
    notifyListeners();
  }

  void addProduct(Product product) {
    if (!product.canOrder) return;
    final index = _cartItems.indexWhere((item) => item.productId == product.id);
    if (index >= 0) {
      final current = _cartItems[index];
      _cartItems[index] = current.copyWith(quantity: current.quantity + 1);
    } else {
      _cartItems = [
        ..._cartItems,
        OrderItem(
          id: 'item_${DateTime.now().microsecondsSinceEpoch}',
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.price,
        ),
      ];
    }
    _error = null;
    unawaited(_saveDraft());
    notifyListeners();
  }

  void decreaseProduct(String productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index < 0) return;

    final current = _cartItems[index];
    if (current.quantity <= 1) {
      _cartItems.removeAt(index);
    } else {
      _cartItems[index] = current.copyWith(quantity: current.quantity - 1);
    }
    unawaited(_saveDraft());
    notifyListeners();
  }

  Future<void> submitOrder() async {
    final user = _currentUser;
    final tableId = _selectedTableId;
    if (user == null || tableId == null || _cartItems.isEmpty) {
      _error = 'Vui long chon ban va mon truoc khi dat';
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    final order = Order(
      id: 'order_${now.microsecondsSinceEpoch}',
      tableId: tableId,
      userId: user.id,
      items: List.unmodifiable(_cartItems),
      status: OrderStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    repository.addOrder(order);
    final table = repository.findTable(tableId);
    if (table != null) {
      repository.upsertTable(
        table.copyWith(status: TableStatus.ordering, currentOrderId: order.id),
      );
    }

    for (final item in _cartItems) {
      final product = repository.findProduct(item.productId);
      if (product != null) {
        repository.updateProductStock(product.id, product.stock - item.quantity);
      }
    }

    _cartItems = [];
    _error = null;
    await cartDraftStorage.clearDraft();
    notifyListeners();
  }

  Future<void> _saveDraft() async {
    final tableId = _selectedTableId;
    if (tableId == null || _cartItems.isEmpty) {
      await cartDraftStorage.clearDraft();
      return;
    }
    await cartDraftStorage.saveDraft(
      CartDraft(tableId: tableId, items: _cartItems),
    );
  }
}
