part of '../app_state.dart';

extension AppStateOrderActions on AppState {
  void selectArea(String areaId) {
    _selectedAreaId = areaId;
    _notify();
  }

  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    _notify();
  }

  void searchMenu(String value) {
    _menuSearch = value;
    _notify();
  }

  void selectTable(String tableId) {
    if (_selectedTableId != tableId) {
      _cart.clear();
      _clearCartDraft();
    }
    _selectedTableId = tableId;
    _notify();
  }

  void clearCart() {
    _cart.clear();
    _clearCartDraft();
    _notify();
  }

  bool addToCart(Product product) {
    if (!product.canOrder) {
      return false;
    }

    final currentQuantity = _cart[product.id]?.quantity ?? 0;
    if (currentQuantity + 1 > product.stock) {
      return false;
    }

    _cart[product.id] = OrderItem(
      id: 'draft_${product.id}',
      productId: product.id,
      productName: product.name,
      quantity: currentQuantity + 1,
      unitPrice: product.price,
      note: _cart[product.id]?.note ?? '',
    );
    _persistCartDraft();
    _notify();
    return true;
  }

  void increaseCartItem(String productId) {
    final product = repository.findProduct(productId);
    if (product == null) return;
    addToCart(product);
  }

  void decreaseCartItem(String productId) {
    final item = _cart[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _cart.remove(productId);
    } else {
      _cart[productId] = item.copyWith(quantity: item.quantity - 1);
    }
    _persistCartDraft();
    _notify();
  }

  void removeCartItem(String productId) {
    _cart.remove(productId);
    _persistCartDraft();
    _notify();
  }

  void updateCartItemNote(String productId, String note) {
    final item = _cart[productId];
    if (item == null) return;

    _cart[productId] = item.copyWith(note: note.trim());
    _persistCartDraft();
    _notify();
  }

  Future<Order?> confirmOrder(String note) async {
    final user = _currentUser;
    final table = selectedTable;
    if (user == null || table == null) {
      _setError('Bạn cần đăng nhập và chọn bàn trước khi tạo order.');
      return null;
    }

    final activeOrder = repository.activeOrderForTable(table.id);
    if (activeOrder != null && !canManageOrder(activeOrder)) {
      _setError('Bạn chỉ được thêm món vào order mình đang phục vụ.');
      return null;
    }

    if (_cart.isEmpty) {
      _setError('Giỏ hàng đang trống.');
      return null;
    }

    if (_reconcileCartWithStock()) {
      _error = null;
      _message = null;
      _notify();
      return null;
    }

    for (final item in cartItems) {
      final product = repository.findProduct(item.productId);
      if (product == null ||
          !product.canOrder ||
          product.stock < item.quantity) {
        _setError('Không đủ tồn kho cho món ${item.productName}.');
        return null;
      }
    }

    final now = DateTime.now();
    final addedItems = cartItems
        .map((item) => item.copyWith(id: nextId('item')))
        .toList();
    final addedNote = note.trim();
    final nextNote = activeOrder == null || addedNote.isEmpty
        ? activeOrder?.note ?? addedNote
        : activeOrder.note.isEmpty
        ? addedNote
        : '${activeOrder.note}\n$addedNote';
    final existingItems = activeOrder == null
        ? const <OrderItem>[]
        : activeOrder.status == OrderStatus.pending
        ? activeOrder.items
        : activeOrder.items
              .map(
                (item) => item.hasBeenSentToKitchen
                    ? item
                    : item.copyWith(kitchenBatchId: 'legacy_${activeOrder.id}'),
              )
              .toList(growable: false);
    final order = activeOrder == null
        ? Order(
            id: nextId('ord'),
            tableId: table.id,
            userId: user.id,
            items: addedItems,
            status: OrderStatus.pending,
            createdAt: now,
            updatedAt: now,
            note: addedNote,
          )
        : activeOrder.copyWith(
            items: [...existingItems, ...addedItems],
            status: OrderStatus.pending,
            updatedAt: now,
            clearSentKitchenAt: true,
            clearCompletedAt: true,
            note: nextNote,
          );

    final transactions = orderTransactionService;
    if (transactions != null) {
      try {
        if (activeOrder == null) {
          await transactions.createOrder(order);
        } else {
          await transactions.appendItemsToOrder(
            order: activeOrder,
            items: addedItems,
            note: addedNote,
          );
        }
      } on OrderTransactionFailure catch (error) {
        if (error.code == 'stock-changed') {
          try {
            await restoreRepositoryData().timeout(const Duration(seconds: 8));
          } catch (_) {
            // The current snapshot is still used to lock unavailable items.
          }
          _reconcileCartWithStock();
          _error = null;
          _message = null;
          _notify();
          return null;
        }
        _setError(error.message);
        return null;
      }
    }

    _mutateAfterRemoteCommit(transactions != null, () {
      if (activeOrder == null) {
        repository.addOrder(order);
      } else {
        repository.updateOrder(order);
        _expireWaitingPayments(order.id);
      }
      for (final item in addedItems) {
        final product = repository.findProduct(item.productId);
        if (product != null) {
          repository.updateProductStock(
            product.id,
            product.stock - item.quantity,
          );
        }
      }
      if (activeOrder == null) {
        repository.upsertTable(
          table.copyWith(
            status: TableStatus.ordering,
            currentOrderId: order.id,
          ),
        );
      }
    });
    _cart.clear();
    _clearCartDraft();
    _message = activeOrder == null
        ? 'Đã tạo order cho ${table.name}.'
        : 'Đã thêm món vào order của ${table.name}.';
    _error = null;
    _notify();
    return order;
  }

  Order? orderForTable(String tableId) =>
      repository.activeOrderForTable(tableId);

  List<Order> ordersForTable(String tableId) =>
      repository.orders.where((order) => order.tableId == tableId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Order? orderById(String id) => repository.findOrder(id);

  Payment? paymentById(String id) => repository.findPayment(id);

  RestaurantTable? tableById(String id) => repository.findTable(id);

  Area? areaById(String id) => repository.findArea(id);

  Category? categoryById(String id) => repository.findCategory(id);

  Product? productById(String id) => repository.findProduct(id);

  AppUser? userById(String id) =>
      repository.users.where((user) => user.id == id).firstOrNull;

  Payment? latestPaymentForOrder(String orderId) =>
      repository.latestPaymentForOrder(orderId);

  bool sendToKitchen(String orderId) {
    final order = repository.findOrder(orderId);
    if (order == null) {
      _setError('Không tìm thấy order.');
      return false;
    }
    if (order.status == OrderStatus.paid ||
        order.status == OrderStatus.cancelled) {
      _setError('Order này đã đóng.');
      return false;
    }
    if (!canManageOrder(order)) {
      _setError('Nhân viên chỉ được gửi bếp order mình đang phục vụ.');
      return false;
    }
    final unsentItems = order.items
        .where((item) => !item.hasBeenSentToKitchen)
        .toList(growable: false);
    if (unsentItems.isEmpty) {
      _setError('Không có món mới cần gửi bếp.');
      return false;
    }
    final kitchenBatchId = nextId('kitchen');
    repository.updateOrder(
      order.copyWith(
        items: order.items
            .map(
              (item) => item.hasBeenSentToKitchen
                  ? item
                  : item.copyWith(kitchenBatchId: kitchenBatchId),
            )
            .toList(growable: false),
        status: OrderStatus.preparing,
        sentKitchenAt: DateTime.now(),
      ),
    );
    _message = 'Đã gửi bếp order ${order.id}.';
    _error = null;
    _notify();
    return true;
  }

  bool completeOrder(String orderId) {
    final order = repository.findOrder(orderId);
    if (order == null || !order.isActive) {
      _setError('Order không còn hoạt động.');
      return false;
    }
    if (!canManageOrder(order)) {
      _setError('Nhân viên chỉ được hoàn tất order mình đang phục vụ.');
      return false;
    }
    repository.updateOrder(
      order.copyWith(
        status: OrderStatus.completed,
        completedAt: DateTime.now(),
      ),
    );
    _message = 'Đã đánh dấu hoàn tất món.';
    _error = null;
    _notify();
    return true;
  }

  bool cancelOrder(String orderId) {
    if (!_requireAdmin()) return false;
    final order = repository.findOrder(orderId);
    if (order == null || order.status == OrderStatus.paid) {
      _setError('Không thể hủy order này.');
      return false;
    }

    for (final item in order.items) {
      final product = repository.findProduct(item.productId);
      if (product != null) {
        repository.updateProductStock(
          product.id,
          product.stock + item.quantity,
        );
      }
    }

    repository.updateOrder(order.copyWith(status: OrderStatus.cancelled));
    _expireWaitingPayments(order.id);
    final table = repository.findTable(order.tableId);
    if (table != null) {
      repository.upsertTable(
        table.copyWith(status: TableStatus.available, clearCurrentOrder: true),
      );
    }
    _message = 'Đã hủy order và hoàn lại tồn kho.';
    _error = null;
    _notify();
    return true;
  }

  bool removeOrderItem(String orderId, String orderItemId) {
    if (!_requireAdmin()) return false;
    final order = repository.findOrder(orderId);
    if (order == null) {
      _setError('Không tìm thấy order.');
      return false;
    }
    if (order.status == OrderStatus.paid ||
        order.status == OrderStatus.cancelled) {
      _setError('Không thể xóa món khỏi order đã đóng.');
      return false;
    }

    final item = order.items
        .where((value) => value.id == orderItemId)
        .firstOrNull;
    if (item == null) {
      _setError('Không tìm thấy món trong order.');
      return false;
    }

    if (order.items.length == 1) {
      return cancelOrder(orderId);
    }

    final product = repository.findProduct(item.productId);
    if (product != null) {
      repository.updateProductStock(product.id, product.stock + item.quantity);
    }

    final updatedItems = order.items
        .where((value) => value.id != orderItemId)
        .toList(growable: false);
    repository.updateOrder(order.copyWith(items: updatedItems));
    _expireWaitingPayments(order.id);
    _message = 'Đã xóa món ${item.productName} và hoàn lại tồn kho.';
    _error = null;
    _notify();
    return true;
  }

  Future<bool> transferOrderToTable(
    String orderId,
    String targetTableId,
  ) async {
    final order = repository.findOrder(orderId);
    if (order == null || !order.isActive) {
      _setError('Order không còn hoạt động để chuyển bàn.');
      return false;
    }
    if (!canManageOrder(order)) {
      _setError('Bạn không có quyền chuyển order này.');
      return false;
    }

    final sourceTable = repository.findTable(order.tableId);
    final targetTable = repository.findTable(targetTableId);
    if (sourceTable == null || targetTable == null) {
      _setError('Không tìm thấy bàn cần chuyển.');
      return false;
    }
    if (sourceTable.id == targetTable.id) {
      _setError('Vui lòng chọn bàn khác để chuyển order.');
      return false;
    }
    if (targetTable.status != TableStatus.available ||
        targetTable.currentOrderId != null) {
      _setError('Bàn nhận phải đang trống.');
      return false;
    }

    final waitingPayments = repository.payments
        .where(
          (payment) =>
              payment.orderId == order.id &&
              payment.status == PaymentStatus.waiting,
        )
        .toList(growable: false);
    final transactions = orderTransactionService;
    if (transactions != null) {
      try {
        await transactions.transferOrder(
          order: order,
          sourceTable: sourceTable,
          targetTable: targetTable,
          waitingPayments: waitingPayments,
        );
      } on OrderTransactionFailure catch (error) {
        _setError(error.message);
        return false;
      }
    }

    _mutateAfterRemoteCommit(transactions != null, () {
      repository.updateOrder(order.copyWith(tableId: targetTable.id));
      repository.upsertTable(
        sourceTable.copyWith(
          status: TableStatus.available,
          clearCurrentOrder: true,
          note: '',
        ),
      );
      repository.upsertTable(
        targetTable.copyWith(
          status: TableStatus.ordering,
          currentOrderId: order.id,
        ),
      );
      for (final payment in waitingPayments) {
        repository.updatePayment(
          payment.copyWith(status: PaymentStatus.expired),
        );
      }
    });

    _selectedTableId = targetTable.id;
    _message =
        'Đã chuyển order từ ${sourceTable.name} sang ${targetTable.name}.';
    _error = null;
    _notify();
    return true;
  }
}
